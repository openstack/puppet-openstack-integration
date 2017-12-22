#
# Copyright 2016 Red Hat, Inc.
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

# Disable SSL (workaround for Xenial)
if $::operatingsystem == 'Ubuntu' {
  $ipv6            = false
  # Watcher packages are not available in Ubuntu repository.
  $watcher_enabled = false
  # TODO(rnoriega) Enable testing for BGPVPN when UCA releases pike-m1
  $bgpvpn_enabled = false
  # TODO(tobasco): Enable l2gw on Ubuntu again when networking-l2gw has
  # been cut with a newer version.
  # See https://bugs.launchpad.net/ubuntu/+source/networking-l2gw/+bug/1739779
  $l2gw_enabled = false
} else {
  $ipv6            = true
  $watcher_enabled = true
  $bgpvpn_enabled = true
  $l2gw_enabled = true
}

include ::openstack_integration
class { '::openstack_integration::config':
  ssl  => true,
  ipv6 => $ipv6,
}

include ::openstack_integration::cacert
include ::openstack_integration::memcached
include ::openstack_integration::rabbitmq
include ::openstack_integration::mysql
class { '::openstack_integration::keystone':
  token_provider => 'fernet',
}
class { '::openstack_integration::glance':
  backend => 'swift',
}
class { '::openstack_integration::neutron':
  bgpvpn_enabled => $bgpvpn_enabled,
  l2gw_enabled   => $l2gw_enabled,
}
class { '::openstack_integration::nova':
  libvirt_rbd => true,
}

class { '::openstack_integration::ceph':
  deploy_rgw   => true,
  swift_dropin => true,
}
if $watcher_enabled {
  include ::openstack_integration::watcher
}

include ::openstack_integration::provision

# Don't test swift, radosgw won't pass the current tests
# Glance, nova, neutron are true by default.
class { '::openstack_integration::tempest':
  watcher     => $watcher_enabled,
  bgpvpn      => $bgpvpn_enabled,
  l2gw        => $l2gw_enabled,
  l2gw_switch => 'cell08-5930-01::FortyGigE1/0/1|100',
}
