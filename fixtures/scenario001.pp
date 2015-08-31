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

Exec { logoutput => 'on_failure' }

# Common resources
case $::osfamily {
  'Debian': {
    include ::apt
    apt::ppa { 'ppa:ubuntu-cloud-archive/liberty-staging':
      # it's false by default in 2.x series but true in 1.8.x
      package_manage => false,
    }
    Exec['apt_update'] -> Package<||>
  }
  'RedHat': {
    class { '::openstack_extras::repo::redhat::redhat':
      manage_rdo => false,
      repo_hash  => {
        # we need kilo repo to be installed for dependencies
        'rdo-kilo'    => {
          'baseurl'  => 'https://repos.fedorapeople.org/repos/openstack/openstack-kilo/el7/',
          'descr'    => 'RDO kilo',
          'gpgcheck' => 'no',
        },
        'rdo-liberty' => {
          'baseurl'  => 'http://trunk.rdoproject.org/centos7/current/',
          'descr'    => 'RDO trunk',
          'gpgcheck' => 'no',
        },
      },
    }
    package { 'openstack-selinux': ensure => 'latest' }
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

# Deploy MySQL Server
class { '::mysql::server': }

# Deploy Keystone
class { '::keystone::client': }
class { '::keystone::cron::token_flush': }
class { '::keystone::db::mysql':
  password => 'keystone',
}
class { '::keystone':
  verbose             => true,
  debug               => true,
  database_connection => 'mysql://keystone:keystone@127.0.0.1/keystone',
  admin_token         => 'admin_token',
  enabled             => true,
  service_name        => 'httpd',
  default_domain      => 'default_domain',
}
include ::apache
class { '::keystone::wsgi::apache':
  ssl => false,
}
class { '::keystone::roles::admin':
  email    => 'test@example.tld',
  password => 'a_big_secret',
}
class { '::keystone::endpoint':
  default_domain => 'admin',
}

class { '::tempest':
  debug               => true,
  use_stderr          => false,
  log_file            => 'tempest.log',
  tempest_clone_owner => 'jenkins',
  git_clone           => false,
  tempest_clone_path  => '/tmp/openstack/tempest',
  lock_path           => '/tmp/openstack/tempest',
  tempest_config_file => '/tmp/openstack/tempest/etc/tempest.conf',
  configure_images    => false,
  configure_networks  => false,
  identity_uri        => 'http://127.0.0.1:5000/v2.0',
  identity_uri_v3     => 'http://127.0.0.1:5000/v3',
  admin_username      => 'admin',
  admin_tenant_name   => 'openstack',
  admin_password      => 'a_big_secret',
  admin_domain_name   => 'default_domain',
  auth_version        => 'v3',
  cinder_available    => false,
  glance_available    => false,
  horizon_available   => false,
  nova_available      => false,
}
