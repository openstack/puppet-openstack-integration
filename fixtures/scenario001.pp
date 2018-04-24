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

if ($::os_package_type == 'debian') {
  include ::apache::params
  class { '::apache':
    mod_packages => merge($::apache::params::mod_packages, {
      'wsgi' => 'libapache2-mod-wsgi-py3',
    })
  }
}

case $::osfamily {
  'Debian': {
    $ipv6                    = false
    # vitrage are not packaged yet in debian/ubuntu
    $enable_vitrage          = false
    $om_rpc                  = 'rabbit'
    $om_notify               = 'rabbit'
    $notification_topics     = $::os_service_default
  }
  'RedHat': {
    $ipv6                    = true
    $enable_vitrage          = false
    $om_rpc                  = 'amqp'
    $om_notify               = 'rabbit'
    $notification_topics     = ['notifications', 'vitrage_notifications']
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

include ::openstack_integration
class { '::openstack_integration::config':
  ssl            => true,
  ipv6           => $ipv6,
  rpc_backend    => $om_rpc,
  notify_backend => $om_notify,
}
include ::openstack_integration::cacert
include ::openstack_integration::memcached
include ::openstack_integration::rabbitmq
if ($om_rpc == 'amqp') {
  include ::openstack_integration::qdr
}
include ::openstack_integration::mysql
class { '::openstack_integration::keystone':
  # NOTE(sileht): Telemetry autoscaling tempest tests can't renew token, so we
  # use a long one
  token_expiration => '2400',
}
class { '::openstack_integration::glance':
  backend => 'rbd',
}
class { '::openstack_integration::neutron':
  notification_topics => $notification_topics,
}
class { '::openstack_integration::nova':
  libvirt_rbd         => true,
  notification_topics => $notification_topics,
}
class { '::openstack_integration::cinder':
  backend => 'rbd',
}
include ::openstack_integration::ceilometer
class { '::openstack_integration::aodh':
  notification_topics => $notification_topics,
}
if $enable_vitrage {
  include ::openstack_integration::vitrage
}
include ::openstack_integration::ceph
class { '::openstack_integration::heat':
  notification_topics => $notification_topics,
}
include ::openstack_integration::provision
include ::openstack_integration::redis
include ::openstack_integration::gnocchi
include ::openstack_integration::panko

class { '::openstack_integration::tempest':
  cinder     => true,
  gnocchi    => true,
  ceilometer => true,
  aodh       => true,
  heat       => true,
  panko      => true,
  vitrage    => $enable_vitrage,
}
