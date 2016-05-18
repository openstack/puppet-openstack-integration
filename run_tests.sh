#!/bin/bash -ex
# Copyright 2015 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

export PUPPET_VERSION=${PUPPET_VERSION:-3}
export SCENARIO=${SCENARIO:-scenario001}
export MANAGE_PUPPET_MODULES=${MANAGE_PUPPET_MODULES:-true}
export MANAGE_REPOS=${MANAGE_REPOS:-true}
export PUPPET_ARGS=${PUPPET_ARGS:-}
export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)

if [ $PUPPET_VERSION == 4 ]; then
  export PATH=${PATH}:/opt/puppetlabs/bin
  export PUPPET_RELEASE_FILE=puppetlabs-release-pc1
  export PUPPET_BASE_PATH=/etc/puppetlabs/code
  export PUPPET_PKG=puppet-agent
else
  export PUPPET_RELEASE_FILE=puppetlabs-release
  export PUPPET_BASE_PATH=/etc/puppet
  export PUPPET_PKG=puppet
fi

source ${SCRIPT_DIR}/functions
print_header 'Start (run_tests.sh)'

if [ ! -f fixtures/${SCENARIO}.pp ]; then
    echo "fixtures/${SCENARIO}.pp file does not exist. Please define a valid scenario."
    exit 1
fi

if [ $(id -u) != 0 ]; then
  # preserve environment so we can have ZUUL_* params
  SUDO='sudo -E'
fi

print_header 'Clone Tempest'
# TODO(pabelanger): Move this into tools/install_tempest.sh and add logic so we
# can clone tempest outside of the gate. Also, tempest should be sandboxed into
# the local directory but works needs to be added into puppet to properly find
# the path.
if [ -e /usr/zuul-env/bin/zuul-cloner ] ; then
    /usr/zuul-env/bin/zuul-cloner --workspace /tmp --cache-dir /opt/git \
        git://git.openstack.org openstack/tempest
else
    # remove existed checkout before clone
    $SUDO rm -rf /tmp/openstack/tempest

    # We're outside the gate, just do a regular git clone
    git clone git://git.openstack.org/openstack/tempest /tmp/openstack/tempest
fi

if uses_debs; then
    print_header 'Setup (Debian based)'
    if dpkg -l $PUPPET_RELEASE_FILE >/dev/null 2>&1; then
        $SUDO apt-get purge -y $PUPPET_RELEASE_FILE
    fi
    $SUDO rm -f /tmp/puppet.deb

    wget http://apt.puppetlabs.com/${PUPPET_RELEASE_FILE}-trusty.deb -O /tmp/puppet.deb
    $SUDO dpkg -i /tmp/puppet.deb
    $SUDO apt-get update
    $SUDO apt-get install -y dstat ${PUPPET_PKG}
elif is_fedora; then
    print_header 'Setup (RedHat based)'
    # TODO(emilien): this is a workaround until this patch is merged:
    # https://review.openstack.org/#/c/304399/
    # strip down to en_* locales
    $SUDO yum reinstall -y glibc-common glibc
    $SUDO localedef --delete-from-archive \
          $(localedef --list-archive | grep -v -i '^en' | xargs)
    # prepare template
    $SUDO mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
    # rebuild archive
    $SUDO /usr/sbin/build-locale-archive
    # empty template
    $SUDO mkdir -p /usr/locale
    echo | $SUDO tee --append /usr/locale/locale-archive.tmpl

    if rpm --quiet -q $PUPPET_RELEASE_FILE; then
        $SUDO rpm -e $PUPPET_RELEASE_FILE
    fi
    # EPEL does not work fine with RDO, we need to make sure EPEL is really disabled
    if rpm --quiet -q epel-release; then
        $SUDO rpm -e epel-release
    fi
    $SUDO rm -f /tmp/puppet.rpm

    wget  http://yum.puppetlabs.com/${PUPPET_RELEASE_FILE}-el-7.noarch.rpm -O /tmp/puppet.rpm
    $SUDO rpm -ivh /tmp/puppet.rpm
    $SUDO yum install -y dstat ${PUPPET_PKG} setools setroubleshoot audit
    $SUDO service auditd start

    # SElinux in permissive mode so later we can catch alerts
    $SUDO setenforce 0
fi

PUPPET_ARGS="${PUPPET_ARGS} --detailed-exitcodes --color=false --test --trace"

PUPPET_FULL_PATH=$(which puppet)

function run_puppet() {
    local manifest=$1
    $SUDO $PUPPET_FULL_PATH apply $PUPPET_ARGS fixtures/${manifest}.pp
    local res=$?

    return $res
}

function catch_selinux_alerts() {
    if is_fedora; then
        $SUDO sealert -a /var/log/audit/audit.log
        if $SUDO grep -i 'type=AVC' /var/log/audit/audit.log >/dev/null; then
            echo "AVC detected in /var/log/audit/audit.log"
            echo "Please file a bug on https://bugzilla.redhat.com/enter_bug.cgi?product=Red%20Hat%20OpenStack&component=openstack-selinux showing sealert output."
            exit 1
        else
            echo 'No AVC detected in /var/log/audit/audit.log'
        fi
    fi
}

# use dstat to monitor system activity during integration testing
if type "dstat" 2>/dev/null; then
    print_header 'Start dstat'
    $SUDO dstat -tcmndrylpg --top-cpu-adv --top-io-adv --nocolor | $SUDO tee --append /var/log/dstat.log > /dev/null &
fi

if [ "${MANAGE_PUPPET_MODULES}" = true ]; then
    $SUDO ./install_modules.sh
fi

# Run puppet and assert something changes.
set +e
if [ "${MANAGE_REPOS}" = true ]; then
    print_header 'Install repos'
    $SUDO $PUPPET_FULL_PATH apply $PUPPET_ARGS -e "include ::openstack_integration::repos"
fi
print_header "Running Puppet Scenario: ${SCENARIO} (1st time)"
run_puppet $SCENARIO
RESULT=$?
set -e
if [ $RESULT -ne 2 ]; then
    print_header 'First Puppet run contains errors in catalog.'
    print_header 'SELinux Alerts (1st time)'
    catch_selinux_alerts
    exit 1
fi

# Run puppet a second time and assert nothing changes.
set +e
print_header "Running Puppet Scenario: ${SCENARIO} (2nd time)"
run_puppet $SCENARIO
RESULT=$?
set -e
if [ $RESULT -ne 0 ]; then
    print_header 'Second Puppet run is not idempotent.'
    print_header 'SELinux Alerts (2nd time)'
    catch_selinux_alerts
    exit 1
fi

print_header 'Prepare Tempest'
mkdir -p /tmp/openstack/tempest

$SUDO rm -f /tmp/openstack/tempest/cirros-0.3.4-x86_64-disk.img

# NOTE(pabelanger): We cache cirros images on our jenkins slaves, check if it
# exists.
if [ -f ~/cache/files/cirros-0.3.4-x86_64-disk.img ]; then
    # Create a symlink for tempest.
    ln -s ~/cache/files/cirros-0.3.4-x86_64-disk.img /tmp/openstack/tempest
else
    wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img -P /tmp/openstack/tempest
fi

# Tempest plugin tests require tempest-lib to be installed
$SUDO pip install tempest-lib

# Install Gabbi with pip until it's packaged in RDO:
# https://bugzilla.redhat.com/show_bug.cgi?id=1252812
$SUDO pip install gabbi

set +e
# Select what to test:
# Smoke suite
TESTS="smoke"

# Horizon
TESTS="${TESTS} dashboard"

# Aodh
TESTS="${TESTS} TelemetryAlarming"

# Ironic
# Note: running all Ironic tests under SSL is not working
# https://bugs.launchpad.net/ironic/+bug/1554237
TESTS="${TESTS} api.baremetal.admin.test_drivers"

# Zaqar
TESTS="${TESTS} TestManageQueue"

print_header 'Running Tempest'
cd /tmp/openstack/tempest

# ceilometer plugin is broken because of:
# https://github.com/openstack/tempest/commit/e4796f8de446aaaafa83902d1fb2d613331436cf
git checkout 7732fb08d5ed524ee37935ef2b5b1fcd185c798f

tox -eall-plugin -- --concurrency=2 $TESTS
RESULT=$?
set -e
testr last --subunit > /tmp/openstack/tempest/testrepository.subunit
/tmp/openstack/tempest/.tox/all-plugin/bin/tempest list-plugins

print_header 'SELinux Alerts (Tempest)'
catch_selinux_alerts

print_header 'Done (run_tests.sh)'
exit $RESULT
