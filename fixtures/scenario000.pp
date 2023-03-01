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

# Keystone only puppet deployment

if $facts['os']['name'] == 'Ubuntu' {
  $ssl = false
} else {
  $ssl = true
}

if $facts['os']['family'] == 'RedHat' {
  # (amoralej) - disable selinux defaults until
  # https://tickets.puppetlabs.com/browse/PUP-7559 is fixed
  Concat { selinux_ignore_defaults => true }
  File { selinux_ignore_defaults => true }
}

case $facts['os']['family'] {
  'Debian': {
    $ipv6      = false
    $om_rpc    = 'rabbit'
    $om_notify = 'rabbit'
  }
  'RedHat': {
    $ipv6      = true
    $om_rpc    = 'amqp'
    $om_notify = 'rabbit'
  }
  default: {
    fail("Unsupported osfamily (${facts['os']['family']})")
  }
}

include openstack_integration
class { 'openstack_integration::config':
  ssl            => $ssl,
  ipv6           => $ipv6,
  rpc_backend    => $om_rpc,
  notify_backend => $om_notify,
}
if $ssl {
  include openstack_integration::cacert
}
include openstack_integration::apache
include openstack_integration::memcached
include openstack_integration::rabbitmq
if ($om_rpc == 'amqp') {
  include openstack_integration::qdr
}
include openstack_integration::mysql
class { 'openstack_integration::keystone':
  # NOTE(sileht): Telemetry autoscaling tempest tests can't renew token, so we
  # use a long one
  token_expiration => '2400',
}

# turn off glance, nova, neutron
class { 'openstack_integration::provision':
  glance  => false,
  nova    => false,
  neutron => false,
}

# Expected keystone resources logged to
# keystone-resources.txt
class { 'openstack_integration::tempest':
  glance             => false,
  nova               => false,
  neutron            => false,
  configure_images   => false,
  configure_networks => false,
}
