# Configure the Placement service

class openstack_integration::placement {

  include ::openstack_integration::config
  include ::openstack_integration::params

  include ::placement

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'placement':
      notify  => Service['httpd'],
      require => Package['placement-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { '::placement::db::mysql':
    password => 'placement',
  }

  if ($::os_package_type == 'debian') {
    class { '::placement::keystone::auth':
      public_url   => "${::openstack_integration::config::base_url}:8778",
      internal_url => "${::openstack_integration::config::base_url}:8778",
      admin_url    => "${::openstack_integration::config::base_url}:8778",
      password     => 'a_big_secret',
    }
  } else {
    class { '::placement::keystone::auth':
      public_url   => "${::openstack_integration::config::base_url}:8778/placement",
      internal_url => "${::openstack_integration::config::base_url}:8778/placement",
      admin_url    => "${::openstack_integration::config::base_url}:8778/placement",
      password     => 'a_big_secret',
    }
  }
  class { '::placement::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { '::placement::logging':
    debug => true,
  }
  class { '::placement::db':
    database_connection => 'mysql+pymysql://placement:placement@127.0.0.1/placement?charset=utf8',
  }
  include ::placement::db::sync
  include ::apache
  if ($::os_package_type != 'debian') {
    class { '::placement::wsgi::apache':
      bind_host => $::openstack_integration::config::ip_for_url,
      api_port  => '8778',
      ssl_key   => "/etc/placement/ssl/private/${::fqdn}.pem",
      ssl_cert  => $::openstack_integration::params::cert_path,
      ssl       => $::openstack_integration::config::ssl,
      workers   => '2',
    }
  }
}
