# Configure the Gnocchi service
#
# [*backend*]
#   (optional) Backend storage to be used.
#   Defaults to 'file'.
#
class openstack_integration::gnocchi (
  $backend = 'file',
){

  include openstack_integration::config
  include openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'gnocchi':
      notify  => Service['httpd'],
      require => Package['gnocchi'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { 'gnocchi::logging':
    debug => true,
  }
  class { 'gnocchi::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'gnocchi',
      'password' => 'gnocchi',
      'database' => 'gnocchi',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'gnocchi':
    coordination_url => $::openstack_integration::config::tooz_url,
  }
  Class['redis::service'] -> Anchor['gnocchi::service::begin']
  class { 'gnocchi::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'gnocchi',
    host     => $::openstack_integration::config::host,
  }

  # TODO(tkajinam): We need to find a way to enforce swift is up before
  #                 starting all services. Currently it results in dependency
  #                 cycle, caused by multiple usage of httpd. In the mean time
  #                 skip initializing storage for swift, because the current
  #                 implementation only validates connection to swift.
  $db_sync_extra_opts = $backend ? {
    'swift' => '--skip-storage',
    default => undef,
  }
  class { 'gnocchi::db::sync':
    extra_opts => $db_sync_extra_opts,
  }

  class { 'gnocchi::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8041",
    internal_url => "${::openstack_integration::config::base_url}:8041",
    admin_url    => "${::openstack_integration::config::base_url}:8041",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'gnocchi::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'gnocchi::api':
    enabled      => true,
    service_name => 'httpd',
  }
  class { 'gnocchi::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/gnocchi/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'gnocchi::client': }
  class { 'gnocchi::metricd':
    workers                 => 2,
    # because we configure Keystone to expire tokens after 600s, we don't
    # want to rely on default value in Gnocchi which is 300s to cleanup old data.
    # Indeed, Gnocchi might use an old token that expired to clean up and then it would
    # fail. It happens when running Tempest tests in the gate with low resources.
    # Production value (300) shouldn't be changed by default.
    metric_cleanup_delay    => 10,
    # NOTE(sileht): Since we set the pipeline interval to 1 minutes instead
    # of 10, we must compute metrics more often too, otherwise Aodh alarms will
    # always missed data just because they are 'not yet' computed.
    metric_processing_delay => 5,
  }
  class { 'gnocchi::storage': }

  case $backend {
    'ceph': {
      class { 'gnocchi::storage::ceph':
        ceph_username => 'openstack',
        ceph_keyring  => '/etc/ceph/ceph.client.openstack.keyring',
        manage_rados  => true,
      }
      # make sure ceph pool exists before running gnocchi (dbsync & services)
      Ceph::Pool['gnocchi'] -> Anchor['gnocchi::dbsync::begin']
    }
    'swift': {
      class { 'gnocchi::storage::swift':
        swift_auth_version => '3',
        swift_authurl      => $::openstack_integration::config::keystone_admin_uri,
        swift_user         => 'services:gnocchi',
        swift_key          => 'a_big_secret',
      }
      class { 'gnocchi::storage::incoming::redis':
        redis_url => $::openstack_integration::config::tooz_url,
      }
    }
    'file': {
      class { 'gnocchi::storage::file': }
    }
    default: {
      fail("Unsupported backend (${backend})")
    }
  }
  class { 'gnocchi::statsd':
    host                => $::openstack_integration::config::host,
    archive_policy_name => 'high',
    flush_delay         => '100',
    # random datas:
    resource_id         => '07f26121-5777-48ba-8a0b-d70468133dd9',
  }

}
