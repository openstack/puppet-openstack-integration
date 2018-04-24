class openstack_integration::zaqar {

  include ::openstack_integration::config

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'zaqar':
      notify  => Service['httpd'],
      require => Package['zaqar-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }
  class {'::zaqar::logging':
    debug => true,
  }
  class { '::zaqar::db::mysql':
    password => 'zaqar',
  }
  class { '::zaqar::keystone::auth':
    password     => 'a_big_secret',
    roles        => ['admin', 'ResellerAdmin'],
    public_url   => "${::openstack_integration::config::base_url}:8888",
    internal_url => "${::openstack_integration::config::base_url}:8888",
    admin_url    => "${::openstack_integration::config::base_url}:8888",
  }
  class { '::zaqar::keystone::auth_websocket':
    password     => 'a_big_secret',
    public_url   => "ws://${::openstack_integration::config::ip_for_url}:8888",
    internal_url => "ws://${::openstack_integration::config::ip_for_url}:8888",
    admin_url    => "ws://${::openstack_integration::config::ip_for_url}:8888",
  }
  class {'::zaqar::management::sqlalchemy':
    uri => 'mysql+pymysql://zaqar:zaqar@127.0.0.1/zaqar?charset=utf8',
  }
  class {'::zaqar::messaging::swift':
    auth_url => "${::openstack_integration::config::keystone_auth_uri}/v3",
    uri      => 'swift://zaqar:a_big_secret@/services',
  }
  class {'::zaqar::keystone::authtoken':
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    password             => 'a_big_secret',
  }
  class {'::zaqar':
    unreliable       => true,
    management_store => 'sqlalchemy',
    message_store    => 'swift',
  }
  class {'::zaqar::server':
    service_name => 'httpd',
  }
  include ::apache
  class { '::zaqar::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_cert  => $::openstack_integration::params::cert_path,
    ssl_key   => "/etc/zaqar/ssl/private/${::fqdn}.pem",
    workers   => 2,
  }
  include ::zaqar::db::sync
  # run a second instance using websockets, the Debian system does
  # not support the use of services to run a second instance.
  if $::osfamily == 'RedHat' {
    zaqar::server_instance{ '1':
      transport => 'websocket'
    }
  }

}
