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
    $ipv6           = false
    # ec2api is not packaged on UCA
    $ec2api_enabled = false
  }
  'RedHat': {
    $ipv6           = true
    $ec2api_enabled = true
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
include openstack_integration::redis
class { 'openstack_integration::keystone':
  # NOTE(sileht): Telemetry autoscaling tempest tests can't renew token, so we
  # use a long one
  token_expiration => '2400',
}
class { 'openstack_integration::glance':
  backend          => 'swift',
  image_encryption => true,
}
include openstack_integration::neutron
include openstack_integration::swift
include openstack_integration::ironic
include openstack_integration::zaqar
include openstack_integration::provision

include openstack_integration::placement
class { 'openstack_integration::nova':
  volume_encryption => true,
}

class { 'openstack_integration::cinder':
  volume_encryption => true,
  cinder_backup     => 'swift',
}

include openstack_integration::barbican

if $ec2api_enabled {
  include openstack_integration::ec2api
}

class { 'openstack_integration::ceilometer':
  separate_polling => true,
}
include openstack_integration::aodh
class { 'openstack_integration::gnocchi':
  integration_enable => true,
  backend            => 'swift',
}

class { 'openstack_integration::tempest':
  aodh                    => true,
  barbican                => true,
  ceilometer              => true,
  cinder                  => true,
  cinder_backup           => true,
  gnocchi                 => true,
  swift                   => true,
  ironic                  => true,
  zaqar                   => true,
  attach_encrypted_volume => true,
  ec2api                  => $ec2api_enabled,
}
