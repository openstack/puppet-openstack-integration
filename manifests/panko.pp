class openstack_integration::panko {

  include ::openstack_integration::config
  include ::openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'panko':
      notify  => Service['httpd'],
      require => Package['panko'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  include ::panko

  class { '::panko::db':
    database_connection => 'mysql+pymysql://panko:panko@127.0.0.1/panko?charset=utf8',
  }

  class { '::panko::db::mysql':
    password => 'panko',
  }
  class { '::panko::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8977",
    internal_url => "${::openstack_integration::config::base_url}:8977",
    admin_url    => "${::openstack_integration::config::base_url}:8977",
    password     => 'a_big_secret',
  }
  class { '::panko::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { '::panko::api':
    sync_db      => true,
    enabled      => true,
    service_name => 'httpd',
  }
  include ::apache
  class { '::panko::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/panko/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }

}
