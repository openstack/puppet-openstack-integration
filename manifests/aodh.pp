# Configure the Aodh service
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $::os_service_default.
#
class openstack_integration::aodh (
  $notification_topics = $::os_service_default,
) {

  include ::openstack_integration::config
  include ::openstack_integration::params

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

  # gnocchi is not packaged in Ubuntu Cloud Archive
  # https://bugs.launchpad.net/cloud-archive/+bug/1535740
  if $::osfamily == 'RedHat' {
    $gnocchi_url = "${::openstack_integration::config::ip_for_url}:8041"
  } else {
    $gnocchi_url = undef
  }
  class { '::aodh':
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
    amqp_sasl_mechanisms       => 'PLAIN',
    debug                      => true,
    database_connection        => 'mysql+pymysql://aodh:aodh@127.0.0.1/aodh?charset=utf8',
    gnocchi_url                => $gnocchi_url,
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
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
  class { '::aodh::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { '::aodh::api':
    enabled      => true,
    service_name => 'httpd',
    sync_db      => true,
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
    auth_url      => $::openstack_integration::config::keystone_auth_uri,
    auth_password => 'a_big_secret',
  }
  class { '::aodh::client': }
  class { '::aodh::notifier': }
  class { '::aodh::listener': }
  class { '::aodh::evaluator':
    evaluation_interval => 10,
  }

}
