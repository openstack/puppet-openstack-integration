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

if $facts['os']['name'] == 'Ubuntu' {
  $ssl = false
} else {
  $ssl = true
}

case $facts['os']['family'] {
  'Debian': {
    $ipv6 = false
    # TODO(tkajinam): Need additional work to load the plugins
    $bgpvpn_enabled = false
    $l2gw_enabled = false
    $bgp_dragent_enabled = false
  }
  'RedHat': {
    $ipv6 = true
    $bgpvpn_enabled = true
    $l2gw_enabled = true
    $bgp_dragent_enabled = true
  }
  default: {
    fail("Unsupported osfamily (${facts['os']['family']})")
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
class { 'openstack_integration::glance':
  backend => 'swift',
}
class { 'openstack_integration::neutron':
  bgpvpn_enabled      => $bgpvpn_enabled,
  l2gw_enabled        => $l2gw_enabled,
  bgp_dragent_enabled => $bgp_dragent_enabled,
}
include openstack_integration::placement
class { 'openstack_integration::nova':
  libvirt_rbd => true,
}

class { 'openstack_integration::ceph':
  deploy_rgw    => true,
  create_cephfs => true,
  ceph_pools    => ['glance', 'nova'],
}
class { 'openstack_integration::horizon':
  octavia_enabled => true
}
include openstack_integration::watcher
class { 'openstack_integration::manila':
  backend => 'cephfsnative'
}
include openstack_integration::octavia

include openstack_integration::provision

# Don't test swift, radosgw won't pass the current tests
# Glance, nova, neutron are true by default.
class { 'openstack_integration::tempest':
  horizon        => true,
  watcher        => true,
  bgpvpn         => $bgpvpn_enabled,
  l2gw           => $l2gw_enabled,
  l2gw_switch    => 'cell08-5930-01::FortyGigE1/0/1|100',
  dr             => $bgp_dragent_enabled,
  manila         => true,
  share_protocol => 'CEPHFS',
  octavia        => true,
}
