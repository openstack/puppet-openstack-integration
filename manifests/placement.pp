# Configure the Placement service

class openstack_integration::placement {

  include openstack_integration::config
  include openstack_integration::params

  include placement

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'placement':
      notify  => Service['httpd'],
      require => Package['placement-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  include placement::client
  class { 'placement::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'placement',
    host     => $::openstack_integration::config::host,
  }

  class { 'placement::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8778",
    internal_url => "${::openstack_integration::config::base_url}:8778",
    admin_url    => "${::openstack_integration::config::base_url}:8778",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'placement::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'placement::logging':
    debug => true,
  }
  class { 'placement::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'placement',
      'password' => 'placement',
      'database' => 'placement',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  include placement::db::sync
  # TODO(tkajinam): Remove this once lp bug 1987984 is fixed.
  if $facts['os']['name'] == 'Ubuntu' {
    class { 'placement::policy':
      purge_config => true
    }
  }
  include placement::api
  include apache
  if ($facts['os']['name'] != 'Debian') {
    class { 'placement::wsgi::apache':
      bind_host => $::openstack_integration::config::host,
      ssl_key   => "/etc/placement/ssl/private/${facts['networking']['fqdn']}.pem",
      ssl_cert  => $::openstack_integration::params::cert_path,
      ssl       => $::openstack_integration::config::ssl,
      workers   => 2,
    }
  }
}
