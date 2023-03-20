class openstack_integration::murano {

  include openstack_integration::config
  include openstack_integration::params

  $application_package_path = $facts['os']['family'] ? {
    'RedHat' => '/var/cache/murano/meta',
    default  => '/usr/share/murano-common',
  }

  rabbitmq_user { ['murano', 'murano_private']:
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
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
    require              => [ Class['rabbitmq'], Rabbitmq_vhost['/murano'] ],
  }

  if $::openstack_integration::config::messaging_default_proto == 'amqp' {
    qdr_user { 'murano':
      password => 'an_even_bigger_secret',
      provider => 'sasl',
      require  => Class['qdr'],
    }
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'murano':
      notify  => Service['murano-api'],
      require => Package['murano-common'],
    }
    Exec['update-ca-certificates'] ~> Service['murano-api']
  }

  class { 'murano::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'murano',
    host     => $::openstack_integration::config::host,
  }
  class { 'murano::logging':
    debug => true,
  }
  class { 'murano::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'murano',
      'password' => 'murano',
      'database' => 'murano',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'murano::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { 'murano':
    default_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
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
    use_ssl               => $::openstack_integration::config::ssl,
    service_host          => $::openstack_integration::config::ip_for_url,
    cert_file             => $::openstack_integration::params::cert_path,
    key_file              => "/etc/murano/ssl/private/${facts['networking']['fqdn']}.pem",
  }
  class { 'murano::api':
    host => $::openstack_integration::config::host,
  }

  class { 'murano::engine': }

  class { 'murano::keystone::auth':
    password     => 'a_big_secret',
    public_url   => "${::openstack_integration::config::base_url}:8082",
    internal_url => "${::openstack_integration::config::base_url}:8082",
    admin_url    => "${::openstack_integration::config::base_url}:8082",
  }
  -> murano_application { 'io.murano':
    package_path => "${application_package_path}/io.murano.zip",
  }
}
