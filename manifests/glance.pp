class openstack_integration::glance {

  rabbitmq_user { 'glance':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'glance@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::glance::db::mysql':
    password => 'glance',
  }
  include ::glance
  include ::glance::backend::file
  include ::glance::client
  class { '::glance::keystone::auth':
    password => 'a_big_secret',
  }
  class { '::glance::api':
    debug               => true,
    verbose             => true,
    database_connection => 'mysql+pymysql://glance:glance@127.0.0.1/glance?charset=utf8',
    keystone_password   => 'a_big_secret',
    workers             => 2,
  }
  class { '::glance::registry':
    debug               => true,
    verbose             => true,
    database_connection => 'mysql+pymysql://glance:glance@127.0.0.1/glance?charset=utf8',
    keystone_password   => 'a_big_secret',
    workers             => 2,
  }
  class { '::glance::notify::rabbitmq':
    rabbit_userid       => 'glance',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => '127.0.0.1',
    notification_driver => 'messagingv2',
  }

}
