# Configure the Heat service
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $::os_service_default.
#
class openstack_integration::heat (
  $notification_topics = $::os_service_default,
) {

  include ::openstack_integration::config
  include ::openstack_integration::params

  openstack_integration::mq_user { 'heat':
    password => 'an_even_bigger_secret',
    before   => Anchor['heat::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'heat':
      require => Package['heat-common'],
    }
    $key_file = "/etc/heat/ssl/private/${::fqdn}.pem"
    $crt_file = $::openstack_integration::params::cert_path
    File[$key_file] ~> Service<| tag == 'heat-service' |>
    Exec['update-ca-certificates'] ~> Service<| tag == 'heat-service' |>
  } else {
    $key_file = undef
    $crt_file = undef
  }

  class { '::heat::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { '::heat':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'heat',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'heat',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms       => 'PLAIN',
    database_connection        => 'mysql+pymysql://heat:heat@127.0.0.1/heat?charset=utf8',
    debug                      => true,
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
  }
  class { '::heat::db::mysql':
    password => 'heat',
  }
  class { '::heat::keystone::auth':
    password                  => 'a_big_secret',
    configure_delegated_roles => true,
    public_url                => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
    internal_url              => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
    admin_url                 => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
  }
  class { '::heat::keystone::domain':
    domain_password => 'oh_my_no_secret',
  }
  class { '::heat::client': }
  class { '::heat::api':
    service_name => 'httpd',
  }
  include ::apache
  class { '::heat::wsgi::apache_api':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_cert  => $crt_file,
    ssl_key   => $key_file,
    workers   => 2,
  }
  class { '::heat::engine':
    auth_encryption_key           => '1234567890AZERTYUIOPMLKJHGFDSQ12',
    heat_metadata_server_url      => "${::openstack_integration::config::base_url}:8000",
    heat_waitcondition_server_url => "${::openstack_integration::config::base_url}:8000/v1/waitcondition",
    heat_watch_server_url         => "${::openstack_integration::config::base_url}:8003",
  }
  class { '::heat::api_cfn':
    service_name => 'httpd',
  }
  class { '::heat::wsgi::apache_api_cfn':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_cert  => $crt_file,
    ssl_key   => $key_file,
    workers   => 2,
  }
  class { '::heat::cron::purge_deleted': }

}
