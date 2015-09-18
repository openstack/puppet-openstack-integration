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

export SCENARIO=${SCENARIO:-scenario001}

if [ ! -f fixtures/${SCENARIO}.pp ]; then
    echo "fixtures/${SCENARIO}.pp file does not exist. Please define a valid scenario."
    exit 1
fi

if [ $(id -u) != 0 ]; then
  # preserve environment so we can have ZUUL_* params
  SUDO='sudo -E'
fi

$SUDO ./install_modules.sh

# TODO(pabelanger): Move this into tools/install_tempest.sh and add logic so we
# can clone tempest outside of the gate. Also, tempest should be sandboxed into
# the local directory but works needs to be added into puppet to properly find
# the path.
if [ -e /usr/zuul-env/bin/zuul-cloner ] ; then
    /usr/zuul-env/bin/zuul-cloner --workspace /tmp --cache-dir /opt/git \
        git://git.openstack.org openstack/tempest
fi

PUPPET_ARGS="--detailed-exitcodes --verbose --color=false --debug"

function run_puppet() {
    local manifest=$1

    $SUDO puppet apply $PUPPET_ARGS fixtures/${manifest}.pp
    local res=$?

    return $res
}

function is_fedora {
    # note we consider CentOS 7 as fedora for now
    lsb_release -i 2>/dev/null | grep -iq "fedora" || \
        lsb_release -i 2>/dev/null | grep -iq "CentOS"
}

function uses_debs {
    # check if apt-get is installed, valid for debian based
    type "apt-get" 2>/dev/null
}

if uses_debs; then
    $SUDO apt-get update
    $SUDO apt-get install -y dstat
elif is_fedora; then
    $SUDO yum install -y dstat
fi

# use dstat to monitor system activity during integration testing
if type "dstat" 2>/dev/null; then
  $SUDO dstat -tcmndrylpg --top-cpu-adv --top-io-adv --nocolor | $SUDO tee --append /var/log/dstat.log > /dev/null &
fi

# Run puppet and assert something changes.
set +e
run_puppet $SCENARIO
RESULT=$?
set -e
if [ $RESULT -ne 2 ]; then
    exit 1
fi

# Run puppet a second time and assert nothing changes.
set +e
run_puppet $SCENARIO
RESULT=$?
set -e
if [ $RESULT -ne 0 ]; then
    exit 1
fi

# TODO(emilien) later, we should use local image if present. That would be a next iteration.
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img -P /tmp/openstack/tempest

# run tempest smoke suite
cd /tmp/openstack/tempest; tox -eall -- --concurrency=2 smoke dashboard
