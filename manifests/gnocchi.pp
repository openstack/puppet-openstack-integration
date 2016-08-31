class openstack_integration::gnocchi {

  include ::openstack_integration::config
  include ::openstack_integration::params

  # gnocchi is not packaged in Ubuntu Cloud Archive
  # https://bugs.launchpad.net/cloud-archive/+bug/1535740
  if $::osfamily == 'RedHat' {

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
      password            => 'a_big_secret',
      user_domain_name    => 'Default',
      project_domain_name => 'Default',
      auth_url            => $::openstack_integration::config::keystone_admin_uri,
      auth_uri            => $::openstack_integration::config::keystone_auth_uri,
      memcached_servers   => $::openstack_integration::config::memcached_servers,
    }
    class { '::gnocchi::api':
      enabled      => true,
      service_name => 'httpd',
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
    class { '::gnocchi::db::sync': }
    class { '::gnocchi::metricd': }
    class { '::gnocchi::storage': }
    class { '::gnocchi::storage::ceph':
      ceph_username => 'openstack',
      ceph_keyring  => '/etc/ceph/ceph.client.openstack.keyring',
    }
    # make sure ceph pool exists before running gnocchi (dbsync & services)
    Exec['create-gnocchi'] -> Exec['gnocchi-db-sync']
    class { '::gnocchi::statsd':
      archive_policy_name => 'high',
      flush_delay         => '100',
      # random datas:
      resource_id         => '07f26121-5777-48ba-8a0b-d70468133dd9',
      user_id             => 'f81e9b1f-9505-4298-bc33-43dfbd9a973b',
      project_id          => '203ef419-e73f-4b8a-a73f-3d599a72b18d',
    }
  }

}
