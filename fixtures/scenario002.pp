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

if ($::os['family'] == 'Debian') {
  $wsgi_mod_package = 'libapache2-mod-wsgi-py3'
  $wsgi_mod_lib     = 'mod_wsgi.so'
}
elsif ($::os['name'] == 'Fedora') or
  ($::os['family'] == 'RedHat' and Integer.new($::os['release']['major']) > 7) {
  $wsgi_mod_package = 'python3-mod_wsgi'
  $wsgi_mod_lib     = 'mod_wsgi_python3.so'
}
if ($::os['family'] == 'Debian') or ($::os['name'] == 'Fedora') or
  ($::os['family'] == 'RedHat' and Integer.new($::os['release']['major']) > 7) {
  include ::apache::params
  class { '::apache':
    mod_packages => merge($::apache::params::mod_packages, {
      'wsgi' => $wsgi_mod_package,
    }),
    mod_libs     => merge($::apache::params::mod_libs, {
      'wsgi' => $wsgi_mod_lib,
    })
  }
}

if ($::os['name'] == 'Ubuntu') or ($::os['name'] == 'Fedora') or
  ($::os['family'] == 'RedHat' and Integer.new($::os['release']['major']) > 7) {
  # FIXME(ykarel) Disable SSL until services are ready to work with SSL + Python3
  $ssl = false
} else {
  $ssl = true
}

case $::osfamily {
  'Debian': {
    $ipv6             = false
    # ec2api is not packaged on UCA
    $ec2api_enabled   = false
  }
  'RedHat': {
    $ipv6               = true
    $ec2api_enabled     = true
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

include ::openstack_integration
class { '::openstack_integration::config':
  ssl  => $ssl,
  ipv6 => $ipv6,
}
if $ssl {
  include ::openstack_integration::cacert
}
include ::openstack_integration::memcached
include ::openstack_integration::rabbitmq
include ::openstack_integration::mysql
include ::openstack_integration::keystone
class { '::openstack_integration::glance':
  backend => 'swift',
}
include ::openstack_integration::neutron
include ::openstack_integration::swift
include ::openstack_integration::ironic
include ::openstack_integration::zaqar
include ::openstack_integration::provision

include ::openstack_integration::nova_placement
class { '::openstack_integration::nova':
  volume_encryption             => true,
  placement_database_connection => 'mysql+pymysql://nova_placement:nova@127.0.0.1/nova_placement?charset=utf8',
}

class { '::openstack_integration::cinder':
  volume_encryption => true,
  cinder_backup     => 'swift',
}

include ::openstack_integration::barbican

if $ec2api_enabled {
  include ::openstack_integration::ec2api
}

class { '::openstack_integration::tempest':
  cinder                  => true,
  cinder_backup           => true,
  swift                   => true,
  ironic                  => true,
  zaqar                   => true,
  attach_encrypted_volume => true,
  ec2api                  => $ec2api_enabled,
}
