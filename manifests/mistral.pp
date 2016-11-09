class openstack_integration::mistral {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'mistral':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
  }

  rabbitmq_user_permissions { 'mistral@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['rabbitmq'],
  }

  if $::osfamily == 'RedHat' {
    if $::openstack_integration::config::ssl {
      openstack_integration::ssl_key { 'mistral':
        notify  => Service['httpd'],
        require => Package['mistral-common'],
      }
      Exec['update-ca-certificates'] ~> Service['httpd']
    }
    class { '::mistral':
      default_transport_url => os_transport_url({
        'transport' => 'rabbit',
        'host'      => $::openstack_integration::config::host,
        'port'      => $::openstack_integration::config::rabbit_port,
        'username'  => 'mistral',
        'password'  => 'an_even_bigger_secret',
      }),
      database_connection   => 'mysql+pymysql://mistral:mistral@127.0.0.1/mistral?charset=utf8',
      keystone_password     => 'a_big_secret',
      rabbit_use_ssl        => $::openstack_integration::config::ssl,
      # if it works, we might need to change the default in puppet-mistral
      identity_uri          => $::openstack_integration::config::keystone_admin_uri,
      auth_uri              => "${::openstack_integration::config::keystone_auth_uri}/v3",
      debug                 => true,
    }
    class { '::mistral::keystone::auth':
      public_url   => "${::openstack_integration::config::base_url}:8989/v2",
      admin_url    => "${::openstack_integration::config::base_url}:8989/v2",
      internal_url => "${::openstack_integration::config::base_url}:8989/v2",
      password     => 'a_big_secret',
    }
    class { '::mistral::db::mysql':
      password => 'mistral',
    }
    class { '::mistral::api':
      service_name => 'httpd',
    }
    include ::apache
    class { '::mistral::wsgi::apache':
      bind_host => $::openstack_integration::config::ip_for_url,
      ssl       => $::openstack_integration::config::ssl,
      ssl_key   => "/etc/mistral/ssl/private/${::fqdn}.pem",
      ssl_cert  => $::openstack_integration::params::cert_path,
      workers   => 2,
    }
    class { '::mistral::client': }
    class { '::mistral::engine': }
    class { '::mistral::executor': }
    class { '::mistral::db::sync': }
  }

}
