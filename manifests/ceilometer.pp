# Configure the Ceilometer service
#
# [*compute_namespace*]
#   (optional) Enable polling for the compute namespace
#   Default to true.
#
# [*integration_enable*]
#   (optional) Boolean to run integration tests.
#   Defaults to true.
#
# [*separate_polling*]
#   (optional) Use separate polling services for individual namespaces
#   Defaults to false
#
class openstack_integration::ceilometer (
  $compute_namespace  = true,
  $integration_enable = true,
  $separate_polling   = false,
){

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'ceilometer':
    password => 'an_even_bigger_secret',
    before   => Anchor['ceilometer::service::begin'],
  }

  class { 'ceilometer::logging':
    debug => true,
  }
  class { 'ceilometer::cache':
    backend          => $::openstack_integration::config::cache_driver,
    enabled          => true,
    memcache_servers => $::openstack_integration::config::memcached_servers,
    redis_server     => $::openstack_integration::config::redis_server,
    redis_password   => 'a_big_secret',
    redis_sentinels  => $::openstack_integration::config::redis_sentinel_server,
    tls_enabled      => $::openstack_integration::config::cache_tls_enabled,
  }
  class { 'ceilometer':
    telemetry_secret           => 'secrete',
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'ceilometer',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'ceilometer',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
  }
  class { 'ceilometer::keystone::auth':
    roles    => ['admin', 'service'],
    password => 'a_big_secret',
  }

  if $integration_enable {
    # Ensure Gnocchi and creads are ready before running ceilometer-upgrade
    # We use Gnocchi instead of local database, db::sync is required to populate
    # gnocchi resource types.
    include ceilometer::db::sync
    Service['httpd'] -> Exec['ceilometer-upgrade']
    Class['ceilometer::keystone::auth'] -> Exec['ceilometer-upgrade']
    Class['gnocchi::keystone::auth'] -> Exec['ceilometer-upgrade']

    $sample_pipeline_publishers = ['gnocchi://']
    $event_pipeline_publishers = ['gnocchi://']

    class { 'ceilometer::coordination':
      backend_url => $::openstack_integration::config::tooz_url,
    }
    Class['openstack_integration::redis'] -> Anchor['ceilometer::service::begin']
    class { 'ceilometer::agent::notification':
      workers                   => 2,
      manage_pipeline           => true,
      pipeline_publishers       => $sample_pipeline_publishers,
      manage_event_pipeline     => true,
      event_pipeline_publishers => $event_pipeline_publishers,
    }
    class { 'ceilometer::agent::polling':
      manage_polling    => true,
      compute_namespace => $compute_namespace,
      # NOTE(sileht): Use 1 minute instead 10 otherwise the telemetry tempest
      # tests are too long to pass in less than 1 hour.
      polling_interval  => 60,
      separate_services => $separate_polling,
    }
  } else {
    # NOTE(tobias-urdin): When running the module tests we need to exclude the
    # gnocchi resource types since the acceptance test does not setup gnocchi itself.
    class { 'ceilometer::db::sync':
      extra_params => '--skip-gnocchi-resource-types',
    }
    class { 'ceilometer::agent::notification': }
  }

  class { 'ceilometer::agent::service_credentials':
    password => 'a_big_secret',
    auth_url => $::openstack_integration::config::keystone_auth_uri,
  }

}
