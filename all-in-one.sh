#!/bin/bash
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
#
# Deploy Puppet OpenStack modules, deploy OpenStack and test the setup.
# Software requirements:
# * Ubuntu 14.04 LTS or CentOS7 fresh install
# * 'git' installed
#
# Hardware requirements:
# * At least 4GB of memory, but 8GB is recommended
# * At least 10GB of storage
#
# Usage:
# $ git clone git://git.openstack.org/openstack/puppet-openstack-integration
# $ cd puppet-openstack-integration
# $ ./all-in-one.sh
#
# or
#
# $ curl -sL http://git.openstack.org/cgit/openstack/puppet-openstack-integration/plain/all-in-one.sh | bash
#

set -e

if [ -n "$DEBUG" ]; then
  set -x
fi

# Prepare puppet-openstack-integration repository
rm -rf /tmp/puppet-openstack-integration
git clone git://git.openstack.org/openstack/puppet-openstack-integration /tmp/puppet-openstack-integration
cd /tmp/puppet-openstack-integration

SCENARIO=scenario003
export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
source $SCRIPT_DIR/functions

if is_fedora; then
    sudo yum -y remove facter puppet rdo-release
    sudo yum -y install libxml2-devel libxslt-devel ruby-devel rubygems
    sudo yum -y groupinstall "Development Tools"
    DASHBOARD="dashboard"
elif uses_debs; then
    sudo apt-get remove -y --purge facter puppet puppet-common
    sudo apt-get update
    sudo apt-get install -y libxml2-dev libxslt-dev zlib1g-dev ruby
    DASHBOARD="horizon"
fi

mkdir -p .bundled_gems
export GEM_HOME=`pwd`/.bundled_gems
gem install bundler --no-rdoc --no-ri --verbose

set -e
./run_tests.sh
RESULT=$?
set +e
if [ $RESULT -ne 0 ]; then
  echo "Deployment failed to finish."
  exit 1
fi

cat > ~/openrc <<EOF
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=openstack
export OS_TENANT_NAME=openstack
export OS_USERNAME=admin
export OS_PASSWORD=a_big_secret
export OS_AUTH_URL=http://127.0.0.1:35357/v3
export OS_IDENTITY_API_VERSION=3
EOF

cat <<-EOF

OpenStack Dashboard available: http://127.0.0.1/${DASHBOARD}
To access through Horizon, use the following user/password:
  admin / a_big_secret
To use OpenStack through the CLI, run:
  source ~/openrc

EOF
