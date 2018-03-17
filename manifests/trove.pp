class openstack_integration::trove {

  include ::openstack_integration::config
  include ::openstack_integration::params

  openstack_integration::mq_user { 'trove':
    password => 'an_even_bigger_secret',
    before   => Anchor['trove::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'trove':
      require => Package['trove'],
    }
    $key_file = "/etc/trove/ssl/private/${::fqdn}.pem"
    $crt_file = $::openstack_integration::params::cert_path
    File[$key_file] ~> Service<| tag == 'trove-service' |>
    Exec['update-ca-certificates'] ~> Service<| tag == 'trove-service' |>
  } else {
    $key_file = undef
    $crt_file = undef
  }

  class { '::trove':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'trove',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'trove',
      'password'  => 'an_even_bigger_secret',
    }),
    database_connection        => 'mysql+pymysql://trove:trove@127.0.0.1/trove?charset=utf8',
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms       => 'PLAIN',
    nova_proxy_admin_pass      => 'a_big_secret',
  }
  class { '::trove::db::mysql':
    password => 'trove',
  }
  class { '::trove::keystone::auth':
    password     => 'a_big_secret',
    public_url   => "${::openstack_integration::config::base_url}:8779/v1.0/%(tenant_id)s",
    internal_url => "${::openstack_integration::config::base_url}:8779/v1.0/%(tenant_id)s",
    admin_url    => "${::openstack_integration::config::base_url}:8779/v1.0/%(tenant_id)s",
  }
  class { '::trove::keystone::authtoken':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }
  class { '::trove::api':
    bind_host => $::openstack_integration::config::host,
    debug     => true,
    workers   => 2,
    cert_file => $crt_file,
    key_file  => $key_file,
  }
  class { '::trove::client': }
  class { '::trove::conductor':
    debug    => true,
    workers  => 2,
    auth_url => $::openstack_integration::config::keystone_auth_uri,
  }
  class { '::trove::taskmanager':
    debug                   => true,
    auth_url                => $::openstack_integration::config::keystone_auth_uri,
    use_guestagent_template => false,
  }
  class { '::trove::quota': }
}
