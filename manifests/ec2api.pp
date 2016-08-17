# Configure the ec2api service
#
class openstack_integration::ec2api {

  include ::openstack_integration::config
  include ::openstack_integration::params

  # Ec2api resources
  class { '::ec2api::logging':
    debug => true,
  }
  class { '::ec2api::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8788",
    internal_url => "${::openstack_integration::config::base_url}:8788",
    admin_url    => "${::openstack_integration::config::base_url}:8788",
    password     => 'a_big_secret',
  }
  class { '::ec2api::db::mysql':
    password => 'ec2api',
  }
  class { '::ec2api::db::sync': }
  case $::osfamily {
    'RedHat': {
      class { '::ec2api::db':
        database_connection => 'mysql+pymysql://ec2api:ec2api@127.0.0.1/ec2api?charset=utf8',
      }
      class { '::ec2api': }
      class { '::ec2api::keystone::authtoken':
        password => 'a_big_secret',
        auth_url => $::openstack_integration::config::keystone_admin_uri,
        auth_uri => $::openstack_integration::config::keystone_auth_uri,
      }
      class { '::ec2api::api':
        keystone_ec2_tokens_url => "${::openstack_integration::config::keystone_auth_uri}/v3/ec2tokens",
        external_network        => 'public',
      }
      include ::ec2api::metadata
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }
}
