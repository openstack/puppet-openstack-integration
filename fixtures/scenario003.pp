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
    $ipv6            = false
    # mistral is not packaged on Ubuntu Trusty
    $mistral_enabled = false
    # murano package should be fixed on Ubuntu Xenial
    $murano_enabled  = false
    # trove package contains broken Tempest tests
    $trove           = false
  }
  'RedHat': {
    $ipv6            = true
    # https://bugs.launchpad.net/mistral/+bug/1663368
    $mistral_enabled = false
    $murano_enabled  = true
    $trove           = true
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

# List of workarounds for Ubuntu Xenial:
# - disable SSL
if ($::operatingsystem == 'Ubuntu') and (versioncmp($::operatingsystemmajrelease, '16') >= 0) {
  $ssl_enabled       = false
  # linuxbridge driver is not working with latest Ubuntu packaging.
  $neutron_plugin    = 'openvswitch'
  # TODO(aschultz): does not work with ocata-m2 right now, check it out when
  # we get m3
  $designate_enabled = false
} else {
  $ssl_enabled       = true
  $neutron_plugin    = 'linuxbridge'
  $designate_enabled = true
}

include ::openstack_integration
class { '::openstack_integration::config':
  ipv6 => $ipv6,
  ssl  => $ssl_enabled,
}
include ::openstack_integration::cacert
include ::openstack_integration::memcached
include ::openstack_integration::rabbitmq
include ::openstack_integration::mysql
class { '::openstack_integration::keystone':
  token_provider => 'fernet',
}
include ::openstack_integration::glance
class { '::openstack_integration::neutron':
  driver => $neutron_plugin,
}
include ::openstack_integration::nova
if $trove_enabled {
  include ::openstack_integration::trove
}
include ::openstack_integration::horizon
include ::openstack_integration::heat
include ::openstack_integration::sahara
if $designate_enabled {
  include ::openstack_integration::designate
}
if $murano_enabled {
  include ::openstack_integration::murano
}
if $mistral_enabled {
  include ::openstack_integration::mistral
}
include ::openstack_integration::provision

class { '::openstack_integration::tempest':
  designate => $designate_enabled,
  trove     => $trove_enabled,
  mistral   => $mistral_enabled,
  sahara    => true,
  horizon   => true,
  murano    => $murano_enabled,
  heat      => true,
}
