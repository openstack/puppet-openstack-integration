class openstack_integration::watcher {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'watcher':
    password => 'my_secret',
    before   => Anchor['watcher::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'watcher':
      notify  => Service['httpd'],
      require => Package['watcher'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }
  class { 'watcher::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    password => 'watcher',
  }
  class { 'watcher::db':
    database_connection => 'mysql+pymysql://watcher:watcher@127.0.0.1/watcher?charset=utf8',
  }
  # TODO: Support SSL
  class { 'watcher::keystone::auth':
    password     => 'a_big_secret',
    public_url   => "${::openstack_integration::config::base_url}:9322",
    admin_url    => "${::openstack_integration::config::base_url}:9322",
    internal_url => "${::openstack_integration::config::base_url}:9322",
  }
  class {'watcher::keystone::authtoken':
    password             => 'a_big_secret',
    auth_version         => 'v3',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => "${::openstack_integration::config::keystone_admin_uri}/v3",
    www_authenticate_uri => "${::openstack_integration::config::keystone_auth_uri}/v3",
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { 'watcher::logging':
    debug => true,
  }
  class { 'watcher':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'watcher',
      'password'  => 'my_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'watcher',
      'password'  => 'my_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms       => 'PLAIN',
  }
  class { 'watcher::watcher_clients_auth':
    password            => 'a_big_secret',
    project_domain_name => 'Default',
    user_domain_name    => 'Default',
    project_name        => 'services',
    auth_url            => "${::openstack_integration::config::keystone_admin_uri}/v3",
  }
  class { 'watcher::api':
    bind_host    => $::openstack_integration::config::host,
    upgrade_db   => true,
    service_name => 'httpd',
  }
  include apache
  class { 'watcher::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/watcher/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'watcher::applier':
    applier_workers => '2',
  }
  class { 'watcher::decision_engine':
    decision_engine_workers => '2',
  }

}
