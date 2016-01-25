class openstack_integration::gnocchi {

  # gnocchi is not packaged in Ubuntu Cloud Archive
  # https://bugs.launchpad.net/cloud-archive/+bug/1535740
  if $::osfamily == 'RedHat' {
    class { '::gnocchi':
      verbose             => true,
      debug               => true,
      database_connection => 'mysql+pymysql://gnocchi:gnocchi@127.0.0.1/gnocchi?charset=utf8',
    }
    class { '::gnocchi::db::mysql':
      password => 'gnocchi',
    }
    class { '::gnocchi::keystone::auth':
      password => 'a_big_secret',
    }
    class { '::gnocchi::api':
      enabled               => true,
      keystone_password     => 'a_big_secret',
      keystone_identity_uri => 'http://127.0.0.1:35357/',
      keystone_auth_uri     => 'http://127.0.0.1:35357/',
      service_name          => 'httpd',
    }
    include ::apache
    class { '::gnocchi::wsgi::apache':
      ssl => false,
    }
    class { '::gnocchi::client': }
    class { '::gnocchi::db::sync': }
    class { '::gnocchi::metricd': }
    class { '::gnocchi::storage': }
    class { '::gnocchi::storage::file': }
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
