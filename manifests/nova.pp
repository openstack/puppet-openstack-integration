class openstack_integration::nova {

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
  class { '::nova::keystone::auth':
    password => 'a_big_secret',
  }
  class { '::nova':
    database_connection    => 'mysql+pymysql://nova:nova@127.0.0.1/nova?charset=utf8',
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
    osapi_compute_workers                => 2,
    ec2_workers                          => 2,
    metadata_workers                     => 2,
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

}
