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

if $facts['os']['name'] == 'Ubuntu' {
  $ssl = false
} else {
  $ssl = true
}

case $facts['os']['family'] {
  'Debian': {
    $ipv6 = false
    # NOTE(tkajinam): UCA Caracal does not provide trove packages
    # https://bugs.launchpad.net/ubuntu/+source/openstack-trove/+bug/2064838
    $trove_enabled = false
  }
  'RedHat': {
    $ipv6 = true
    $trove_enabled = true
  }
  default: {
    fail("Unsupported osfamily (${facts['os']['family']})")
  }
}

include openstack_integration
class { 'openstack_integration::config':
  ssl  => $ssl,
  ipv6 => $ipv6,
}
if $ssl {
  include openstack_integration::cacert
}
include openstack_integration::apache
include openstack_integration::memcached
include openstack_integration::rabbitmq
include openstack_integration::mysql
include openstack_integration::redis
include openstack_integration::ovn
include openstack_integration::keystone
include openstack_integration::glance

class { 'openstack_integration::neutron':
  driver            => 'ovn',
  designate_enabled => true,
}
include openstack_integration::placement
class { 'openstack_integration::nova':
  cinder_enabled => true,
}
if $trove_enabled {
  include openstack_integration::trove
}
class { 'openstack_integration::horizon':
  designate_enabled => true,
  heat_enabled      => true
}
include openstack_integration::heat
include openstack_integration::designate
include openstack_integration::mistral
include openstack_integration::provision

include openstack_integration::barbican
class { 'openstack_integration::magnum':
  cert_manager_type => 'barbican'
}

class { 'openstack_integration::tempest':
  designate      => true,
  trove          => $trove_enabled,
  mistral        => true,
  horizon        => true,
  heat           => true,
  magnum         => true,
  neutron_driver => 'ovn',
}
