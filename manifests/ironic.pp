class openstack_integration::ironic {

  include openstack_integration::config
  include openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'ironic':
      notify  => Service['httpd'],
      require => Package['ironic-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  openstack_integration::mq_user { 'ironic':
    password => 'an_even_bigger_secret',
    before   => Anchor['ironic::service::begin'],
  }
  class { 'ironic::logging':
    debug => true,
  }
  class { 'ironic::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'ironic',
      'password' => 'ironic',
      'database' => 'ironic',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'ironic':
    default_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'ironic',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms  => 'PLAIN',
  }
  class { 'ironic::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'ironic',
    host     => $::openstack_integration::config::host,
  }
  class { 'ironic::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:6385",
    internal_url => "${::openstack_integration::config::base_url}:6385",
    admin_url    => "${::openstack_integration::config::base_url}:6385",
    password     => 'a_big_secret',
  }
  class { 'ironic::api::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { 'ironic::keystone::auth_inspector':
    public_url   => "http://${::openstack_integration::config::ip_for_url}:5050",
    internal_url => "http://${::openstack_integration::config::ip_for_url}:5050",
    admin_url    => "http://${::openstack_integration::config::ip_for_url}:5050",
    password     => 'a_big_secret',
  }
  class { 'ironic::client': }
  class { 'ironic::api':
    service_name => 'httpd',
  }
  include apache
  class { 'ironic::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/ironic/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'ironic::conductor':
    enabled_hardware_types => ['fake-hardware', 'ipmi'],
  }
  class { 'ironic::drivers::interfaces':
    enabled_management_interfaces => ['fake', 'ipmitool'],
    enabled_boot_interfaces       => ['fake', 'pxe'],
    enabled_deploy_interfaces     => ['fake', 'direct'],
    enabled_power_interfaces      => ['fake', 'ipmitool'],
    enabled_vendor_interfaces     => ['fake', 'ipmitool', 'no-vendor'],
  }
  class { 'ironic::drivers::ipmi': }

  # Ironic inspector resources
  class { 'ironic::inspector::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'ironic-inspector',
    host     => $::openstack_integration::config::host,
  }
  class { 'ironic::inspector::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { 'ironic::pxe': }
  class { 'ironic::inspector::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'ironic-inspector',
      'password' => 'ironic-inspector',
      'database' => 'ironic-inspector',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'ironic::inspector::ironic':
    password => 'a_big_secret',
    auth_url => "${::openstack_integration::config::keystone_auth_uri}/v3",
  }
  class { 'ironic::inspector':
    listen_address        => $::openstack_integration::config::host,
    default_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'ironic',
      'password'  => 'an_even_bigger_secret',
    }),
    dnsmasq_interface     => 'eth0',
  }
}
