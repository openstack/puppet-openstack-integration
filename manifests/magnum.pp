# Configure the Magnum service
#
# [*cert_manager_type*]
#   (optional) Cert manager to use
#   Can be 'barbican', 'x509keypair' or 'local'.
#   Defaults to 'barbican'.
#

class openstack_integration::magnum (
  $cert_manager_type = 'barbican'
) {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'magnum':
    password => 'an_even_bigger_secret',
    before   => Anchor['magnum::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'magnum':
      notify  => Service['httpd'],
      require => Anchor['magnum::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { 'magnum::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9511",
    internal_url => "${::openstack_integration::config::base_url}:9511",
    admin_url    => "${::openstack_integration::config::base_url}:9511",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }

  class { 'magnum::keystone::keystone_auth':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
  }

  class { 'magnum::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }

  class { 'magnum::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'magnum',
    host     => $::openstack_integration::config::host,
  }

  class { 'magnum::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'magnum',
      'password' => 'magnum',
      'database' => 'magnum',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }

  class { 'magnum::keystone::domain':
    domain_password => 'oh_my_no_secret',
  }

  class { 'magnum::logging':
    debug => true,
  }

  class { 'magnum':
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'magnum',
      'password'  => 'an_even_bigger_secret',
    }),
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'magnum',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
  }

  class { 'magnum::api':
    host         => $::openstack_integration::config::host,
    service_name => 'httpd',
  }
  class { 'magnum::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/magnum/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }

  class { 'magnum::conductor':
    workers => 2,
  }
  class { 'magnum::client': }
  class { 'magnum::certificates':
    cert_manager_type => $cert_manager_type
  }
  class { 'magnum::clients': }

}
