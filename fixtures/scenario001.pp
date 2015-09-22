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
        'openstack-common-testing'  => {
          'baseurl'  => 'http://cbs.centos.org/repos/cloud7-openstack-common-testing/x86_64/os/',
          'descr'    => 'openstack-common-testing',
          'gpgcheck' => 'no',
        },
        'openstack-liberty-testing' => {
          'baseurl'  => 'http://cbs.centos.org/repos/cloud7-openstack-liberty-testing/x86_64/os/',
          'descr'    => 'openstack-liberty-testing',
          'gpgcheck' => 'no',
        },
        'openstack-liberty-trunk'   => {
          'baseurl'  => 'http://trunk.rdoproject.org/centos7-liberty/current-passed-ci/',
          'descr'    => 'openstack-liberty-trunk',
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
rabbitmq_user { ['neutron', 'nova', 'cinder', 'ceilometer', 'glance']:
  admin    => true,
  password => 'an_even_bigger_secret',
  provider => 'rabbitmqctl',
  require  => Class['rabbitmq'],
}
rabbitmq_user_permissions { ['neutron@/', 'nova@/', 'cinder@/', 'ceilometer@/', 'glance@/']:
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
  ssl     => false,
  workers => 4,
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
  workers             => 4,
}
class { '::glance::registry':
  debug               => true,
  verbose             => true,
  database_connection => 'mysql://glance:glance@127.0.0.1/glance?charset=utf8',
  keystone_password   => 'a_big_secret',
  workers             => 4,
}
class { '::glance::notify::rabbitmq':
  rabbit_userid       => 'glance',
  rabbit_password     => 'an_even_bigger_secret',
  rabbit_host         => '127.0.0.1',
  notification_driver => 'messagingv2',
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
  api_workers         => 4,
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
  debug            => true,
  auth_password    => 'a_big_secret',
  shared_secret    => 'a_big_secret',
  metadata_workers => 4,
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
  database_connection    => 'mysql://nova:nova@127.0.0.1/nova?charset=utf8',
  rabbit_host            => '127.0.0.1',
  rabbit_userid          => 'nova',
  rabbit_password        => 'an_even_bigger_secret',
  glance_api_servers     => 'localhost:9292',
  verbose                => true,
  debug                  => true,
  notification_driver    => 'messagingv2',
  notify_on_state_change => 'vm_and_task_state',
}
class { '::nova::api':
  admin_password                       => 'a_big_secret',
  identity_uri                         => 'http://127.0.0.1:35357/',
  osapi_v3                             => true,
  neutron_metadata_proxy_shared_secret => 'a_big_secret',
  osapi_compute_workers                => 4,
  ec2_workers                          => 4,
  metadata_workers                     => 4,
  default_floating_pool                => 'public',
}
class { '::nova::cert': }
class { '::nova::client': }
class { '::nova::conductor': }
class { '::nova::consoleauth': }
class { '::nova::cron::archive_deleted_rows': }
class { '::nova::compute':
  vnc_enabled                 => true,
  instance_usage_audit        => true,
  instance_usage_audit_period => 'hour',
}
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

# Deploy Cinder
class { '::cinder::db::mysql':
  password => 'cinder',
}
class { '::cinder::keystone::auth':
  password => 'a_big_secret',
}
class { '::cinder':
  database_connection => 'mysql://cinder:cinder@127.0.0.1/cinder?charset=utf8',
  rabbit_host         => '127.0.0.1',
  rabbit_userid       => 'cinder',
  rabbit_password     => 'an_even_bigger_secret',
  verbose             => true,
  debug               => true,
}
class { '::cinder::api':
  keystone_password   => 'a_big_secret',
  identity_uri        => 'http://127.0.0.1:35357/',
  default_volume_type => 'BACKEND_1',
  service_workers     => 4,
}
class { '::cinder::quota': }
class { '::cinder::scheduler': }
class { '::cinder::scheduler::filter': }
class { '::cinder::volume': }
class { '::cinder::cron::db_purge': }
class { '::cinder::glance':
  glance_api_servers  => 'localhost:9292',
}
class { '::cinder::setup_test_volume':
  size => '15G',
}
cinder::backend::iscsi { 'BACKEND_1':
  iscsi_ip_address => '127.0.0.1',
}
class { '::cinder::backends':
  enabled_backends => ['BACKEND_1'],
}
Cinder::Type {
  os_password    => 'a_big_secret',
  os_tenant_name => 'services',
  os_username    => 'cinder',
  os_auth_url    => 'http://127.0.0.1:5000/v2.0',
}
cinder::type { 'BACKEND_1':
  set_key   => 'volume_backend_name',
  set_value => 'BACKEND_1',
  notify    => Service['cinder-volume'],
  require   => Service['cinder-api'],
}

# Deploy Ceilometer
class { '::ceilometer':
  metering_secret => 'secrete',
  rabbit_userid   => 'ceilometer',
  rabbit_password => 'an_even_bigger_secret',
  rabbit_host     => '127.0.0.1',
  debug           => true,
  verbose         => true,
}
class { '::ceilometer::db::mysql':
  password => 'ceilometer',
}
class { '::ceilometer::db':
  database_connection => 'mysql://ceilometer:ceilometer@127.0.0.1/ceilometer?charset=utf8',
}
class { '::ceilometer::keystone::auth':
  password => 'a_big_secret',
}
class { '::ceilometer::api':
  enabled               => true,
  keystone_password     => 'a_big_secret',
  keystone_identity_uri => 'http://127.0.0.1:35357/',
  service_name          => 'httpd',
}
class { '::ceilometer::wsgi::apache':
  ssl     => false,
  workers => '4',
}
class { '::ceilometer::collector': }
class { '::ceilometer::expirer': }
class { '::ceilometer::alarm::evaluator': }
class { '::ceilometer::alarm::notifier': }
class { '::ceilometer::agent::notification': }
class { '::ceilometer::agent::polling': }
class { '::ceilometer::agent::auth':
  auth_password => 'a_big_secret',
  auth_url      => 'http://127.0.0.1:5000/v2.0',
}

# Configure Tempest and the resources
$os_auth_options = '--os-username admin --os-password a_big_secret --os-tenant-name openstack --os-auth-url http://127.0.0.1:5000/v2.0'

exec { 'manage_m1.nano_nova_flavor':
  path     => '/usr/bin:/bin:/usr/sbin:/sbin',
  provider => shell,
  command  => "nova ${os_auth_options} flavor-create m1.nano 42 128 0 1",
  unless   => "nova ${os_auth_options} flavor-list | grep m1.nano",
}
Keystone_user_role['admin@openstack'] -> Exec['manage_m1.nano_nova_flavor']

exec { 'manage_m1.micro_nova_flavor':
  path     => '/usr/bin:/bin:/usr/sbin:/sbin',
  provider => shell,
  command  => "nova ${os_auth_options} flavor-create m1.micro 84 128 0 1",
  unless   => "nova ${os_auth_options} flavor-list | grep m1.micro",
}
Keystone_user_role['admin@openstack'] -> Exec['manage_m1.micro_nova_flavor']

neutron_network { 'public':
  tenant_name     => 'openstack',
  router_external => true,
}
Keystone_user_role['admin@openstack'] -> Neutron_network<||>

neutron_subnet { 'public-subnet':
  cidr             => '172.24.5.0/24',
  ip_version       => '4',
  allocation_pools => ['start=172.24.5.10,end=172.24.5.200'],
  gateway_ip       => '172.24.5.1',
  enable_dhcp      => false,
  network_name     => 'public',
  tenant_name      => 'openstack',
}

include ::vswitch::ovs
vs_bridge { 'br-ex':
  ensure => present,
  notify => Exec['create_br-ex_vif'],
}

# creates br-ex virtual interface to reach floating-ip network
exec { 'create_br-ex_vif':
  path        => '/usr/bin:/bin:/usr/sbin:/sbin',
  provider    => shell,
  command     => 'ip addr add 172.24.5.1/24 dev br-ex; ip link set br-ex up',
  refreshonly => true,
}

glance_image { 'cirros':
  ensure           => present,
  container_format => 'bare',
  disk_format      => 'qcow2',
  is_public        => 'yes',
  # TODO(emilien) optimization by 1/ using Hiera to configure Glance image source
  # and 2/ if running in the gate, use /home/jenkins/cache/files/ cirros image.
  # source        => '/home/jenkins/cache/files/cirros-0.3.4-x86_64-disk.img',
  source           => 'http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img',
}
glance_image { 'cirros_alt':
  ensure           => present,
  container_format => 'bare',
  disk_format      => 'qcow2',
  is_public        => 'yes',
  # TODO(emilien) optimization by 1/ using Hiera to configure Glance image source
  # and 2/ if running in the gate, use /home/jenkins/cache/files/ cirros image.
  # source        => '/home/jenkins/cache/files/cirros-0.3.4-x86_64-disk.img',
  source           => 'http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img',
}

class { '::tempest':
  debug                => true,
  use_stderr           => false,
  log_file             => 'tempest.log',
  tempest_clone_owner  => 'jenkins',
  git_clone            => false,
  tempest_clone_path   => '/tmp/openstack/tempest',
  lock_path            => '/tmp/openstack/tempest',
  tempest_config_file  => '/tmp/openstack/tempest/etc/tempest.conf',
  configure_images     => true,
  configure_networks   => true,
  identity_uri         => 'http://127.0.0.1:5000/v2.0',
  identity_uri_v3      => 'http://127.0.0.1:5000/v3',
  admin_username       => 'admin',
  admin_tenant_name    => 'openstack',
  admin_password       => 'a_big_secret',
  admin_domain_name    => 'default_domain',
  auth_version         => 'v3',
  image_name           => 'cirros',
  image_name_alt       => 'cirros_alt',
  cinder_available     => true,
  glance_available     => true,
  horizon_available    => false,
  nova_available       => true,
  neutron_available    => true,
  ceilometer_available => true,
  public_network_name  => 'public',
  flavor_ref           => '42',
  flavor_ref_alt       => '84',
  image_ssh_user       => 'cirros',
  image_alt_ssh_user   => 'cirros',
  img_file             => 'cirros-0.3.4-x86_64-disk.img',
  # TODO(emilien) optimization by 1/ using Hiera to configure Glance image source
  # and 2/ if running in the gate, use /home/jenkins/cache/files/ cirros image.
  # img_dir            => '/home/jenkins/cache/files',
  img_dir              => '/tmp/openstack/tempest',
}
