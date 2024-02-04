# Configure the ec2api service
#
class openstack_integration::ec2api {

  include openstack_integration::config
  include openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'ec2api':
      notify  => Anchor['ec2api::service::begin'],
      require => Anchor['ec2api::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service<| tag == 'ec2api-service' |>
  }

  class { 'ec2api::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8788",
    internal_url => "${::openstack_integration::config::base_url}:8788",
    admin_url    => "${::openstack_integration::config::base_url}:8788",
    password     => 'a_big_secret',
    roles        => ['admin', 'service'],
  }
  class { 'ec2api::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'ec2api',
    host     => $::openstack_integration::config::host,
  }

  case $facts['os']['family'] {
    'RedHat': {
      class { 'ec2api::cache':
        backend          => 'dogpile.cache.pymemcache',
        enabled          => true,
        memcache_servers => $::openstack_integration::config::memcache_servers,
      }
      class { 'ec2api::db':
        database_connection => os_database_connection({
          'dialect'  => 'mysql+pymysql',
          'host'     => $::openstack_integration::config::ip_for_url,
          'username' => 'ec2api',
          'password' => 'ec2api',
          'database' => 'ec2api',
          'charset'  => 'utf8',
          'extra'    => $::openstack_integration::config::db_extra,
        }),
      }
      class { 'ec2api::db::sync': }
      class { 'ec2api::logging':
        debug => true,
      }
      class { 'ec2api': }
      class { 'ec2api::keystone::authtoken':
        password                     => 'a_big_secret',
        user_domain_name             => 'Default',
        project_domain_name          => 'Default',
        auth_url                     => $::openstack_integration::config::keystone_admin_uri,
        www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
        memcached_servers            => $::openstack_integration::config::memcached_servers,
        service_token_roles_required => true,
      }
      class { 'ec2api::api':
        my_ip                   => $::openstack_integration::config::host,
        ec2_host                => $::openstack_integration::config::host,
        ec2api_listen           => $::openstack_integration::config::host,
        keystone_ec2_tokens_url => "${::openstack_integration::config::keystone_auth_uri}/v3/ec2tokens",
        external_network        => 'public',
        ec2api_use_ssl          => $::openstack_integration::config::ssl,
        ssl_cert_file           => $::openstack_integration::params::cert_path,
        ssl_key_file            => "/etc/ec2api/ssl/private/${facts['networking']['fqdn']}.pem",
        ec2api_workers          => 2,
      }
      class { 'ec2api::metadata':
        nova_metadata_ip => $::openstack_integration::config::host,
        metadata_listen  => $::openstack_integration::config::host,
        metadata_use_ssl => $::openstack_integration::config::ssl,
        metadata_workers => 2,
      }
    }
    'Debian': {
      warning('ec2api is not yet packaged on Ubuntu systems.')
    }
    default: {
      fail("Unsupported osfamily (${facts['os']['family']})")
    }
  }
}
