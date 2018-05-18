# Configure the Gnocchi service
#
# [*integration_enable*]
#   (optional) Boolean to run integration tests.
#   Defaults to true.
#
class openstack_integration::gnocchi (
  $integration_enable = true,
){

  include ::openstack_integration::config
  include ::openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'gnocchi':
      notify  => Service['httpd'],
      require => Package['gnocchi'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { '::gnocchi':
    debug               => true,
    database_connection => 'mysql+pymysql://gnocchi:gnocchi@127.0.0.1/gnocchi?charset=utf8',
  }
  class { '::gnocchi::db::mysql':
    password => 'gnocchi',
  }
  class { '::gnocchi::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8041",
    internal_url => "${::openstack_integration::config::base_url}:8041",
    admin_url    => "${::openstack_integration::config::base_url}:8041",
    password     => 'a_big_secret',
  }
  class { '::gnocchi::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { '::gnocchi::api':
    enabled      => true,
    service_name => 'httpd',
    sync_db      => true,
  }
  include ::apache
  class { '::gnocchi::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/gnocchi/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { '::gnocchi::client': }
  class { '::gnocchi::metricd':
    workers       => 2,
    # because we configure Keystone to expire tokens after 600s, we don't
    # want to rely on default value in Gnocchi which is 300s to cleanup old data.
    # Indeed, Gnocchi might use an old token that expired to clean up and then it would
    # fail. It happens when running Tempest tests in the gate with low resources.
    # Production value (300) shouldn't be changed by default.
    cleanup_delay => 10,
  }
  class { '::gnocchi::storage':
    # NOTE(sileht): Since we set the pipeline interval to 1 minutes instead
    # of 10, we must compute metrics more often too, otherwise Aodh alarms will
    # always missed data just because they are 'not yet' computed.
    metric_processing_delay => 5,
    coordination_url        => $::openstack_integration::config::tooz_url,
  }
  if $integration_enable {
    class { '::gnocchi::storage::ceph':
      ceph_username => 'openstack',
      ceph_keyring  => '/etc/ceph/ceph.client.openstack.keyring',
      manage_cradox => ($::osfamily == 'RedHat'),
      manage_rados  => ($::osfamily == 'Debian'),
    }
    # make sure ceph pool exists before running gnocchi (dbsync & services)
    Exec['create-gnocchi'] -> Exec['gnocchi-db-sync']
  } else {
    class { '::gnocchi::storage::file': }
  }
  class { '::gnocchi::statsd':
    archive_policy_name => 'high',
    flush_delay         => '100',
    # random datas:
    resource_id         => '07f26121-5777-48ba-8a0b-d70468133dd9',
  }

}
