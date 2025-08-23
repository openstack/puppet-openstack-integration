# Configure the cloudkitty service
#
class openstack_integration::cloudkitty {
  include openstack_integration::config
  include openstack_integration::params

  if $openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'cloudkitty':
      notify  => Service['httpd'],
      require => Package['cloudkitty-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  openstack_integration::mq_user { 'cloudkitty':
    password => 'an_even_bigger_secret',
    before   => Anchor['cloudkitty::service::begin'],
  }

  # Cloudkitty resources
  class { 'cloudkitty::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $openstack_integration::config::ip_for_url,
      'username' => 'cloudkitty',
      'password' => 'cloudkitty',
      'database' => 'cloudkitty',
      'charset'  => 'utf8',
      'extra'    => $openstack_integration::config::db_extra,
    }),
  }
  class { 'cloudkitty::logging':
    debug => true,
  }

  class { 'cloudkitty':
    default_transport_url      => os_transport_url({
      'transport' => $openstack_integration::config::messaging_default_proto,
      'host'      => $openstack_integration::config::host,
      'port'      => $openstack_integration::config::messaging_default_port,
      'username'  => 'cloudkitty',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $openstack_integration::config::messaging_notify_proto,
      'host'      => $openstack_integration::config::host,
      'port'      => $openstack_integration::config::messaging_notify_port,
      'username'  => 'cinder',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $openstack_integration::config::ssl,
    notification_driver        => 'messagingv2',
    # NOTE(tobias-urdin): Cloudkitty in Stein has moved to storage v2 by default and the
    # only driver available is InfluxDB which we do not deploy. This sets it back to the
    # old sqlalchemy storage driver in version 1.
    storage_backend            => 'sqlalchemy',
    storage_version            => '1',
  }
  class { 'cloudkitty::keystone::auth':
    public_url   => "${openstack_integration::config::base_url}:8889",
    internal_url => "${openstack_integration::config::base_url}:8889",
    admin_url    => "${openstack_integration::config::base_url}:8889",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'cloudkitty::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'cloudkitty::db::mysql':
    charset  => $openstack_integration::params::mysql_charset,
    collate  => $openstack_integration::params::mysql_collate,
    password => 'cloudkitty',
    host     => $openstack_integration::config::host,
  }
  class { 'cloudkitty::api':
    service_name => 'httpd',
  }
  include apache
  class { 'cloudkitty::wsgi::apache':
    bind_host => $openstack_integration::config::host,
    ssl_key   => "/etc/cloudkitty/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $openstack_integration::params::cert_path,
    ssl       => $openstack_integration::config::ssl,
    workers   => 2,
  }
  class { 'cloudkitty::processor': }
  class { 'cloudkitty::orchestrator':
    coordination_url => $openstack_integration::config::tooz_url,
    max_workers      => 2,
    max_threads      => 4,
  }
  class { 'cloudkitty::fetcher::keystone':
    auth_type           => 'password',
    username            => 'cloudkitty',
    password            => 'a_big_secret',
    project_name        => 'services',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $openstack_integration::config::keystone_admin_uri,
  }
  class { 'cloudkitty::client': }
}
