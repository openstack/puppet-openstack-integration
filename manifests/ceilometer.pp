class openstack_integration::ceilometer {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'ceilometer':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'ceilometer@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'ceilometer':
      notify  => Service['httpd'],
      require => Package['ceilometer-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { '::ceilometer':
    telemetry_secret => 'secrete',
    rabbit_userid    => 'ceilometer',
    rabbit_password  => 'an_even_bigger_secret',
    rabbit_host      => $::openstack_integration::config::ip_for_url,
    rabbit_port      => $::openstack_integration::config::rabbit_port,
    rabbit_use_ssl   => $::openstack_integration::config::ssl,
    debug            => true,
    verbose          => true,
  }
  class { '::ceilometer::db::mysql':
    password => 'ceilometer',
  }
  class { '::ceilometer::db':
    database_connection => 'mysql+pymysql://ceilometer:ceilometer@127.0.0.1/ceilometer?charset=utf8',
  }
  class { '::ceilometer::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8777",
    internal_url => "${::openstack_integration::config::base_url}:8777",
    admin_url    => "${::openstack_integration::config::base_url}:8777",
    password     => 'a_big_secret',
  }
  class { '::ceilometer::api':
    enabled           => true,
    keystone_password => 'a_big_secret',
    identity_uri      => $::openstack_integration::config::keystone_admin_uri,
    auth_uri          => $::openstack_integration::config::keystone_auth_uri,
    service_name      => 'httpd',
  }
  include ::apache
  class { '::ceilometer::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/keystone/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => '2',
  }
  class { '::ceilometer::collector':
    collector_workers => '2',
  }
  class { '::ceilometer::expirer': }
  class { '::ceilometer::agent::notification':
    notification_workers => '2',
  }
  class { '::ceilometer::agent::polling': }
  class { '::ceilometer::agent::auth':
    auth_password => 'a_big_secret',
    auth_url      => "${::openstack_integration::config::keystone_auth_uri}/v2.0",
  }

}
