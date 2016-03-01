class openstack_integration::ironic {

  include ::openstack_integration::config

  rabbitmq_user { 'ironic':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'ironic@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::ironic':
    rabbit_userid       => 'ironic',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => '127.0.0.1',
    rabbit_port         => $::openstack_integration::config::rabbit_port,
    rabbit_use_ssl      => $::openstack_integration::config::ssl,
    database_connection => 'mysql+pymysql://ironic:ironic@127.0.0.1/ironic?charset=utf8',
    debug               => true,
    verbose             => true,
    enabled_drivers     => ['fake', 'pxe_ssh', 'pxe_ipmitool'],
  }
  class { '::ironic::db::mysql':
    password => 'ironic',
  }
  class { '::ironic::keystone::auth':
    password => 'a_big_secret',
  }
  class { '::ironic::client': }
  class { '::ironic::api':
    admin_password => 'a_big_secret',
    workers        => '2',
  }
  class { '::ironic::conductor': }

}
