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

if $::osfamily == 'RedHat' {
  # (amoralej) - disable selinux defaults until
  # https://tickets.puppetlabs.com/browse/PUP-7559 is fixed
  Concat { selinux_ignore_defaults => true }
  File { selinux_ignore_defaults => true }
}

case $::osfamily {
  'Debian': {
    $ipv6            = false
    # mistral is not packaged on Ubuntu Trusty
    $mistral_enabled = false
    # murano package should be fixed on Ubuntu Xenial
    $murano_enabled  = false
    # trove package contains broken Tempest tests
    $trove_enabled   = false

    # TODO(tobias-urdin): Ubuntu Train packages has not moved out Sahara
    # plugins to its own packages.
    if $::operatingsystem == 'Ubuntu' {
      $sahara_integration_enable = false
    } else {
      $sahara_integration_enable = true
    }
  }
  'RedHat': {
    $ipv6                      = true
    $mistral_enabled           = true
    # NOTE(mnaser): We need to figure out why Murano won't accept credentials
    #               and how to get it to work with Keystone V3.
    $murano_enabled            = false
    $trove_enabled             = true
    $sahara_integration_enable = true
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

if ($::operatingsystem == 'Ubuntu') and (versioncmp($::operatingsystemmajrelease, '16') >= 0) {
  # Disable Designate MDS on Ubuntu until we find why Puppet run is not
  # idempotent sometimes.
  $designate_enabled = false
} else {
  $designate_enabled = true
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
include ::openstack_integration::glance
# RHEL8 has an issue with linuxbridge driver https://bugzilla.redhat.com/show_bug.cgi?id=1720637
if ($::os['family'] == 'RedHat' and Integer.new($::os['release']['major']) > 7) {
  $neutron_driver = undef
} else {
  $neutron_driver = 'linuxbridge'
}

class { '::openstack_integration::neutron':
  driver => $neutron_driver,
}
include ::openstack_integration::placement
include ::openstack_integration::nova
if $trove_enabled {
  include ::openstack_integration::trove
}
include ::openstack_integration::horizon
include ::openstack_integration::heat
class { '::openstack_integration::sahara':
  integration_enable => $sahara_integration_enable,
}
if $designate_enabled {
  include ::openstack_integration::designate
}
if $murano_enabled {
  include ::openstack_integration::murano
}
if $mistral_enabled {
  include ::openstack_integration::mistral
}
include ::openstack_integration::provision

class { '::openstack_integration::tempest':
  designate => $designate_enabled,
  trove     => $trove_enabled,
  mistral   => $mistral_enabled,
  sahara    => $sahara_integration_enable,
  horizon   => true,
  murano    => $murano_enabled,
  heat      => true,
}
