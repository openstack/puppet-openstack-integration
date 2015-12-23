class openstack_integration::ceilometer {

  rabbitmq_user { 'ceilometer':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'ceilometer@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

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
    workers => '2',
  }
  class { '::ceilometer::collector': }
  class { '::ceilometer::expirer': }
  class { '::ceilometer::agent::notification': }
  class { '::ceilometer::agent::polling': }
  class { '::ceilometer::agent::auth':
    auth_password => 'a_big_secret',
    auth_url      => 'http://127.0.0.1:5000/v2.0',
  }

}
