class openstack_integration::mistral {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'mistral':
    password => 'an_even_bigger_secret',
    before   => Anchor['mistral::service::begin'],
  }
  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'mistral':
      notify  => Service['httpd'],
      require => Package['mistral-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }
  class { 'mistral::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { 'mistral::logging':
    debug => true,
  }
  class { 'mistral::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'mistral',
      'password' => 'mistral',
      'database' => 'mistral',
      'charset'  => 'utf8',
    }),
  }
  class { 'mistral':
    default_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'mistral',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
  }
  class { 'mistral::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8989/v2",
    admin_url    => "${::openstack_integration::config::base_url}:8989/v2",
    internal_url => "${::openstack_integration::config::base_url}:8989/v2",
    password     => 'a_big_secret',
  }
  class { 'mistral::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'mistral',
    host     => $::openstack_integration::config::host,
  }
  class { 'mistral::api':
    service_name => 'httpd',
  }
  include apache
  class { 'mistral::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/mistral/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
    threads   => 1,
  }
  class { 'mistral::client': }
  class { 'mistral::engine': }
  class { 'mistral::executor': }
  class { 'mistral::event_engine': }

}
