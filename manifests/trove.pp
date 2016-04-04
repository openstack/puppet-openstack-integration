class openstack_integration::trove {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'trove':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'trove@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
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
    database_connection   => 'mysql+pymysql://trove:trove@127.0.0.1/trove?charset=utf8',
    rabbit_userid         => 'trove',
    rabbit_password       => 'an_even_bigger_secret',
    rabbit_host           => $::openstack_integration::config::ip_for_url,
    rabbit_port           => $::openstack_integration::config::rabbit_port,
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    nova_proxy_admin_pass => 'a_big_secret',
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
  class { '::trove::api':
    keystone_password => 'a_big_secret',
    auth_uri          => $::openstack_integration::config::keystone_auth_uri,
    identity_uri      => $::openstack_integration::config::keystone_admin_uri,
    debug             => true,
    verbose           => true,
    workers           => 2,
    cert_file         => $crt_file,
    key_file          => $key_file,
  }
  class { '::trove::client': }
  class { '::trove::conductor':
    debug    => true,
    verbose  => true,
    workers  => 2,
    auth_url => $::openstack_integration::config::keystone_auth_uri,
  }
  class { '::trove::taskmanager':
    debug    => true,
    verbose  => true,
    auth_url => $::openstack_integration::config::keystone_auth_uri,
  }

}
