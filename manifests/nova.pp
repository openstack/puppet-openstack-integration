# Configure the Nova service
#
# [*libvirt_rbd*]
#   (optional) Boolean to configure or not Nova
#   to use Libvirt RBD backend.
#   Defaults to false.
#
# [*libvirt_virt_type*]
#   (optional) Libvirt domain type. Options are: kvm, lxc, qemu, uml, xen
#   Defaults to 'qemu'
#
# [*libvirt_cpu_mode*]
#   (optional) The libvirt CPU mode to configure.
#   Possible values include custom, host-model, none, host-passthrough.
#   Defaults to 'none'
#
# [*volume_encryption*]
#   (optional) Boolean to configure or not volume encryption
#   Defaults to false.
#
class openstack_integration::nova (
  $libvirt_rbd       = false,
  $libvirt_virt_type = 'qemu',
  $libvirt_cpu_mode  = 'none',
  $volume_encryption = false,
) {

  include ::openstack_integration::config
  include ::openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'nova':
      notify  => Service['httpd'],
      require => Package['nova-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  rabbitmq_user { 'nova':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'nova@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }
  Rabbitmq_user_permissions['nova@/'] -> Service<| tag == 'nova-service' |>

  class { '::nova::db::mysql':
    password => 'nova',
  }
  class { '::nova::db::mysql_api':
    password => 'nova',
  }
  class { '::nova::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8774/v2.1",
    internal_url => "${::openstack_integration::config::base_url}:8774/v2.1",
    admin_url    => "${::openstack_integration::config::base_url}:8774/v2.1",
    password     => 'a_big_secret',
  }
  class { '::nova::keystone::authtoken':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }
  class { '::nova':
    default_transport_url   => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'nova',
      'password'  => 'an_even_bigger_secret',
    }),
    database_connection     => 'mysql+pymysql://nova:nova@127.0.0.1/nova?charset=utf8',
    api_database_connection => 'mysql+pymysql://nova_api:nova@127.0.0.1/nova_api?charset=utf8',
    rabbit_use_ssl          => $::openstack_integration::config::ssl,
    use_ipv6                => $::openstack_integration::config::ipv6,
    glance_api_servers      => "${::openstack_integration::config::base_url}:9292",
    debug                   => true,
    notification_driver     => 'messagingv2',
    notify_on_state_change  => 'vm_and_task_state',
  }
  class { '::nova::api':
    api_bind_address                     => $::openstack_integration::config::host,
    neutron_metadata_proxy_shared_secret => 'a_big_secret',
    metadata_workers                     => 2,
    default_floating_pool                => 'public',
    sync_db_api                          => true,
    service_name                         => 'httpd',
  }
  include ::apache
  class { '::nova::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl_key   => "/etc/nova/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    ssl       => $::openstack_integration::config::ssl,
    workers   => '2',
  }
  class { '::nova::client': }
  class { '::nova::conductor': }
  class { '::nova::consoleauth': }
  class { '::nova::cron::archive_deleted_rows': }
  if $volume_encryption {
    $keymgr_api_class     = 'castellan.key_manager.barbican_key_manager.BarbicanKeyManager'
    $keymgr_auth_endpoint = "${::openstack_integration::config::keystone_auth_uri}/v3"
    $barbican_endpoint    = "${::openstack_integration::config::base_url}:9311"
  } else {
    $keymgr_api_class     = undef
    $keymgr_auth_endpoint = undef
    $barbican_endpoint    = undef
  }
  class { '::nova::compute':
    vnc_enabled                 => true,
    instance_usage_audit        => true,
    instance_usage_audit_period => 'hour',
    keymgr_api_class            => $keymgr_api_class,
    barbican_auth_endpoint      => $keymgr_auth_endpoint,
    barbican_endpoint           => $barbican_endpoint,
  }
  class { '::nova::compute::libvirt':
    libvirt_virt_type     => $libvirt_virt_type,
    libvirt_cpu_mode      => $libvirt_cpu_mode,
    migration_support     => true,
    vncserver_listen      => '0.0.0.0',
    # TODO: enable it again when puppet 4.5 will be idempotent
    # https://tickets.puppetlabs.com/browse/PUP-6370
    virtlock_service_name => false,
    virtlog_service_name  => false,
  }
  if $libvirt_rbd {
    class { '::nova::compute::rbd':
      libvirt_rbd_user        => 'openstack',
      libvirt_rbd_secret_uuid => '7200aea0-2ddd-4a32-aa2a-d49f66ab554c',
      libvirt_rbd_secret_key  => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
      libvirt_images_rbd_pool => 'nova',
      rbd_keyring             => 'client.openstack',
      # ceph packaging is already managed by puppet-ceph
      manage_ceph_client      => false,
    }
    # make sure ceph pool exists before running nova-compute
    Exec['create-nova'] -> Service['nova-compute']
  }
  class { '::nova::scheduler': }
  class { '::nova::scheduler::filter': }
  class { '::nova::vncproxy': }

  class { '::nova::network::neutron':
    neutron_auth_url => "${::openstack_integration::config::keystone_admin_uri}/v3",
    neutron_url      => "${::openstack_integration::config::base_url}:9696",
    neutron_password => 'a_big_secret',
  }

}
