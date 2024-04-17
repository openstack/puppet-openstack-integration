class openstack_integration::trove {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'trove':
    password => 'an_even_bigger_secret',
    before   => Anchor['trove::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'trove':
      notify  => Service['httpd'],
      require => Package['trove'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { 'trove::logging':
    debug => true,
  }
  class { 'trove::cache':
    backend          => $::openstack_integration::config::cache_driver,
    enabled          => true,
    memcache_servers => $::openstack_integration::config::memcache_servers,
    redis_server     => $::openstack_integration::config::redis_server,
    redis_password   => 'a_big_secret',
    redis_sentinels  => $::openstack_integration::config::redis_sentinel_server,
    tls_enabled      => $::openstack_integration::config::cache_tls_enabled,
  }
  class { 'trove::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'trove',
      'password' => 'trove',
      'database' => 'trove',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'trove':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'trove',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'trove',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
  }
  class { 'trove::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'trove',
    host     => $::openstack_integration::config::host,
  }
  class { 'trove::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8779/v1.0/%(tenant_id)s",
    internal_url => "${::openstack_integration::config::base_url}:8779/v1.0/%(tenant_id)s",
    admin_url    => "${::openstack_integration::config::base_url}:8779/v1.0/%(tenant_id)s",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'trove::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'trove::service_credentials':
    password => 'a_big_secret',
    auth_url => $::openstack_integration::config::keystone_auth_uri,
  }
  class { 'trove::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/trove/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'trove::api':
    bind_host    => $::openstack_integration::config::host,
    service_name => 'httpd',
  }
  class { 'trove::client': }
  class { 'trove::conductor':
    workers => 2,
  }
  class { 'trove::guestagent::service_credentials':
    password => 'a_big_secret',
    auth_url => $::openstack_integration::config::keystone_auth_uri
  }
  class { 'trove::taskmanager': }
  class { 'trove::quota': }
}
