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
      require => Anchor['watcher::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }
  class { 'watcher::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'watcher',
    host     => $::openstack_integration::config::host,
  }
  class { 'watcher::cache':
    backend          => $::openstack_integration::config::cache_driver,
    enabled          => true,
    memcache_servers => $::openstack_integration::config::memcache_servers,
    redis_server     => $::openstack_integration::config::redis_server,
    redis_password   => 'a_big_secret',
    redis_sentinels  => $::openstack_integration::config::redis_sentinel_server,
    tls_enabled      => $::openstack_integration::config::cache_tls_enabled,
  }
  class { 'watcher::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'watcher',
      'password' => 'watcher',
      'database' => 'watcher',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'watcher::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9322",
    admin_url    => "${::openstack_integration::config::base_url}:9322",
    internal_url => "${::openstack_integration::config::base_url}:9322",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class {'watcher::keystone::authtoken':
    password                     => 'a_big_secret',
    auth_version                 => 'v3',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => "${::openstack_integration::config::keystone_admin_uri}/v3",
    www_authenticate_uri         => "${::openstack_integration::config::keystone_auth_uri}/v3",
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
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
  }
  class { 'watcher::watcher_clients_auth':
    password            => 'a_big_secret',
    project_domain_name => 'Default',
    user_domain_name    => 'Default',
    project_name        => 'services',
    auth_url            => "${::openstack_integration::config::keystone_admin_uri}/v3",
  }
  class { 'watcher::api':
    upgrade_db   => true,
    service_name => 'httpd',
  }
  class { 'watcher::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/watcher/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'watcher::applier':
    applier_workers => 2,
  }
  class { 'watcher::decision_engine':
    decision_engine_workers => 2,
  }
  class { 'watcher::cron::db_purge': }

}
