# Configure the Heat service
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
class openstack_integration::heat (
  $notification_topics = $facts['os_service_default'],
) {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'heat':
    password => 'an_even_bigger_secret',
    before   => Anchor['heat::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'heat':
      notify  => Service['httpd'],
      require => Anchor['heat::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { 'heat::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'heat::trustee':
    password         => 'a_big_secret',
    auth_url         => $::openstack_integration::config::keystone_admin_uri,
    user_domain_name => 'Default',
  }
  class { 'heat::logging':
    debug => true,
  }
  class { 'heat::cache':
    backend          => $::openstack_integration::config::cache_driver,
    enabled          => true,
    memcache_servers => $::openstack_integration::config::memcache_servers,
    redis_server     => $::openstack_integration::config::redis_server,
    redis_password   => 'a_big_secret',
    redis_sentinels  => $::openstack_integration::config::redis_sentinel_server,
    tls_enabled      => $::openstack_integration::config::cache_tls_enabled,
  }
  class { 'heat::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'heat',
      'password' => 'heat',
      'database' => 'heat',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'heat':
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
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
  }
  class { 'heat::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'heat',
    host     => $::openstack_integration::config::host,
  }
  class { 'heat::keystone::auth':
    public_url                => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
    internal_url              => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
    admin_url                 => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
    roles                     => ['admin', 'service'],
    password                  => 'a_big_secret',
    configure_delegated_roles => true,
  }
  class { 'heat::keystone::auth_cfn':
    password            => 'a_big_secret',
    # NOTE(tkajinam): heat-cfn service user is not used
    configure_user      => false,
    configure_user_role => false,
    public_url          => "${::openstack_integration::config::base_url}:8000/v1",
    internal_url        => "${::openstack_integration::config::base_url}:8000/v1",
    admin_url           => "${::openstack_integration::config::base_url}:8000/v1",
  }
  class { 'heat::keystone::domain':
    domain_password => 'oh_my_no_secret',
  }
  class { 'heat::client': }
  class { 'heat::api':
    service_name => 'httpd',
  }
  class { 'heat::wsgi::apache_api':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_cert  => $::openstack_integration::params::cert_path,
    ssl_key   => "/etc/heat/ssl/private/${facts['networking']['fqdn']}.pem",
    workers   => 2,
  }
  class { 'heat::engine':
    num_engine_workers            =>  2,
    auth_encryption_key           => '1234567890AZERTYUIOPMLKJHGFDSQ12',
    heat_metadata_server_url      => "${::openstack_integration::config::base_url}:8000",
    heat_waitcondition_server_url => "${::openstack_integration::config::base_url}:8000/v1/waitcondition",
  }
  class { 'heat::api_cfn':
    service_name => 'httpd',
  }
  class { 'heat::wsgi::apache_api_cfn':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_cert  => $::openstack_integration::params::cert_path,
    ssl_key   => "/etc/heat/ssl/private/${facts['networking']['fqdn']}.pem",
    workers   => 2,
  }
  class { 'heat::cron::purge_deleted': }

}
