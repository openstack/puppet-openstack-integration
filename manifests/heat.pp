class openstack_integration::heat {

  rabbitmq_user { 'heat':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'heat@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::heat':
    rabbit_userid       => 'heat',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => '127.0.0.1',
    database_connection => 'mysql+pymysql://heat:heat@127.0.0.1/heat?charset=utf8',
    identity_uri        => 'http://127.0.0.1:35357/',
    keystone_password   => 'a_big_secret',
    debug               => true,
    verbose             => true,
  }
  class { '::heat::db::mysql':
    password => 'heat',
  }
  class { '::heat::keystone::auth':
    password                  => 'a_big_secret',
    configure_delegated_roles => true,
  }
  class { '::heat::keystone::domain':
    domain_password => 'oh_my_no_secret',
  }
  Keystone_user_role['heat_admin::heat@::heat'] -> File['/root/openrc']
  class { '::heat::client': }
  class { '::heat::api':
    workers => '2',
  }
  class { '::heat::engine':
    auth_encryption_key => '1234567890AZERTYUIOPMLKJHGFDSQ12',
  }
  class { '::heat::api_cloudwatch':
    workers => '2',
  }
  class { '::heat::api_cfn':
    workers => '2',
  }

}
