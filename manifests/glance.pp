# Configure the Glance service
#
# [*backend*]
#   (optional) Glance backend to use.
#   Can be 'file', 'swift', 'rbd' or 'cinder'.
#   Defaults to 'file'.
#
# [*image_encryption*]
#   (optional) Boolean to configure or not image encryption
#   Defaults to false.
#
class openstack_integration::glance (
  $backend          = 'file',
  $image_encryption = false,
) {

  include openstack_integration::config
  include openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'glance':
    }
    $key_file = undef
    $crt_file  = undef
  } else {
    $key_file = undef
    $crt_file  = undef
  }

  openstack_integration::mq_user { 'glance':
    password => 'an_even_bigger_secret',
    before   => Anchor['glance::service::begin'],
  }

  class { 'glance::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'glance',
  }
  include glance
  include glance::client
  class { 'glance::keystone::auth':
    public_url   => "http://${::openstack_integration::config::ip_for_url}:9292",
    internal_url => "http://${::openstack_integration::config::ip_for_url}:9292",
    admin_url    => "http://${::openstack_integration::config::ip_for_url}:9292",
    password     => 'a_big_secret',
  }
  class { 'glance::api::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  case $backend {
    'file': {
      glance::backend::multistore::file { 'file1': }
      $default_backend = 'file1'
    }
    'rbd': {
      glance::backend::multistore::rbd { 'rbd1':
        rbd_store_user => 'openstack',
        rbd_store_pool => 'glance',
      }
      # make sure ceph pool exists before running Glance API
      Exec['create-glance'] -> Service['glance-api']
      $default_backend = 'rbd1'
    }
    'swift': {
      glance::backend::multistore::swift { 'swift1':
        swift_store_user                    => 'services:glance',
        swift_store_key                     => 'a_big_secret',
        swift_store_create_container_on_put => 'True',
        swift_store_auth_address            => "${::openstack_integration::config::keystone_auth_uri}/v3",
        swift_store_auth_version            => '3',
      }
      $default_backend = 'swift1'
    }
    'cinder': {
      glance::backend::multistore::cinder { 'cinder1':
        cinder_store_auth_address => "${::openstack_integration::config::keystone_auth_uri}/v3",
        cinder_store_project_name => 'services',
        cinder_store_user_name    => 'glance',
        cinder_store_password     => 'a_big_secret',
      }
      $default_backend = 'cinder1'
    }
    default: {
      fail("Unsupported backend (${backend})")
    }
  }

  $enabled_backends = ["${default_backend}:${backend}"]

  class { 'glance::api::logging':
    debug => true,
  }
  class { 'glance::api::db':
    database_connection => 'mysql+pymysql://glance:glance@127.0.0.1/glance?charset=utf8',
  }
  class { 'glance::api':
    workers          => 2,
    enabled_backends => $enabled_backends,
    default_backend  => $default_backend,
    bind_host        => $::openstack_integration::config::host,
    cert_file        => $crt_file,
    key_file         => $key_file,
  }
  class { 'glance::cron::db_purge': }
  class { 'glance::notify::rabbitmq':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'glance',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'glance',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_driver        => 'messagingv2',
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
  }

  if $image_encryption {
    class { 'glance::key_manager':
      backend => 'castellan.key_manager.barbican_key_manager.BarbicanKeyManager'
    }
    class { 'glance::key_manager::barbican':
      barbican_endpoint => "${::openstack_integration::config::base_url}:9311",
      auth_endpoint     => "${::openstack_integration::config::keystone_auth_uri}/v3"
    }
  }
}
