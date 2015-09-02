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
    class { '::openstack_extras::repo::debian::ubuntu':
      release         => 'liberty',
      repo            => 'proposed',
      package_require => true,
    }
    $package_provider = 'apt'
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
    $package_provider = 'yum'
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

# Deploy MySQL Server
class { '::mysql::server': }

# Deploy RabbitMQ
class { '::rabbitmq':
  delete_guest_user => true,
  package_provider  => $package_provider,
}
rabbitmq_vhost { '/':
  provider => 'rabbitmqctl',
  require  => Class['rabbitmq'],
}
rabbitmq_user { ['neutron', 'nova']:
  admin    => true,
  password => 'an_even_bigger_secret',
  provider => 'rabbitmqctl',
  require  => Class['rabbitmq'],
}
rabbitmq_user_permissions { ['neutron@/', 'nova@/']:
  configure_permission => '.*',
  write_permission     => '.*',
  read_permission      => '.*',
  provider             => 'rabbitmqctl',
  require              => Class['rabbitmq'],
}

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

# Deploy Glance
class { '::glance::db::mysql':
  password => 'glance',
}
include ::glance
include ::glance::client
class { '::glance::keystone::auth':
  password => 'a_big_secret',
}
class { '::glance::api':
  debug               => true,
  verbose             => true,
  database_connection => 'mysql://glance:glance@127.0.0.1/glance?charset=utf8',
  keystone_password   => 'a_big_secret',
}
class { '::glance::registry':
  debug               => true,
  verbose             => true,
  database_connection => 'mysql://glance:glance@127.0.0.1/glance?charset=utf8',
  keystone_password   => 'a_big_secret',
}
glance_image { 'cirros':
  ensure           => present,
  container_format => 'bare',
  disk_format      => 'qcow2',
  is_public        => 'yes',
  source           => 'http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img',
}
glance_image { 'cirros_alt':
  ensure           => present,
  container_format => 'bare',
  disk_format      => 'qcow2',
  is_public        => 'yes',
  source           => 'http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img',
}

# Deploy Neutron
class { '::neutron::db::mysql':
  password => 'neutron',
}
class { '::neutron::keystone::auth':
  password => 'a_big_secret',
}
class { '::neutron':
  rabbit_user           => 'neutron',
  rabbit_password       => 'an_even_bigger_secret',
  rabbit_host           => '127.0.0.1',
  allow_overlapping_ips => true,
  core_plugin           => 'ml2',
  service_plugins       => ['router', 'metering'],
  debug                 => true,
  verbose               => true,
}
class { '::neutron::client': }
class { '::neutron::server':
  database_connection => 'mysql://neutron:neutron@127.0.0.1/neutron?charset=utf8',
  auth_password       => 'a_big_secret',
  identity_uri        => 'http://127.0.0.1:35357/',
  sync_db             => true,
}
class { '::neutron::plugins::ml2':
  type_drivers         => ['vxlan'],
  tenant_network_types => ['vxlan'],
  mechanism_drivers    => ['openvswitch'],
}
class { '::neutron::agents::ml2::ovs':
  enable_tunneling => true,
  local_ip         => '127.0.0.1',
  tunnel_types     => ['vxlan'],
}
class { '::neutron::agents::metadata':
  debug         => true,
  auth_password => 'a_big_secret',
  shared_secret => 'a_big_secret',
}
class { '::neutron::agents::lbaas':
  debug => true,
}
class { '::neutron::agents::l3':
  debug => true,
}
class { '::neutron::agents::dhcp':
  debug => true,
}
class { '::neutron::agents::metering':
  debug => true,
}
class { '::neutron::server::notifications':
  nova_admin_password => 'a_big_secret',
}

# Deploy Nova
class { '::nova::db::mysql':
  password => 'nova',
}
class { '::nova::keystone::auth':
  password => 'a_big_secret',
}
class { '::nova':
  database_connection => 'mysql://nova:nova@127.0.0.1/nova?charset=utf8',
  rabbit_host         => '127.0.0.1',
  rabbit_userid       => 'nova',
  rabbit_password     => 'an_even_bigger_secret',
  glance_api_servers  => 'localhost:9292',
  verbose             => true,
  debug               => true,
}
class { '::nova::api':
  admin_password                       => 'a_big_secret',
  identity_uri                         => 'http://127.0.0.1:35357/',
  osapi_v3                             => true,
  neutron_metadata_proxy_shared_secret => 'a_big_secret',
}
class { '::nova::cert': }
class { '::nova::client': }
class { '::nova::conductor': }
class { '::nova::consoleauth': }
class { '::nova::cron::archive_deleted_rows': }
class { '::nova::compute': vnc_enabled => true }
class { '::nova::compute::libvirt':
  libvirt_virt_type => 'qemu',
  migration_support => true,
  vncserver_listen  => '0.0.0.0',
}
class { '::nova::scheduler': }
class { '::nova::vncproxy': }
class { '::nova::network::neutron':
  neutron_admin_password => 'a_big_secret',
  neutron_admin_auth_url => 'http://127.0.0.1:35357/v2.0',
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
  configure_images    => true,
  configure_networks  => false,
  identity_uri        => 'http://127.0.0.1:5000/v2.0',
  identity_uri_v3     => 'http://127.0.0.1:5000/v3',
  admin_username      => 'admin',
  admin_tenant_name   => 'openstack',
  admin_password      => 'a_big_secret',
  admin_domain_name   => 'default_domain',
  auth_version        => 'v3',
  image_name          => 'cirros',
  image_name_alt      => 'cirros_alt',
  cinder_available    => false,
  glance_available    => true,
  horizon_available   => false,
  nova_available      => false,
}
