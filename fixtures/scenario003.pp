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

if $::os['name'] == 'Ubuntu' {
  $ssl = false
} else {
  $ssl = true
}

case $::osfamily {
  'Debian': {
    $ipv6            = false
    # mistral is not packaged on Ubuntu Trusty
    $mistral_enabled = false
    # murano package should be fixed on Ubuntu Xenial
    $murano_enabled  = false
    # trove package contains broken Tempest tests
    $trove_enabled   = false

    # TODO(tobias-urdin): Ubuntu Train packages has not moved out Sahara
    # plugins to its own packages.
    if $::operatingsystem == 'Ubuntu' {
      $sahara_integration_enable = false
    } else {
      $sahara_integration_enable = true
    }
  }
  'RedHat': {
    $ipv6                      = true
    $mistral_enabled           = true
    # NOTE(mnaser): We need to figure out why Murano won't accept credentials
    #               and how to get it to work with Keystone V3.
    $murano_enabled            = false
    $trove_enabled             = true
    $sahara_integration_enable = true
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
include openstack_integration::keystone
include openstack_integration::glance

class { 'openstack_integration::neutron':
  driver => 'linuxbridge',
}
include openstack_integration::placement
include openstack_integration::nova
if $trove_enabled {
  include openstack_integration::trove
}
class { 'openstack_integration::horizon':
  heat_enabled => true
}
include openstack_integration::heat
class { 'openstack_integration::sahara':
  integration_enable => $sahara_integration_enable,
}
include openstack_integration::designate
if $murano_enabled {
  include openstack_integration::murano
}
if $mistral_enabled {
  include openstack_integration::mistral
}
include openstack_integration::provision

include openstack_integration::barbican
class { 'openstack_integration::magnum':
  cert_manager_type => 'barbican'
}

class { 'openstack_integration::tempest':
  designate => true,
  trove     => $trove_enabled,
  mistral   => $mistral_enabled,
  sahara    => $sahara_integration_enable,
  horizon   => true,
  murano    => $murano_enabled,
  heat      => true,
  # NOTE(tobias-urdin): We have tempest disabled because we cannot
  # run it when instances does not have internet acces to
  # deploy for example Docker.
  magnum    => false,
}
