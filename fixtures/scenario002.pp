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
    $cache_backend = 'memcached'
    $django_cache_backend = 'memcached'
    $tooz_backend = 'redis'
    $neutron_use_httpd = false
  }
  'RedHat': {
    $ipv6 = false
    $cache_backend = 'redis_sentinel'
    $django_cache_backend = 'redis'
    $tooz_backend = 'redis_sentinel'
    $neutron_use_httpd = true
  }
  default: {
    fail("Unsupported osfamily (${facts['os']['family']})")
  }
}

include openstack_integration
class { 'openstack_integration::config':
  ssl           => $ssl,
  ipv6          => $ipv6,
  cache_backend => $cache_backend,
  tooz_backend  => $tooz_backend,
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
class { 'openstack_integration::neutron':
  use_httpd         => $neutron_use_httpd,
  baremetal_enabled => true,
  metering_enabled  => true,
}
class { 'openstack_integration::swift':
  ceilometer_enabled => true,
}
class { 'openstack_integration::ironic':
  inspector_backend        => 'swift',
  send_power_notifications => true,
}
include openstack_integration::zaqar
include openstack_integration::provision

include openstack_integration::placement
class { 'openstack_integration::nova':
  volume_encryption => true,
  cinder_enabled    => true,
}

class { 'openstack_integration::cinder':
  volume_encryption => true,
  cinder_backup     => 'swift',
}

include openstack_integration::barbican

class { 'openstack_integration::ceilometer':
  separate_polling => true,
}
include openstack_integration::aodh
class { 'openstack_integration::gnocchi':
  backend => 'swift',
}

class { 'openstack_integration::horizon':
  cache_backend         => $django_cache_backend,
  cinder_backup_enabled => true,
  ironic_enabled        => true
}

class { 'openstack_integration::tempest':
  aodh                    => true,
  barbican                => true,
  ceilometer              => true,
  cinder                  => true,
  cinder_backup           => true,
  gnocchi                 => true,
  horizon                 => true,
  swift                   => true,
  ironic                  => true,
  zaqar                   => true,
  attach_encrypted_volume => true,
}
