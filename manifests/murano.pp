class openstack_integration::murano {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { ['murano', 'murano_private']:
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }

  rabbitmq_vhost { '/murano':
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
  }

  rabbitmq_user_permissions { ['murano@/', 'murano_private@/murano']:
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => [ Class['::rabbitmq'], Rabbitmq_vhost['/murano'] ],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'murano':
      require => Package['murano-common'],
    }
    $key_file = "/etc/murano/ssl/private/${::fqdn}.pem"
    $crt_file = $::openstack_integration::params::cert_path
    File[$key_file] ~> Service<| tag == 'murano-service' |>
    Exec['update-ca-certificates'] ~> Service<| tag == 'murano-service' |>
  } else {
    $key_file = undef
    $crt_file = undef
  }

  class { '::murano::db::mysql':
    password => 'a_big_secret',
  }

  class { '::murano':
    admin_password        => 'a_big_secret',
    default_transport_url => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'murano',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_os_use_ssl     => $::openstack_integration::config::ssl,
    rabbit_own_user       => 'murano_private',
    rabbit_own_password   => 'an_even_bigger_secret',
    rabbit_own_vhost      => '/murano',
    rabbit_own_host       => $::openstack_integration::config::host,
    rabbit_own_port       => $::openstack_integration::config::rabbit_port,
    rabbit_own_use_ssl    => $::openstack_integration::config::ssl,
    database_connection   => 'mysql://murano:a_big_secret@127.0.0.1/murano?charset=utf8',
    identity_uri          => $::openstack_integration::config::keystone_admin_uri,
    auth_uri              => $::openstack_integration::config::keystone_auth_uri,
    use_ssl               => $::openstack_integration::config::ssl,
    service_host          => $::openstack_integration::config::ip_for_url,
    cert_file             => $crt_file,
    key_file              => $key_file,
    debug                 => true,
  }

  class { '::murano::api':
    host => $::openstack_integration::config::host,
  }

  class { '::murano::engine': }

  class { '::murano::keystone::auth':
    password     => 'a_big_secret',
    public_url   => "${::openstack_integration::config::base_url}:8082",
    internal_url => "${::openstack_integration::config::base_url}:8082",
    admin_url    => "${::openstack_integration::config::base_url}:8082",
  }
  -> murano::application { 'io.murano': }
}
