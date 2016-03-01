# Configure the Cinder service
#
# [*libvirt_rbd*]
#   (optional) Boolean to configure or not Nova
#   to use Libvirt RBD backend.
#   Defaults to false.
#
class openstack_integration::nova (
  $libvirt_rbd = false,
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

  class { '::nova::db::mysql':
    password => 'nova',
  }
  class { '::nova::db::mysql_api':
    password => 'nova',
  }
  class { '::nova::keystone::auth':
    public_url      => "${::openstack_integration::config::proto}://127.0.0.1:8774/v2/%(tenant_id)s",
    public_url_v3   => "${::openstack_integration::config::proto}://127.0.0.1:8774/v3/%(tenant_id)s",
    internal_url    => "${::openstack_integration::config::proto}://127.0.0.1:8774/v2/%(tenant_id)s",
    internal_url_v3 => "${::openstack_integration::config::proto}://127.0.0.1:8774/v3/%(tenant_id)s",
    admin_url       => "${::openstack_integration::config::proto}://127.0.0.1:8774/v2/%(tenant_id)s",
    admin_url_v3    => "${::openstack_integration::config::proto}://127.0.0.1:8774/v3/%(tenant_id)s",
    password        => 'a_big_secret',
  }
  class { '::nova':
    database_connection     => 'mysql+pymysql://nova:nova@127.0.0.1/nova?charset=utf8',
    api_database_connection => 'mysql+pymysql://nova_api:nova@127.0.0.1/nova_api?charset=utf8',
    rabbit_host             => $::openstack_integration::config::rabbit_host,
    rabbit_port             => $::openstack_integration::config::rabbit_port,
    rabbit_userid           => 'nova',
    rabbit_password         => 'an_even_bigger_secret',
    rabbit_use_ssl          => $::openstack_integration::config::ssl,
    glance_api_servers      => "${::openstack_integration::config::proto}://127.0.0.1:9292",
    verbose                 => true,
    debug                   => true,
    notification_driver     => 'messagingv2',
    notify_on_state_change  => 'vm_and_task_state',
  }
  class { '::nova::api':
    admin_password                       => 'a_big_secret',
    auth_uri                             => $::openstack_integration::config::keystone_auth_uri,
    identity_uri                         => $::openstack_integration::config::keystone_admin_uri,
    osapi_v3                             => true,
    neutron_metadata_proxy_shared_secret => 'a_big_secret',
    metadata_workers                     => 2,
    default_floating_pool                => 'public',
    sync_db_api                          => true,
    service_name                         => 'httpd',
  }
  include ::apache
  class { '::nova::wsgi::apache':
    ssl_key  => "/etc/nova/ssl/private/${::fqdn}.pem",
    ssl_cert => $::openstack_integration::params::cert_path,
    ssl      => $::openstack_integration::config::ssl,
    workers  => '2',
  }
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
    neutron_password => 'a_big_secret',
  }

}
