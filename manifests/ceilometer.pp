# Configure the Ceilometer service
#
# [*enable_legacy_telemetry*]
#   (optional) Define if we use the legacy ceilometer database/service instead
#   of Gnocchi and Panko
#   Default to false.
#
# [*compute_namespace*]
#   (optional) Enable polling for the compute namespace
#   Default to true.
#
class openstack_integration::ceilometer (
  $enable_legacy_telemetry = false,
  $compute_namespace       = true,
){

  include ::openstack_integration::config
  include ::openstack_integration::params

  openstack_integration::mq_user { 'ceilometer':
    password => 'an_even_bigger_secret',
    before   => Anchor['ceilometer::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'ceilometer':
      notify  => Service['httpd'],
      require => Package['ceilometer-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { '::ceilometer':
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
    amqp_sasl_mechanisms       => 'PLAIN',
    memcached_servers          => $::openstack_integration::config::memcached_servers,
    debug                      => true,
  }

  class { '::ceilometer::keystone::auth':
    public_url         => "${::openstack_integration::config::base_url}:8777",
    internal_url       => "${::openstack_integration::config::base_url}:8777",
    admin_url          => "${::openstack_integration::config::base_url}:8777",
    password           => 'a_big_secret',
    configure_endpoint => $enable_legacy_telemetry,
  }

  if $enable_legacy_telemetry {
    class { '::ceilometer::db::mysql':
      password => 'ceilometer',
    }
    class { '::ceilometer::db':
      database_connection => 'mysql+pymysql://ceilometer:ceilometer@127.0.0.1/ceilometer?charset=utf8',
    }
    class { '::ceilometer::keystone::authtoken':
      password            => 'a_big_secret',
      user_domain_name    => 'Default',
      project_domain_name => 'Default',
      auth_url            => $::openstack_integration::config::keystone_admin_uri,
      auth_uri            => $::openstack_integration::config::keystone_auth_uri,
      memcached_servers   => $::openstack_integration::config::memcached_servers,
    }
    class { '::ceilometer::api':
      enabled      => true,
      service_name => 'httpd',
    }
    include ::apache
    class { '::ceilometer::wsgi::apache':
      bind_host => $::openstack_integration::config::ip_for_url,
      ssl       => $::openstack_integration::config::ssl,
      ssl_key   => "/etc/keystone/ssl/private/${::fqdn}.pem",
      ssl_cert  => $::openstack_integration::params::cert_path,
      workers   => '2',
    }

    class { '::ceilometer::expirer': }

    # Gnocchi and Panko are not avialable on Ubuntu
    $sample_pipeline_publishers = ['database://']
    $event_pipeline_publishers = ['database://']
  } else {
    # We use Gnocchi/Panko instead of local database
    class { '::ceilometer::db::sync':
      extra_params => '--skip-metering-database',
    }
    # Ensure Gnocchi and creads are ready before running ceilometer-upgrade
    Service['httpd'] -> Exec['ceilometer-upgrade']
    Class['ceilometer::agent::auth'] -> Exec['ceilometer-upgrade']
    Class['ceilometer::keystone::auth'] -> Exec['ceilometer-upgrade']
    Class['gnocchi::keystone::auth'] -> Exec['ceilometer-upgrade']

    # The default pipeline doesn't have Panko
    $sample_pipeline_publishers = ['gnocchi://']
    $event_pipeline_publishers = ['gnocchi://', 'panko://']
  }

  class { '::ceilometer::agent::notification':
    notification_workers      => '2',
    manage_pipeline           => true,
    pipeline_publishers       => $sample_pipeline_publishers,
    manage_event_pipeline     => true,
    event_pipeline_publishers => $event_pipeline_publishers,
  }
  class { '::ceilometer::agent::polling':
    manage_polling    => true,
    compute_namespace => $compute_namespace,
    # NOTE(sileht): Use 1 minute instead 10 otherwise the telemetry tempest
    # tests are too long to pass in less than 1 hour.
    polling_interval  => 60,
  }
  class { '::ceilometer::agent::auth':
    auth_password => 'a_big_secret',
    auth_url      => $::openstack_integration::config::keystone_auth_uri,
  }

}
