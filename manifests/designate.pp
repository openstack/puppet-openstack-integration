# Configure the Designate service
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
class openstack_integration::designate (
  $notification_topics = $facts['os_service_default'],
) {

  include openstack_integration::config
  include openstack_integration::params
  include openstack_integration::bind

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'designate':
      notify  => Service['httpd'],
      require => Anchor['designate::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  openstack_integration::mq_user { 'designate':
    password => 'an_even_bigger_secret',
    before   => Anchor['designate::service::begin'],
  }

  class { 'designate::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'designate',
    host     => $::openstack_integration::config::host,
  }
  class { 'designate::logging':
    debug => true,
  }
  class { 'designate':
    default_transport_url      => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'designate',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'designate',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
  }
  class { 'designate::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'designate',
      'password' => 'designate',
      'database' => 'designate',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'designate::coordination':
    backend_url => $::openstack_integration::config::tooz_url,
  }
  Class['openstack_integration::redis'] -> Anchor['designate::service::begin']

  include 'designate::client'

  class { 'designate::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9001",
    internal_url => "${::openstack_integration::config::base_url}:9001",
    admin_url    => "${::openstack_integration::config::base_url}:9001",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'designate::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }

  class { 'designate::api':
    api_base_uri     => "${::openstack_integration::config::base_url}:9001",
    auth_strategy    => 'keystone',
    enable_api_v2    => true,
    enable_api_admin => true,
    service_name     => 'httpd',
  }
  class { 'designate::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl_key   => "/etc/designate/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    ssl       => $::openstack_integration::config::ssl,
    workers   => 2,
  }

  class { 'designate::mdns':
    listen  => "${::openstack_integration::config::ip_for_url}:5354",
    workers => 2,
  }

  class { 'designate::central':
    workers => 2,
  }

  class { 'designate::producer':
    workers => 2,
  }

  class { 'designate::worker':
    workers => 2,
  }

  class { 'designate::backend::bind9':
    nameservers   => [$::openstack_integration::config::host],
    bind9_hosts   => [$::openstack_integration::config::host],
    dns_port      => 5322,
    mdns_hosts    => [$::openstack_integration::config::host],
    rndc_key_file => $::dns::rndckeypath,
  }
  Class['dns::service'] -> Anchor['designate::service::begin']
}
