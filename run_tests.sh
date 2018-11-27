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

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
source ${SCRIPT_DIR}/functions

export WORKSPACE=${WORKSPACE:-/tmp}
export CEPH_VERSION=${CEPH_VERSION:-mimic}
export PUPPET_MAJ_VERSION=${PUPPET_MAJ_VERSION:-5}
export SCENARIO=${SCENARIO:-scenario001}
export MANAGE_PUPPET_MODULES=${MANAGE_PUPPET_MODULES:-true}
export MANAGE_REPOS=${MANAGE_REPOS:-true}
export ADD_SWAP=${ADD_SWAP:-true}
export SWAP_SIZE_GB=${SWAP_SIZE_GB:-4}
export HIERA_CONFIG=${HIERA_CONFIG:-${SCRIPT_DIR}/hiera/hiera.yaml}
export MANAGE_HIERA=${MANAGE_HIERA:-true}
export PUPPET_ARGS="${PUPPET_ARGS} --detailed-exitcodes --color=false --test --summarize --trace --hiera_config ${HIERA_CONFIG} --logdest ${WORKSPACE}/puppet.log"
export DISTRO=$(lsb_release -c -s)
# If openstack/tempest is broken on master, we can pin the repository to a specific commit
# by using the following line:
# export TEMPEST_VERSION=${TEMPEST_VERSION:-'382a2065f3364a36c110bfcc6275a0f8f6894773'}
export TEMPEST_VERSION=${TEMPEST_VERSION:-'master'}
# For installing Tempest from RPM keep TEMPEST_FROM_SOURCE to false
# In Ubuntu, Tempest packages are not maintained so installing from source
if [ $(lsb_release --id -s) = "Ubuntu" ]; then
   export TEMPEST_FROM_SOURCE=${TEMPEST_FROM_SOURCE:-true}
else
   export TEMPEST_FROM_SOURCE=${TEMPEST_FROM_SOURCE:-false}
fi
# Cirros Image directory
export IMG_DIR=${IMG_DIR:-'/tmp/openstack/image'}


# if we're running the tests we don't need to write out the facts to facter
# so we can disable it.
export WRITE_FACTS=false
source ${SCRIPT_DIR}/configure_facts.sh

export PATH=${PATH}:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin
export PUPPET_BASE_PATH=/etc/puppetlabs/code
export PUPPET_PKG=${PUPPET_PKG:-puppet-agent}

print_header 'Start (run_tests.sh)'

if [ ! -f fixtures/${SCENARIO}.pp ]; then
    echo "fixtures/${SCENARIO}.pp file does not exist. Please define a valid scenario."
    exit 1
fi

if [ $(id -u) != 0 ]; then
  # preserve environment so we can have ZUUL_* params
  export SUDO='sudo -E'
fi

if [ "${ADD_SWAP}" = true ]; then
    print_header "Create $SWAP_SIZE_GB GB swapfile"
    set +e
    $SUDO swapon -s |grep -q '/swapfile'
    RESULT=$?
    set -e
    if [ $RESULT -eq 0 ]; then
        $SUDO swapoff /swapfile && $SUDO rm -f /swapfile
    fi
    $SUDO dd if=/dev/zero of=/swapfile count=${SWAP_SIZE_GB}k bs=1M
    $SUDO chmod 0600 /swapfile
    $SUDO mkswap /swapfile
    $SUDO swapon /swapfile
fi

# We install some gems as root so to take benefit of
# OpenStack Infra mirrors.
if [ -f ~/.gemrc ]; then
    cat ~/.gemrc | $SUDO tee /root/.gemrc
fi

print_header 'Clone Tempest, plugins & pre-cache CirrOS'
# TODO(pabelanger): Move this into tools/install_tempest.sh and add logic so we
# can clone tempest outside of the gate. Also, tempest should be sandboxed into
# the local directory but works needs to be added into puppet to properly find
# the path.

# If it's running in tempest gate, we need to deploy it from source to test the
# patch.
if [[ "${ZUUL_PROJECT}" = "openstack/tempest" ]]; then
    TEMPEST_FROM_SOURCE=true
fi


if [ -e /usr/zuul-env/bin/zuul-cloner ] ; then
    # For ubuntu we always need to deploy tempest-horizon from source
    if uses_debs; then
        /usr/zuul-env/bin/zuul-cloner --workspace /tmp --cache-dir /opt/git \
            git://git.openstack.org openstack/tempest-horizon
    fi
    if [ "${TEMPEST_FROM_SOURCE}" = true ]; then
        /usr/zuul-env/bin/zuul-cloner --workspace /tmp --cache-dir /opt/git \
            git://git.openstack.org openstack/tempest
        # Pin Tempest to TEMPEST_VERSION unless we're running inside the
        # openstack/tempest gate.
        if [[ "${ZUUL_PROJECT}" != "openstack/tempest" ]]; then
            pushd /tmp/openstack/tempest
            git reset --hard $TEMPEST_VERSION
            popd
        fi
    fi
else
    # For ubuntu we always need to deploy tempest-horizon from source
    if uses_debs; then
        $SUDO rm -rf /tmp/openstack/tempest-horizon
        git clone git://git.openstack.org/openstack/tempest-horizon /tmp/openstack/tempest-horizon
    fi
    if [ "${TEMPEST_FROM_SOURCE}" = true ]; then
        $SUDO rm -rf /tmp/openstack/tempest
        git clone git://git.openstack.org/openstack/tempest /tmp/openstack/tempest
        pushd /tmp/openstack/tempest
        git reset --hard origin/$TEMPEST_VERSION
        popd
    fi
fi

# NOTE(pabelanger): We cache cirros images on our jenkins slaves, check if it
# exists.

if [[ ! -e $IMG_DIR ]]; then
    mkdir -p $IMG_DIR
fi

if [ -f ~/cache/files/cirros-0.4.0-x86_64-disk.img ]; then
    # Create a symlink for tempest.
    if ! [ -h /tmp/openstack/image/cirros-0.4.0-x86_64-disk.img ] ; then
        ln -s ~/cache/files/cirros-0.4.0-x86_64-disk.img $IMG_DIR
    fi
else
    wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img -P $IMG_DIR
fi

install_puppet
PUPPET_FULL_PATH=$(which puppet)
if [ "${MANAGE_HIERA}" = true ]; then
  configure_hiera
fi

if uses_debs; then
    $SUDO apt-get install -y dstat ebtables iotop sysstat
elif is_fedora; then
    $SUDO $YUM install -y dstat setools setroubleshoot audit iotop sysstat
    $SUDO service auditd start
    # SElinux in permissive mode so later we can catch alerts
    $SUDO selinuxenabled && $SUDO setenforce 0
fi

# use dstat to monitor system activity during integration testing
if type "dstat" 2>/dev/null; then
    print_header 'Start dstat'
    $SUDO dstat -tcmndrylpg --top-cpu-adv --top-io-adv --nocolor | $SUDO tee --append /var/log/dstat.log > /dev/null &
fi

if type "iostat" 2>/dev/null; then
    print_header 'Start iostat'
    $SUDO iostat -x -k -d -t 4 | $SUDO tee --append /var/log/iostat.log > /dev/null &
fi

if [ -f "/usr/sbin/iotop" ]; then
    print_header 'Start iotop'
    $SUDO /usr/sbin/iotop --kilobytes --only --batch --time --delay=2 --processes --quiet | $SUDO tee --append /var/log/iotop.log > /dev/null &
fi

if [ "${MANAGE_PUPPET_MODULES}" = true ]; then
    $SUDO ./install_modules.sh
fi

# Added tempest specific values to common.yaml
if [ "${TEMPEST_FROM_SOURCE}" = false ]; then
    echo "tempest::install_from_source: false" >> ${SCRIPT_DIR}/hiera/common.yaml
fi

# Run puppet and assert something changes.
set +e
if [ "${MANAGE_REPOS}" = true ]; then
    print_header 'Install repos'
    $SUDO $PUPPET_FULL_PATH apply $PUPPET_ARGS -e "include ::openstack_integration::repos"
    RESULT=$?
    if [ $RESULT -ne 0 ] && [ $RESULT -ne 2 ]; then
        print_header 'Puppet failed to install repositories.'
        exit 1
    fi
    print_header 'Updating packages'
    if is_fedora; then
        $SUDO $YUM update -y
        update_ret=$?
    elif uses_debs; then
        $SUDO DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confnew" upgrade
        update_ret=$?
    fi
    if [ $update_ret -ne 0 ]; then
        print_header 'Error updating packages'
        exit 1
    fi
fi

print_header "Running Puppet Scenario: ${SCENARIO} (1st time)"
run_puppet $SCENARIO
RESULT=$?
set -e
if [ $RESULT -ne 0 ] && [ $RESULT -ne 2 ]; then
    print_header 'First Puppet run contains errors in catalog.'
    catch_puppet_failures
    print_header 'SELinux Alerts (1st time)'
    catch_selinux_alerts
    exit 1
fi
timestamp_puppet_log

# Run puppet a second time and assert nothing changes.
set +e
print_header "Running Puppet Scenario: ${SCENARIO} (2nd time)"
run_puppet $SCENARIO
RESULT=$?
set -e
if [ $RESULT -ne 0 ]; then
    print_header 'Second Puppet run is not idempotent.'
    catch_puppet_failures
    print_header 'SELinux Alerts (2nd time)'
    catch_selinux_alerts
    exit 1
fi
timestamp_puppet_log

print_header 'Prepare Tempest'

# FIXME: Since tempest create tempest workspace which is owned by root user.
# We need to fix it in puppet-tempest, as a workaround we are changing the mode
# of tempest workspace and run tempest command using root.
$SUDO touch /tmp/openstack/tempest/test-whitelist.txt /tmp/openstack/tempest/test-blacklist.txt
$SUDO chown -R "$(id -u):$(id -g)" /tmp/openstack/tempest/

# install from source now on ubuntu until packaged
if uses_debs; then
    cd /tmp/openstack/tempest-horizon;
    if [ $(lsb_release --id -s) = "Debian" ] ; then
        $SUDO apt-get install -y tempest python3-stestr python3-os-testr python3-tempest python3-tempest-horizon
    else
        $SUDO python setup.py install
        $SUDO pip install -U stestr os-testr
    fi
fi

set +e
# Select what to test:
# Smoke suite
echo "smoke" > /tmp/openstack/tempest/test-whitelist.txt

# Horizon
echo "dashboard" >> /tmp/openstack/tempest/test-whitelist.txt

# Aodh
echo "TelemetryAlarming" >> /tmp/openstack/tempest/test-whitelist.txt

# Gnocchi
echo "telemetry_tempest_plugin.gnocchi" >> /tmp/openstack/tempest/test-whitelist.txt

# Vitrage
echo "TestEvents" >> /tmp/openstack/tempest/test-whitelist.txt

# Test Autoscaling with Telemetry (need panko, ubuntu doesn't ship it)
uses_debs || echo "test_telemetry_integration" >> /tmp/openstack/tempest/test-whitelist.txt

# Ironic
# Note: running all Ironic tests under SSL is not working
# https://bugs.launchpad.net/ironic/+bug/1554237
echo "ironic_tempest_plugin.tests.api.admin.test_drivers" >> /tmp/openstack/tempest/test-whitelist.txt

# Zaqar
echo "v2.test_queues.TestManageQueue" >> /tmp/openstack/tempest/test-whitelist.txt

# ec2api
# VPN tests require VPNaaS, which doesn't work yet in puppet-tempest.
# As soon as enabling neutron_vpnaas_available works there, the VPN tests can
# be included.
echo "ec2api_tempest_plugin.api.*test_create_delete(?!.*_vpn_connection)" >> /tmp/openstack/tempest/test-whitelist.txt

# Cinder Backup
echo "VolumesBackupsAdminV2Test" >> /tmp/openstack/tempest/test-whitelist.txt

# Cinder encrypted volumes
echo "TestEncryptedCinderVolumes" >> /tmp/openstack/tempest/test-whitelist.txt

# Mistral
# We have to ignore a smoke test because of:
# https://bugs.launchpad.net/mistral/+bug/1654555
echo "test_create_and_delete_workflow" >> /tmp/openstack/tempest/test-whitelist.txt

# BGPVPN
echo "test_create_bgpvpn" >> /tmp/openstack/tempest/test-whitelist.txt

# L2GW
echo "test_create_show_list_update_delete_l2gateway" >> /tmp/openstack/tempest/test-whitelist.txt

if uses_debs; then
  echo "mistral_tempest_tests.tests.api.v2.test_executions.ExecutionTestsV2.test_get_list_executions" > /tmp/openstack/tempest/test-blacklist.txt
  echo "ceilometer.tests.tempest.api.test_telemetry_notification_api.TelemetryNotificationAPITest.test_check_glance_v2_notifications" >> /tmp/openstack/tempest/test-blacklist.txt
  echo "tempest_horizon.tests.scenario.test_dashboard_basic_ops.TestDashboardBasicOps.test_basic_scenario" >> /tmp/openstack/tempest/test-blacklist.txt
  # TODO (amoralej) tempest tests for object_storage are not working in master with current version of tempest in uca (16.1.0).
  echo "tempest.api.object_storage" >> /tmp/openstack/tempest/test-blacklist.txt
  EXCLUDES="--blacklist-file=/tmp/openstack/tempest/test-blacklist.txt"

  # TODO(tobias-urdin): We must have the neutron-tempest-plugin to even test Neutron, is also required by
  # vpnaas and dynamic routing projects.
  $SUDO pip install neutron-tempest-plugin
else
  # https://review.openstack.org/#/c/504345/ has changed the behavior of tempest when running with --regex and --whitelist-file
  # and now operator between them is OR when filtering tests (which is how it was documented, btw). In order to promote
  # we need to remove this regex option and implement https://review.openstack.org/#/c/547278 when ready.
  # Note these tests were disabled in https://review.openstack.org/#/c/461969/ and hopefully it's more stable now and allows
  # us to run it until we can implement --blacklist-file in a stable way.
  #EXCLUDES="--regex=^(?!tempest.scenario.gnocchi.test.live_assert_vcpus_metric_is_really_expurged.test_request.*$)(?!tempest.scenario.gnocchi.test.live_assert_no_delete_metrics_have_the_gabbilive_policy.test_request.*$).*"

  # TODO(tobias-urdin): An ugly fix to make sure we get the ryu.tests.integrated.common module which is removed
  # from the ryu RPM package. Remove this if we push a fix for the ryu centos package (4.26 is the packaged version).
  git clone -b v4.26 https://github.com/osrg/ryu.git /tmp/openstack/ryu
  $SUDO cp -R /tmp/openstack/ryu/ryu/tests/integrated/common/ /usr/lib/python2.7/site-packages/ryu/tests/integrated/

  # NOTE(tobias-urdin): Blacklist the dynamic routing scenario tests because they use Docker which is not available and also
  # requires the above mentioned ryu.tests.integrated.common module (we need to init tempest workspace now).
  # Note(chandankumar): Blacklist tempest_horizon.tests.scenario.test_dashboard_basic_ops test as they are currently flacky in CI on CentOS
  # Adding it to skip list will help till we find the correct solution
  EXCLUDES="--black-regex=^neutron_dynamic_routing.tests.tempest.scenario|tempest_horizon.tests.scenario.test_dashboard_basic_ops"
fi
print_header 'Running Tempest'
cd /tmp/openstack/tempest

if [ "${TEMPEST_FROM_SOURCE}" = true ]; then
    virtualenv --system-site-packages run_tempest
    run_tempest/bin/pip install -c https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt -U -r requirements.txt
    run_tempest/bin/python setup.py install
    run_tempest/bin/stestr init
    export tempest_binary="run_tempest/bin/tempest"
elif [ $(lsb_release --id -s) = "Debian" ]; then
    export tempest_binary="/usr/bin/python3-tempest"
else
    export tempest_binary="/usr/bin/tempest"
fi

# List tempest version
$tempest_binary --version

# List tempest plugins
$tempest_binary list-plugins

# list tempest workspace
$tempest_binary workspace list

# list tempest tests before running tempest
$tempest_binary run -l --whitelist_file=/tmp/openstack/tempest/test-whitelist.txt

# Run tempest tests
$tempest_binary run --whitelist_file=/tmp/openstack/tempest/test-whitelist.txt --concurrency=2 $EXCLUDES

RESULT=$?
set -e
if [ -d .testrepository ]; then
    testr last --subunit > /tmp/openstack/tempest/testrepository.subunit
elif [ -d .stestr ]; then
    if type "stestr-3" 2>/dev/null; then
        stestr-3 last --subunit > /tmp/openstack/tempest/testrepository.subunit
    else
        stestr last --subunit > /tmp/openstack/tempest/testrepository.subunit
    fi
fi
subunit2html /tmp/openstack/tempest/testrepository.subunit /tmp/openstack/tempest/testr_results.html
print_header 'SELinux Alerts (Tempest)'
catch_selinux_alerts

print_header 'Done (run_tests.sh)'
exit $RESULT
