# Configure the ec2api service
#
class openstack_integration::ec2api {

  include openstack_integration::config
  include openstack_integration::params

  class { 'ec2api::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8788",
    internal_url => "${::openstack_integration::config::base_url}:8788",
    admin_url    => "${::openstack_integration::config::base_url}:8788",
    password     => 'a_big_secret',
  }
  class { 'ec2api::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'ec2api',
    host     => $::openstack_integration::config::host,
  }
  case $::osfamily {
    'RedHat': {
      class { 'ec2api::db':
        database_connection => os_database_connection({
          'dialect'  => 'mysql+pymysql',
          'host'     => $::openstack_integration::config::ip_for_url,
          'username' => 'ec2api',
          'password' => 'ec2api',
          'database' => 'ec2api',
          'charset'  => 'utf8',
        }),
      }
      class { 'ec2api::db::sync': }
      class { 'ec2api::logging':
        debug => true,
      }
      class { 'ec2api': }
      class { 'ec2api::keystone::authtoken':
        password             => 'a_big_secret',
        user_domain_name     => 'Default',
        project_domain_name  => 'Default',
        auth_url             => $::openstack_integration::config::keystone_admin_uri,
        www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
        memcached_servers    => $::openstack_integration::config::memcached_servers,
      }
      class { 'ec2api::api':
        keystone_ec2_tokens_url => "${::openstack_integration::config::keystone_auth_uri}/v3/ec2tokens",
        external_network        => 'public',
      }
      include ec2api::metadata
    }
    'Debian': {
      warning('ec2api is not yet packaged on Ubuntu systems.')
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }
}
