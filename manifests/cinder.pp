# Configure the Cinder service
#
# [*backend*]
#   (optional) Cinder backend to use.
#   Can be 'iscsi' or 'rbd'.
#   Defaults to 'iscsi'.
#
# [*volume_encryption*]
#   (optional) Boolean to configure or not volume encryption
#   Defaults to false.
#
# [*cinder_backup*]
#   (optional) Set type of cinder backup
#   Possible values: undef, swift, ceph
#   defaults to undef
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
class openstack_integration::cinder (
  $backend             = 'iscsi',
  $volume_encryption   = false,
  $cinder_backup       = undef,
  $notification_topics = $facts['os_service_default'],
) {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'cinder':
    password => 'an_even_bigger_secret',
    before   => Anchor['cinder::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'cinder':
      notify  => Service['httpd'],
      require => Anchor['cinder::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }
  include cinder::client
  class { 'cinder::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'cinder',
    host     => $::openstack_integration::config::host,
  }
  class { 'cinder::keystone::auth':
    public_url_v3   => "${::openstack_integration::config::base_url}:8776/v3",
    internal_url_v3 => "${::openstack_integration::config::base_url}:8776/v3",
    admin_url_v3    => "${::openstack_integration::config::base_url}:8776/v3",
    roles           => ['admin', 'service'],
    password        => 'a_big_secret',
  }
  class { 'cinder::logging':
    debug => true,
  }
  if $volume_encryption {
    class { 'cinder::key_manager':
      backend => 'castellan.key_manager.barbican_key_manager.BarbicanKeyManager'
    }
    class { 'cinder::key_manager::barbican':
      barbican_endpoint       => "${::openstack_integration::config::base_url}:9311",
      auth_endpoint           => $::openstack_integration::config::keystone_auth_uri,
      send_service_user_token => true,
    }
    class { 'cinder::key_manager::barbican::service_user':
      password            => 'a_big_secret',
      user_domain_name    => 'Default',
      project_domain_name => 'Default',
      auth_url            => $::openstack_integration::config::keystone_admin_uri,
    }
  }
  class { 'cinder::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'cinder',
      'password' => 'cinder',
      'database' => 'cinder',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'cinder':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'cinder',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'cinder',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
  }
  class { 'cinder::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'cinder::keystone::service_user':
    send_service_user_token => true,
    password                => 'a_big_secret',
    user_domain_name        => 'Default',
    project_domain_name     => 'Default',
    auth_url                => $::openstack_integration::config::keystone_admin_uri,
  }
  class { 'cinder::api':
    default_volume_type => 'BACKEND_1',
    public_endpoint     => "${::openstack_integration::config::base_url}:8776",
    service_name        => 'httpd',
  }
  class { 'cinder::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/cinder/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'cinder::quota': }
  class { 'cinder::scheduler': }
  class { 'cinder::scheduler::filter': }
  class { 'cinder::volume':
    volume_clear => 'none',
  }
  class { 'cinder::backup': }
  class { 'cinder::cron::db_purge': }
  class { 'cinder::glance': }
  case $backend {
    'iscsi': {
      class { 'cinder::setup_test_volume':
        size => '15G',
      }
      cinder::backend::iscsi { 'BACKEND_1':
        target_ip_address  => $::openstack_integration::config::host,
        manage_volume_type => true,
      }
      include openstacklib::iscsid
      Service['iscsid'] -> Service['cinder-volume']
    }
    'rbd': {
      cinder::backend::rbd { 'BACKEND_1':
        rbd_user           => 'openstack',
        rbd_pool           => 'cinder',
        rbd_secret_uuid    => '7200aea0-2ddd-4a32-aa2a-d49f66ab554c',
        manage_volume_type => true,
      }
      # make sure ceph pool exists before running Cinder Volume
      Exec['create-cinder'] -> Service['cinder-volume']
    }
    default: {
      fail("Unsupported backend (${backend})")
    }
  }
  class { 'cinder::backends':
    enabled_backends => ['BACKEND_1'],
  }

  case $cinder_backup {
    'swift': {
      class { 'cinder::backup::swift': }
    }
    'ceph': {
      class { 'cinder::backup::ceph':
        backup_ceph_user => 'openstack',
      }
      # make sure ceph pool exists before running Cinder Backup
      Exec['create-backups'] -> Service['cinder-backup']
    }
    default: {}
  }
}
