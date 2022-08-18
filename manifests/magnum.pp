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

  rabbitmq_user { 'magnum':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
  }
  rabbitmq_user_permissions { 'magnum@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['rabbitmq'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'magnum':
      require => Package['magnum-common'],
    }
    $key_file = "/etc/magnum/ssl/private/${::fqdn}.pem"
    $crt_file = $::openstack_integration::params::cert_path
    File[$key_file] ~> Service<| tag == 'magnum-service' |>
    Exec['update-ca-certificates'] ~> Service<| tag == 'magnum-service' |>
  } else {
    $key_file = undef
    $crt_file = undef
  }

  class { 'magnum::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9511",
    internal_url => "${::openstack_integration::config::base_url}:9511",
    admin_url    => "${::openstack_integration::config::base_url}:9511",
    password     => 'a_big_secret',
  }

  class { 'magnum::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => "${::openstack_integration::config::base_url}:35357/v3",
    www_authenticate_uri => "${::openstack_integration::config::base_url}:5000/v3",
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }

  class { 'magnum::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'magnum',
  }

  class { 'magnum::db':
    database_connection => 'mysql+pymysql://magnum:magnum@127.0.0.1/magnum',
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
    host          => $::openstack_integration::config::host,
    enabled_ssl   => $::openstack_integration::config::ssl,
    ssl_cert_file => $crt_file,
    ssl_key_file  => $key_file
  }

  class { 'magnum::conductor': }
  class { 'magnum::client': }
  class { 'magnum::certificates':
    cert_manager_type => $cert_manager_type
  }
  class { 'magnum::clients': }

}
