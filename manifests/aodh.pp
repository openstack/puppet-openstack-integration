# Configure the Aodh service
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
class openstack_integration::aodh (
  $notification_topics = $facts['os_service_default'],
) {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'aodh':
    password => 'an_even_bigger_secret',
    before   => Anchor['aodh::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'aodh':
      notify  => Service['httpd'],
      require => Package['aodh'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { 'aodh::logging':
    debug => true,
  }
  class { 'aodh::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'aodh',
      'password' => 'aodh',
      'database' => 'aodh',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'aodh':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'aodh',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'aodh',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
  }
  class { 'aodh::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'aodh',
    host     => $::openstack_integration::config::host,
  }
  class { 'aodh::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8042",
    internal_url => "${::openstack_integration::config::base_url}:8042",
    admin_url    => "${::openstack_integration::config::base_url}:8042",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'aodh::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'aodh::api':
    enabled      => true,
    service_name => 'httpd',
    sync_db      => true,
  }
  class { 'aodh::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/aodh/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'aodh::service_credentials':
    auth_url => $::openstack_integration::config::keystone_auth_uri,
    password => 'a_big_secret',
  }
  class { 'aodh::client': }
  class { 'aodh::notifier':
    workers => 2,
  }
  class { 'aodh::listener':
    workers => 2,
  }
  class { 'aodh::coordination':
    backend_url => $::openstack_integration::config::tooz_url,
  }
  class { 'aodh::evaluator':
    evaluation_interval => 10,
    workers             => 2,
  }
  class { 'aodh::expirer': }

}
