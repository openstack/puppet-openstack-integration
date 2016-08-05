class openstack_integration::barbican {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'barbican':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'barbican@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }
  Rabbitmq_user_permissions['barbican@/'] -> Service<| tag == 'barbican-service' |>

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'barbican':
      notify  => Service['httpd'],
      require => Package['barbican-api'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  include ::barbican
  class { '::barbican::db::mysql':
    password => 'barbican',
  }
  class { '::barbican::db':
    database_connection => 'mysql+pymysql://barbican:barbican@127.0.0.1/barbican?charset=utf8',
  }
  class { '::barbican::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9311",
    internal_url => "${::openstack_integration::config::base_url}:9311",
    admin_url    => "${::openstack_integration::config::base_url}:9311",
    password     => 'a_big_secret',
  }
  include ::barbican::quota
  include ::barbican::keystone::notification
  class { '::barbican::api::logging':
    debug => true,
  }
  class { '::barbican::api':
    host_href                   => "${::openstack_integration::config::base_url}:9311",
    auth_type                   => 'keystone',
    keystone_password           => 'a_big_secret',
    service_name                => 'httpd',
    enabled_certificate_plugins => ['simple_certificate'],
    db_auto_create              => false,
    auth_url                    => "${::openstack_integration::config::keystone_admin_uri}/v3",
    rabbit_userid               => 'barbican',
    rabbit_password             => 'an_even_bigger_secret',
    rabbit_port                 => $::openstack_integration::config::rabbit_port,
    rabbit_use_ssl              => $::openstack_integration::config::ssl,
    rabbit_host                 => $::openstack_integration::config::ip_for_url,
  }
  # add me in puppet-barbican
  barbican_config {
    'keystone_authtoken/auth_uri': value => "${::openstack_integration::config::keystone_auth_uri}/v3";
  }
  include ::apache
  class { '::barbican::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/barbican/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }

}
