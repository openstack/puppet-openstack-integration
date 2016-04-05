#
# Copyright 2015 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

case $::osfamily {
  'Debian': {
    $ipv6           = false
    # sahara is broken for Ubuntu Trusty and Debian
    # ConfigParser.NoSectionError: No section: 'alembic'
    $sahara_enabled = false
  }
  'RedHat': {
    $ipv6           = true
    $sahara_enabled = true
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

include ::openstack_integration
class { '::openstack_integration::config':
  ipv6 => $ipv6,
  ssl  => true,
}
include ::openstack_integration::cacert
include ::openstack_integration::rabbitmq
include ::openstack_integration::mysql
include ::openstack_integration::keystone
include ::openstack_integration::glance
class { '::openstack_integration::neutron':
  driver => 'linuxbridge',
}
include ::openstack_integration::nova
include ::openstack_integration::trove
include ::openstack_integration::horizon
include ::openstack_integration::heat
if $sahara_enabled {
  include ::openstack_integration::sahara
}
include ::openstack_integration::provision

class { '::openstack_integration::tempest':
  trove   => true,
  sahara  => $sahara_enabled,
  horizon => true,
  heat    => true,
}
