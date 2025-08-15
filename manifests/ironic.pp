# Configure the Ironic service
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
# [*inspector_backend*]
#   (optional) The storage backend for storing introspection data.
#   Defaults to 'database'.
#
# [*send_power_notifications*]
#   (optional) Send power notifications to Nova.
#   Defaults to false
#
class openstack_integration::ironic (
  $notification_topics      = $facts['os_service_default'],
  $inspector_backend        = 'database',
  $send_power_notifications = false,
) {

  include openstack_integration::config
  include openstack_integration::params

  if $openstack_integration::config::ssl {
    if $facts['os']['family'] != 'RedHat' {
      # TODO(tkajinam): ironic-inspector can enable ssl with use_ssl and
      #                 ssl options from oslo.service
      fail('ssl is supported only in CentOS and RHEL')
    }

    openstack_integration::ssl_key { 'ironic':
      notify  => Service['httpd'],
      require => Anchor['ironic::install::end'],
    }
    openstack_integration::ssl_key { 'ironic-inspector':
      notify  => Service['httpd'],
      require => Anchor['ironic-inspector::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  # ironic
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
      'host'     => $openstack_integration::config::ip_for_url,
      'username' => 'ironic',
      'password' => 'ironic',
      'database' => 'ironic',
      'charset'  => 'utf8',
      'extra'    => $openstack_integration::config::db_extra,
    }),
  }
  class { 'ironic::glance':
    auth_url => $openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }
  class { 'ironic::neutron':
    auth_url => $openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }
  class { 'ironic::service_catalog':
    auth_url => $openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }
  class { 'ironic::swift':
    auth_url => $openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }
  class { 'ironic::nova':
    auth_url                 => $openstack_integration::config::keystone_admin_uri,
    password                 => 'a_big_secret',
    send_power_notifications => $send_power_notifications,
  }
  class { 'ironic::cinder':
    auth_url => $openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }

  class { 'ironic':
    default_transport_url      => os_transport_url({
      'transport' => $openstack_integration::config::messaging_default_proto,
      'host'      => $openstack_integration::config::host,
      'port'      => $openstack_integration::config::messaging_default_port,
      'username'  => 'ironic',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $openstack_integration::config::messaging_notify_proto,
      'host'      => $openstack_integration::config::host,
      'port'      => $openstack_integration::config::messaging_notify_port,
      'username'  => 'ironic',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $openstack_integration::config::ssl,
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
  }
  class { 'ironic::db::mysql':
    charset  => $openstack_integration::params::mysql_charset,
    collate  => $openstack_integration::params::mysql_collate,
    password => 'ironic',
    host     => $openstack_integration::config::host,
  }
  class { 'ironic::keystone::auth':
    public_url   => "${openstack_integration::config::base_url}:6385",
    internal_url => "${openstack_integration::config::base_url}:6385",
    admin_url    => "${openstack_integration::config::base_url}:6385",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'ironic::api::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'ironic::client': }
  class { 'ironic::api':
    service_name => 'httpd',
  }
  class { 'ironic::wsgi::apache':
    bind_host => $openstack_integration::config::host,
    ssl       => $openstack_integration::config::ssl,
    ssl_key   => "/etc/ironic/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $openstack_integration::params::cert_path,
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
  class { 'ironic::vnc':
    host_ip       => $openstack_integration::config::host,
    public_url    => "${openstack_integration::config::base_url}:6090/vnc_auto.html",
    enable_ssl    => $openstack_integration::config::ssl,
    ssl_cert_file => $openstack_integration::params::cert_path,
    ssl_key_file  => "/etc/ironic/ssl/private/${facts['networking']['fqdn']}.pem",
  }

  # shared
  class { 'ironic::pxe': }

  # ironic-inspector
  class { 'ironic::keystone::auth_inspector':
    public_url   => "${openstack_integration::config::base_url}:5050",
    internal_url => "${openstack_integration::config::base_url}:5050",
    admin_url    => "${openstack_integration::config::base_url}:5050",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'ironic::inspector::db::mysql':
    charset  => $openstack_integration::params::mysql_charset,
    collate  => $openstack_integration::params::mysql_collate,
    password => 'ironic-inspector',
    host     => $openstack_integration::config::host,
  }
  class { 'ironic::inspector::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'ironic::inspector::logging':
    debug => true,
  }
  class { 'ironic::inspector::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $openstack_integration::config::ip_for_url,
      'username' => 'ironic-inspector',
      'password' => 'ironic-inspector',
      'database' => 'ironic-inspector',
      'charset'  => 'utf8',
      'extra'    => $openstack_integration::config::db_extra,
    }),
  }
  class { 'ironic::inspector::ironic':
    password => 'a_big_secret',
    auth_url => "${openstack_integration::config::keystone_auth_uri}/v3",
  }
  class { 'ironic::inspector::swift':
    password => 'a_big_secret',
    auth_url => "${openstack_integration::config::keystone_auth_uri}/v3",
  }

  if $facts['os']['family'] == 'RedHat' {
    class { 'ironic::inspector::wsgi::apache':
      bind_host => $openstack_integration::config::host,
      ssl       => $openstack_integration::config::ssl,
      ssl_key   => "/etc/ironic-inspector/ssl/private/${facts['networking']['fqdn']}.pem",
      ssl_cert  => $openstack_integration::params::cert_path,
      workers   => 2,
    }
    $standalone = false
    Service['memcached'] -> Anchor['ironic-inspector::service::begin']
  } else {
    $standalone = true
  }
  class { 'ironic::inspector':
    listen_address        => $openstack_integration::config::host,
    default_transport_url => os_transport_url({
      'transport' => $openstack_integration::config::messaging_default_proto,
      'host'      => $openstack_integration::config::host,
      'port'      => $openstack_integration::config::messaging_default_port,
      'username'  => 'ironic',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $openstack_integration::config::ssl,
    standalone            => $standalone,
    dnsmasq_interface     => 'eth0',
    store_data            => $inspector_backend,
  }
  class { 'ironic::inspector::coordination':
    backend_url => "memcached://${openstack_integration::config::ip_for_url}:11211",
  }
  class { 'ironic::inspector::client': }
}
