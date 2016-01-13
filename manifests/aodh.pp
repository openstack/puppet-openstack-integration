class openstack_integration::aodh {

  rabbitmq_user { 'aodh':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'aodh@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  # Aodh is not yet packaged in UCA, but only in RDO.
  case $::osfamily {
    'Debian': {
      class { '::ceilometer::alarm::evaluator': }
      class { '::ceilometer::alarm::notifier': }
    }
    'RedHat': {
      class { '::aodh':
        rabbit_userid       => 'aodh',
        rabbit_password     => 'an_even_bigger_secret',
        verbose             => true,
        debug               => true,
        rabbit_host         => '127.0.0.1',
        database_connection => 'mysql+pymysql://aodh:aodh@127.0.0.1/aodh?charset=utf8',
      }
      class { '::aodh::db::mysql':
        password => 'aodh',
      }
      class { '::aodh::keystone::auth':
        password => 'a_big_secret',
      }
      class { '::aodh::api':
        enabled               => true,
        keystone_password     => 'a_big_secret',
        keystone_identity_uri => 'http://127.0.0.1:35357/',
        keystone_auth_uri     => 'http://127.0.0.1:35357/',
        service_name          => 'httpd',
      }
      class { '::aodh::wsgi::apache':
        ssl => false,
      }
      class { '::aodh::auth':
        auth_url      => 'http://127.0.0.1:5000/v2.0',
        auth_password => 'a_big_secret',
      }
      class { '::aodh::client': }
      class { '::aodh::notifier': }
      class { '::aodh::listener': }
      class { '::aodh::evaluator': }
      class { '::aodh::db::sync': }
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

}
