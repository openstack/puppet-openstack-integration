class openstack_integration::aodh {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'aodh':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'aodh@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  # https://bugs.launchpad.net/aodh/+bug/1557154
  Rabbitmq_user_permissions['aodh@/'] -> Service<| tag == 'aodh-service' |>

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'aodh':
      notify  => Service['httpd'],
      require => Package['aodh'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  # gnocchi is not packaged in Ubuntu Cloud Archive
  # https://bugs.launchpad.net/cloud-archive/+bug/1535740
  if $::osfamily == 'RedHat' {
    $gnocchi_url = "${::openstack_integration::config::ip_for_url}:8041"
  } else {
    $gnocchi_url = undef
  }
  class { '::aodh':
    rabbit_userid       => 'aodh',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_port         => $::openstack_integration::config::rabbit_port,
    rabbit_use_ssl      => $::openstack_integration::config::ssl,
    verbose             => true,
    debug               => true,
    rabbit_host         => $::openstack_integration::config::ip_for_url,
    database_connection => 'mysql+pymysql://aodh:aodh@127.0.0.1/aodh?charset=utf8',
    gnocchi_url         => $gnocchi_url,
  }
  class { '::aodh::db::mysql':
    password => 'aodh',
  }
  class { '::aodh::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8042",
    internal_url => "${::openstack_integration::config::base_url}:8042",
    admin_url    => "${::openstack_integration::config::base_url}:8042",
    password     => 'a_big_secret',
  }
  class { '::aodh::api':
    enabled               => true,
    keystone_password     => 'a_big_secret',
    keystone_identity_uri => $::openstack_integration::config::keystone_admin_uri,
    keystone_auth_uri     => $::openstack_integration::config::keystone_admin_uri,
    service_name          => 'httpd',
  }
  include ::apache
  class { '::aodh::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/aodh/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { '::aodh::auth':
    auth_url      => "${::openstack_integration::config::keystone_auth_uri}/v2.0",
    auth_password => 'a_big_secret',
  }
  class { '::aodh::client': }
  class { '::aodh::notifier': }
  class { '::aodh::listener': }
  class { '::aodh::evaluator': }
  class { '::aodh::db::sync': }

}
