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
    password => 'a_big_secret',
  }
  class { '::nova':
    database_connection     => 'mysql+pymysql://nova:nova@127.0.0.1/nova?charset=utf8',
    api_database_connection => 'mysql+pymysql://nova_api:nova@127.0.0.1/nova_api?charset=utf8',
    rabbit_host             => '127.0.0.1',
    rabbit_userid           => 'nova',
    rabbit_password         => 'an_even_bigger_secret',
    glance_api_servers      => 'localhost:9292',
    verbose                 => true,
    debug                   => true,
    notification_driver     => 'messagingv2',
    notify_on_state_change  => 'vm_and_task_state',
  }
  class { '::nova::api':
    admin_password                       => 'a_big_secret',
    identity_uri                         => 'http://127.0.0.1:35357/',
    osapi_v3                             => true,
    neutron_metadata_proxy_shared_secret => 'a_big_secret',
    osapi_compute_workers                => 2,
    metadata_workers                     => 2,
    default_floating_pool                => 'public',
    sync_db_api                          => true,
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
  class { '::nova::vncproxy': }

  # Nova versions are different on Ubuntu & RedHat systems.
  # RedHat packaging is more recent than Ubuntu.
  # Recent Nova in Mitaka requires keystone v3 credentials.
  # See LP #1542486 for more details.
  # Drop this case when Ubuntu will update Mitaka packaging.
  case $::osfamily {
    'Debian': {
      class { '::nova::network::neutron':
        neutron_auth_url    => 'http://127.0.0.1:35357',
        neutron_auth_plugin => 'password',
        neutron_password    => 'a_big_secret',
      }
    }
    'RedHat': {
      class { '::nova::network::neutron':
        neutron_password => 'a_big_secret',
      }
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

}
