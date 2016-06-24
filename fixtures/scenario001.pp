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
    $ipv6               = false
    # we need https://review.openstack.org/#/c/318503/ backported in Mitaka / UCA
    $ceilometer_enabled = false
    # gnocchi is not packaged in Ubuntu Cloud Archive
    # https://bugs.launchpad.net/cloud-archive/+bug/1535740
    $gnocchi_enabled    = false
  }
  'RedHat': {
    $ipv6               = true
    $ceilometer_enabled = true
    $gnocchi_enabled    = true
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

# List of workarounds for Ubuntu Xenial:
# - disable ceph
# - disable SSL
if ($::operatingsystem == 'Ubuntu') and (versioncmp($::operatingsystemmajrelease, '16') >= 0) {
  $ssl_enabled    = false
  $glance_backend = 'file'
  $cinder_backend = 'iscsi'
  $libvirt_rbd    = false
} else {
  $ssl_enabled    = true
  $glance_backend = 'rbd'
  $cinder_backend = 'rbd'
  $libvirt_rbd    = true
}

include ::openstack_integration
class { '::openstack_integration::config':
  ssl  => $ssl_enabled,
  ipv6 => $ipv6,
}
include ::openstack_integration::cacert
include ::openstack_integration::rabbitmq
include ::openstack_integration::mysql
include ::openstack_integration::keystone
class { '::openstack_integration::glance':
  backend => $glance_backend,
}
class { '::openstack_integration::neutron':
  lbaasv2 => true
}
class { '::openstack_integration::nova':
  libvirt_rbd => $libvirt_rbd,
}
class { '::openstack_integration::cinder':
  backend => $cinder_backend,
}
if $ceilometer_enabled {
  include ::openstack_integration::ceilometer
  include ::openstack_integration::aodh
  include ::openstack_integration::gnocchi
}
if $libvirt_rbd {
  include ::openstack_integration::ceph
}
include ::openstack_integration::provision

class { '::openstack_integration::tempest':
  cinder     => true,
  ceilometer => $ceilometer_enabled,
  aodh       => $ceilometer_enabled,
  gnocchi    => $gnocchi_enabled,
}
