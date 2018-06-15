class openstack_integration::ironic {

  include ::openstack_integration::config
  include ::openstack_integration::params

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

  class { '::ironic':
    default_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'ironic',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms  => 'PLAIN',
    database_connection   => 'mysql+pymysql://ironic:ironic@127.0.0.1/ironic?charset=utf8',
    debug                 => true,
  }
  class { '::ironic::db::mysql':
    password => 'ironic',
  }
  class { '::ironic::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:6385",
    internal_url => "${::openstack_integration::config::base_url}:6385",
    admin_url    => "${::openstack_integration::config::base_url}:6385",
    password     => 'a_big_secret',
  }
  class { '::ironic::api::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { '::ironic::keystone::auth_inspector':
    password => 'a_big_secret',
  }
  class { '::ironic::client': }
  class { '::ironic::api':
    service_name => 'httpd',
  }
  include ::apache
  class { '::ironic::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/ironic/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { '::ironic::conductor':
    enabled_hardware_types => ['fake-hardware', 'ipmi'],
  }
  class { '::ironic::drivers::interfaces':
    enabled_management_interfaces => ['fake', 'ipmitool'],
    enabled_boot_interfaces       => ['fake', 'pxe'],
    enabled_deploy_interfaces     => ['fake', 'iscsi', 'direct'],
    enabled_power_interfaces      => ['fake', 'ipmitool'],
    enabled_vendor_interfaces     => ['fake', 'ipmitool', 'no-vendor'],
  }
  class { '::ironic::drivers::ipmi': }
  Rabbitmq_user_permissions['ironic@/'] -> Service<| tag == 'ironic-service' |>
  # Ironic inspector resources
  case $::osfamily {
    'Debian': {
      warning("Ironic inspector packaging is not ready on ${::osfamily}.")
    }
    'RedHat': {
      class { '::ironic::inspector::db::mysql':
        password => 'a_big_secret',
      }
      class { '::ironic::inspector::authtoken':
        password => 'a_big_secret',
      }
      class { '::ironic::pxe': }
      class { '::ironic::inspector':
        ironic_password   => 'a_big_secret',
        ironic_auth_url   => "${::openstack_integration::config::keystone_auth_uri}/v3",
        dnsmasq_interface => 'eth0',
        db_connection     => 'mysql+pymysql://ironic-inspector:a_big_secret@127.0.0.1/ironic-inspector?charset=utf8',
      }
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }
}
