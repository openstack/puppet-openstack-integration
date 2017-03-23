class openstack_integration::ironic {

  include ::openstack_integration::config
  include ::openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'ironic':
      notify  => Service['httpd'],
      require => Package['ironic-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  rabbitmq_user { 'ironic':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'ironic@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  # https://bugs.launchpad.net/ironic/+bug/1564075
  Rabbitmq_user_permissions['ironic@/'] -> Service<| tag == 'ironic-service' |>

  class { '::ironic':
    default_transport_url => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'ironic',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    database_connection   => 'mysql+pymysql://ironic:ironic@127.0.0.1/ironic?charset=utf8',
    debug                 => true,
  }
  class { '::ironic::db::mysql':
    password => 'ironic',
  }
  class { '::ironic::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:6385",
    internal_url => "${::openstack_integration::config::base_url}:6385",
    admin_url    => "${::openstack_integration::config::base_url}:6385",
    password     => 'a_big_secret',
  }
  class { '::ironic::api::authtoken':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }
  class { '::ironic::client': }
  class { '::ironic::api':
    service_name => 'httpd',
  }
  include ::apache
  class { '::ironic::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/ironic/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { '::ironic::conductor':
    enabled_drivers       => ['fake', 'pxe_ipmitool'],
  }
  Rabbitmq_user_permissions['ironic@/'] -> Service<| tag == 'ironic-service' |>

}
