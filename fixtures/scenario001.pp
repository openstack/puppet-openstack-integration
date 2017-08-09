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
    $ipv6                    = false
    # panko, gnocchi and vitrage are not packaged yet in debian/ubuntu
    # https://bugs.launchpad.net/cloud-archive/+bug/1535740
    $enable_vitrage          = false
    $enable_legacy_telemetry = true
  }
  'RedHat': {
    $ipv6                    = true
    $enable_vitrage          = true
    $enable_legacy_telemetry = false
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

# List of workarounds for Ubuntu Xenial:
# - disable SSL
if ($::operatingsystem == 'Ubuntu') and (versioncmp($::operatingsystemmajrelease, '16') >= 0) {
  $ssl_enabled = false
} else {
  $ssl_enabled = true
}

include ::openstack_integration
class { '::openstack_integration::config':
  ssl  => $ssl_enabled,
  ipv6 => $ipv6,
}
include ::openstack_integration::cacert
include ::openstack_integration::memcached
include ::openstack_integration::rabbitmq
include ::openstack_integration::mysql
class { '::openstack_integration::keystone':
  # NOTE(sileht):zTelemetry autoscaling tempest tests can't renew token, so we
  # use a long one
  token_expiration => '2400',
}
class { '::openstack_integration::glance':
  backend => 'rbd',
}
include ::openstack_integration::neutron
class { '::openstack_integration::nova':
  libvirt_rbd => true,
}
class { '::openstack_integration::cinder':
  backend => 'rbd',
}
class { '::openstack_integration::ceilometer':
  enable_legacy_telemetry =>  $enable_legacy_telemetry
}
include ::openstack_integration::aodh
if $enable_vitrage {
  include ::openstack_integration::vitrage
}
include ::openstack_integration::ceph
include ::openstack_integration::heat
include ::openstack_integration::provision
if ! $enable_legacy_telemetry {
  include ::openstack_integration::redis
  include ::openstack_integration::gnocchi
  include ::openstack_integration::panko
}

class { '::openstack_integration::tempest':
  cinder     => true,
  gnocchi    => ! $enable_legacy_telemetry,
  ceilometer => true,
  aodh       => true,
  heat       => true,
  panko      => ! $enable_legacy_telemetry,
  vitrage    => $enable_vitrage,
}
