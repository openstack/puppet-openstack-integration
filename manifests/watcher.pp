class openstack_integration::watcher {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'watcher':
    admin    => true,
    password => 'my_secret',
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
  }
  rabbitmq_user_permissions { 'watcher@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['rabbitmq'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'watcher':
      require => Package['watcher'],
    }
  }
  class { '::watcher::db::mysql':
    password => 'watcher',
  }
  class { '::watcher::db':
    database_connection => 'mysql+pymysql://watcher:watcher@127.0.0.1/watcher?charset=utf8',
  }
  # TODO: Support SSL
  class { '::watcher::keystone::auth':
    password     => 'a_big_secret',
    public_url   => "http://${::openstack_integration::config::ip_for_url}:9322",
    admin_url    => "http://${::openstack_integration::config::ip_for_url}:9322",
    internal_url => "http://${::openstack_integration::config::ip_for_url}:9322",
  }
  class {'::watcher::keystone::authtoken':
    password            => 'a_big_secret',
    auth_version        => 'v3',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => "${::openstack_integration::config::keystone_admin_uri}/v3",
    auth_uri            => "${::openstack_integration::config::keystone_auth_uri}/v3",
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }
  class { '::watcher::logging':
    debug => true,
  }
  class { '::watcher':
    default_transport_url => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'watcher',
      'password'  => 'my_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
  }
  class { '::watcher::api':
    watcher_api_bind_host   => $::openstack_integration::config::host,
    watcher_client_password => 'a_big_secret',
    upgrade_db              => true,
  }
  class { '::watcher::applier':
    applier_workers => '2',
  }
  class { '::watcher::decision_engine':
    decision_engine_workers => '2',
  }

}
