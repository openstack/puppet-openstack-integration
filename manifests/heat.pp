class openstack_integration::heat {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'heat':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'heat@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'heat':
      require => Package['heat-common'],
    }
    $key_file = "/etc/heat/ssl/private/${::fqdn}.pem"
    $crt_file = $::openstack_integration::params::cert_path
    File[$key_file] ~> Service<| tag == 'heat-service' |>
    Exec['update-ca-certificates'] ~> Service<| tag == 'heat-service' |>
  } else {
    $key_file = undef
    $crt_file = undef
  }

  class { '::heat':
    rabbit_userid       => 'heat',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => $::openstack_integration::config::ip_for_url,
    rabbit_use_ssl      => $::openstack_integration::config::ssl,
    rabbit_port         => $::openstack_integration::config::rabbit_port,
    database_connection => 'mysql+pymysql://heat:heat@127.0.0.1/heat?charset=utf8',
    identity_uri        => $::openstack_integration::config::keystone_auth_uri,
    auth_plugin         => 'password',
    keystone_password   => 'a_big_secret',
    debug               => true,
  }
  class { '::heat::db::mysql':
    password => 'heat',
  }
  class { '::heat::keystone::auth':
    password                  => 'a_big_secret',
    configure_delegated_roles => true,
    public_url                => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
    internal_url              => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
    admin_url                 => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
  }
  class { '::heat::keystone::domain':
    domain_password => 'oh_my_no_secret',
  }
  Keystone_user_role['heat_admin::heat@::heat'] -> File['/root/openrc']
  class { '::heat::client': }
  class { '::heat::api':
    bind_host => $::openstack_integration::config::host,
    workers   => '2',
    use_ssl   => $::openstack_integration::config::ssl,
    cert_file => $crt_file,
    key_file  => $key_file,
  }
  class { '::heat::engine':
    auth_encryption_key           => '1234567890AZERTYUIOPMLKJHGFDSQ12',
    heat_metadata_server_url      => "${::openstack_integration::config::base_url}:8000",
    heat_waitcondition_server_url => "${::openstack_integration::config::base_url}:8000/v1/waitcondition",
    heat_watch_server_url         => "${::openstack_integration::config::base_url}:8003",
  }
  class { '::heat::api_cloudwatch':
    bind_host => $::openstack_integration::config::host,
    workers   => '2',
    use_ssl   => $::openstack_integration::config::ssl,
    cert_file => $crt_file,
    key_file  => $key_file,
  }
  class { '::heat::api_cfn':
    bind_host => $::openstack_integration::config::host,
    workers   => '2',
    use_ssl   => $::openstack_integration::config::ssl,
    cert_file => $crt_file,
    key_file  => $key_file,
  }

}
