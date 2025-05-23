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
    # NOTE(tkajinam): Disable due to package conflict
    $vitrage = false
    $notification_topics = $facts['os_service_default']
  }
  'RedHat': {
    $ipv6 = true
    $cache_backend = 'redis'
    $vitrage = true
    $notification_topics = ['notifications', 'vitrage_notifications']
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
  backend                 => 'rbd',
  show_multiple_locations => true,
}
class { 'openstack_integration::neutron':
  notification_topics => $notification_topics,
  metering_enabled    => true,
}
include openstack_integration::placement
class { 'openstack_integration::nova':
  libvirt_rbd         => true,
  notification_topics => $notification_topics,
  cinder_enabled      => true,
}
class { 'openstack_integration::cinder':
  backend       => 'rbd',
  cinder_backup => 'ceph',
}
include openstack_integration::ceilometer
class { 'openstack_integration::aodh':
  notification_topics => $notification_topics,
}
if $vitrage {
  include openstack_integration::vitrage
}
class { 'openstack_integration::ceph':
  ceph_pools => ['glance', 'nova', 'cinder', 'gnocchi', 'backups']
}
class { 'openstack_integration::heat':
  notification_topics => $notification_topics,
}
class { 'openstack_integration::provision':
  # NOTE(tkajinam): Use raw format to use rbd image cloning when creating
  #                 a volume from an image.
  image_format => 'raw',
}
class { 'openstack_integration::gnocchi':
  backend => 'ceph',
}

include openstack_integration::watcher

class { 'openstack_integration::tempest':
  cinder        => true,
  cinder_backup => true,
  gnocchi       => true,
  ceilometer    => true,
  aodh          => true,
  heat          => true,
  vitrage       => $vitrage,
  watcher       => true,
  image_format  => 'raw',
}
