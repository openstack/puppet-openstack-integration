class openstack_integration::trove {

  rabbitmq_user { 'trove':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'trove@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::trove':
    database_connection   => 'mysql+pymysql://trove:trove@127.0.0.1/trove?charset=utf8',
    rabbit_userid         => 'trove',
    rabbit_password       => 'an_even_bigger_secret',
    rabbit_host           => '127.0.0.1',
    nova_proxy_admin_pass => 'a_big_secret',
  }
  class { '::trove::db::mysql':
    password => 'trove',
  }
  class { '::trove::keystone::auth':
    password => 'a_big_secret',
  }
  class { '::trove::api':
    keystone_password => 'a_big_secret',
    auth_url          => 'http://127.0.0.1:35357/',
    debug             => true,
    verbose           => true,
    workers           => 2,
  }
  class { '::trove::client': }
  class { '::trove::conductor':
    debug   => true,
    verbose => true,
  }
  class { '::trove::taskmanager':
    debug   => true,
    verbose => true,
  }

}
