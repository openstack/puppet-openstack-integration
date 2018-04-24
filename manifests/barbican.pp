class openstack_integration::barbican {

  include ::openstack_integration::config
  include ::openstack_integration::params

  openstack_integration::mq_user { 'barbican':
    password => 'an_even_bigger_secret',
    before   => Anchor['barbican::service::begin'],
  }

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
  class { '::barbican::keystone::authtoken':
    password             => 'a_big_secret',
    auth_url             => "${::openstack_integration::config::keystone_admin_uri}/v3",
    www_authenticate_uri => "${::openstack_integration::config::keystone_auth_uri}/v3",
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
  }
  class { '::barbican::api':
    default_transport_url       => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'barbican',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url  => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'barbican',
      'password'  => 'an_even_bigger_secret',
    }),
    host_href                   => "${::openstack_integration::config::base_url}:9311",
    auth_strategy               => 'keystone',
    service_name                => 'httpd',
    enabled_certificate_plugins => ['simple_certificate'],
    db_auto_create              => false,
    rabbit_use_ssl              => $::openstack_integration::config::ssl,
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
