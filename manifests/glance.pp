# Configure the Glance service
#
# [*backend*]
#   (optional) Glance backend to use.
#   Can be 'file', 'swift' or 'rbd'.
#   Defaults to 'file'.
#
class openstack_integration::glance (
  $backend = 'file',
) {

  include openstack_integration::config
  include openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'glance':
      notify => Service['glance-api'],
    }
    Package<| tag == 'glance-package' |> -> File['/etc/glance/ssl']
    $key_file  = "/etc/glance/ssl/private/${::fqdn}.pem"
    $crt_file = $::openstack_integration::params::cert_path
    Exec['update-ca-certificates'] ~> Service['glance-api']
  } else {
    $key_file = undef
    $crt_file  = undef
  }

  openstack_integration::mq_user { 'glance':
    password => 'an_even_bigger_secret',
    before   => Anchor['glance::service::begin'],
  }

  class { 'glance::db::mysql':
    password => 'glance',
  }
  include glance
  include glance::client
  class { 'glance::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9292",
    internal_url => "${::openstack_integration::config::base_url}:9292",
    admin_url    => "${::openstack_integration::config::base_url}:9292",
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
    default: {
      fail("Unsupported backend (${backend})")
    }
  }

  $enabled_backends = ["${default_backend}:${backend}"]

  class { 'glance::api::logging':
    debug => true,
  }
  class { 'glance::api':
    database_connection => 'mysql+pymysql://glance:glance@127.0.0.1/glance?charset=utf8',
    workers             => 2,
    enabled_backends    => $enabled_backends,
    default_backend     => $default_backend,
    bind_host           => $::openstack_integration::config::host,
    cert_file           => $crt_file,
    key_file            => $key_file,
  }
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

}
