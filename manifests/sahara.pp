class openstack_integration::sahara {

  rabbitmq_user { 'sahara':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'sahara@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::sahara::db::mysql':
    password => 'sahara',
  }
  class { '::sahara::keystone::auth':
    password     => 'a_big_secret',
  }
  class { '::sahara':
    database_connection => 'mysql+pymysql://sahara:sahara@127.0.0.1/sahara?charset=utf8',
    # two plugins because of hardcode in tempest:
    # https://github.com/openstack/tempest/blob/master/tempest/config.py#L923
    plugins             => ['vanilla', 'hdp'],
    rabbit_userid       => 'sahara',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => '127.0.0.1',
    rpc_backend         => 'rabbit',
    admin_password      => 'a_big_secret',
    admin_user          => 'sahara',
    admin_tenant_name   => 'services',
    debug               => true,
    verbose             => true,
  }
  class { '::sahara::service::api':
    api_workers => 2,
  }
  class { '::sahara::service::engine': }
  class { '::sahara::client': }
  class { '::sahara::notify':
    enable_notifications => true,
  }

}
