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

# Run puppet and assert something changes.
set +e
run_puppet scenario001
RESULT=$?
set -e
if [ $RESULT -ne 2 ]; then
    exit 1
fi

# Run puppet a second time and assert nothing changes.
set +e
run_puppet scenario001
RESULT=$?
set -e
if [ $RESULT -ne 0 ]; then
    exit 1
fi

# TODO(emilien) the checkout thing is temporary, while test_list_projects_returns_only_authorized_projects is
# failing for us we checkout the most recent commit without this test.
# https://bugs.launchpad.net/tempest/+bug/1492419
cd /tmp/openstack/tempest; git checkout b6369eaa58f2c9ce334863cb3ba54c5656cf64c4; tox -eall -- identity image
