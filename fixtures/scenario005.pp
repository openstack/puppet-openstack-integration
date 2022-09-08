#
# Copyright 2022 Red Hat, Inc.
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

if $::os['name'] == 'Ubuntu' {
  $ssl = false
} else {
  $ssl = true
}

case $::osfamily {
  'Debian': {
    $ipv6 = false
  }
  'RedHat': {
    $ipv6 = true
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
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
include openstack_integration::ovn
include openstack_integration::keystone
include openstack_integration::cinder
class { 'openstack_integration::glance':
  backend => 'cinder',
}
class { 'openstack_integration::neutron':
  driver => 'ovn',
}
include openstack_integration::placement
include openstack_integration::nova

class { 'openstack_integration::octavia':
  provider_driver => 'ovn'
}

include openstack_integration::manila

class { 'openstack_integration::provision':
  # NOTE(tkajinam): Use raw format to use volume cloning when creating a volume
  #                 from an image.
  image_format => 'raw',
}

class { 'openstack_integration::tempest':
  cinder         => true,
  manila         => true,
  octavia        => true,
  neutron_driver => 'ovn',
  image_format   => 'raw',
}
