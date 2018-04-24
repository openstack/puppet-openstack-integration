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
#   Possible values: false, swift
#   defaults to false.
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $::os_service_default.
#
class openstack_integration::cinder (
  $backend             = 'iscsi',
  $volume_encryption   = false,
  $cinder_backup       = false,
  $notification_topics = $::os_service_default,
) {

  include ::openstack_integration::config
  include ::openstack_integration::params

  openstack_integration::mq_user { 'cinder':
    password => 'an_even_bigger_secret',
    before   => Anchor['cinder::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'cinder':
      notify  => Service['httpd'],
      require => Package['cinder'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }
  include ::cinder::client
  class { '::cinder::db::mysql':
    password => 'cinder',
  }
  class { '::cinder::keystone::auth':
    public_url      => "${::openstack_integration::config::base_url}:8776/v1/%(tenant_id)s",
    internal_url    => "${::openstack_integration::config::base_url}:8776/v1/%(tenant_id)s",
    admin_url       => "${::openstack_integration::config::base_url}:8776/v1/%(tenant_id)s",
    public_url_v2   => "${::openstack_integration::config::base_url}:8776/v2/%(tenant_id)s",
    internal_url_v2 => "${::openstack_integration::config::base_url}:8776/v2/%(tenant_id)s",
    admin_url_v2    => "${::openstack_integration::config::base_url}:8776/v2/%(tenant_id)s",
    public_url_v3   => "${::openstack_integration::config::base_url}:8776/v3/%(tenant_id)s",
    internal_url_v3 => "${::openstack_integration::config::base_url}:8776/v3/%(tenant_id)s",
    admin_url_v3    => "${::openstack_integration::config::base_url}:8776/v3/%(tenant_id)s",
    password        => 'a_big_secret',
  }
  class { '::cinder':
    default_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'cinder',
      'password'  => 'an_even_bigger_secret',
    }),
    database_connection   => 'mysql+pymysql://cinder:cinder@127.0.0.1/cinder?charset=utf8',
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms  => 'PLAIN',
    debug                 => true,
  }
  class { '::cinder::ceilometer':
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'cinder',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
  }
  if $volume_encryption {
    $keymgr_backend             = 'castellan.key_manager.barbican_key_manager.BarbicanKeyManager'
    $keymgr_encryption_api_url  = "${::openstack_integration::config::base_url}:9311"
    $keymgr_encryption_auth_url = "${::openstack_integration::config::keystone_auth_uri}/v3"
  } else {
    # (TODO) amoralej - we need to define api_class until fix https://review.openstack.org/#/c/468252 in
    # cinder is merged to unblock puppet promotion
    $keymgr_backend             = 'cinder.keymgr.conf_key_mgr.ConfKeyManager'
    $keymgr_encryption_api_url  = undef
    $keymgr_encryption_auth_url = undef
  }
  class { '::cinder::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { '::cinder::api':
    default_volume_type        => 'BACKEND_1',
    public_endpoint            => "${::openstack_integration::config::base_url}:8776",
    service_name               => 'httpd',
    keymgr_backend             => $keymgr_backend,
    keymgr_encryption_api_url  => $keymgr_encryption_api_url,
    keymgr_encryption_auth_url => $keymgr_encryption_auth_url,
  }
  include ::apache
  class { '::cinder::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/cinder/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { '::cinder::quota': }
  class { '::cinder::scheduler': }
  class { '::cinder::scheduler::filter': }
  class { '::cinder::volume':
    volume_clear => 'none',
  }
  class { '::cinder::backup': }
  class { '::cinder::cron::db_purge': }
  class { '::cinder::glance':
    glance_api_servers => "${::openstack_integration::config::base_url}:9292",
  }
  case $backend {
    'iscsi': {
      class { '::cinder::setup_test_volume':
        size => '15G',
      }
      cinder::backend::iscsi { 'BACKEND_1':
        iscsi_ip_address   => '127.0.0.1',
        manage_volume_type => true,
      }
    }
    'rbd': {
      cinder::backend::rbd { 'BACKEND_1':
        rbd_user           => 'openstack',
        rbd_pool           => 'cinder',
        rbd_secret_uuid    => '7200aea0-2ddd-4a32-aa2a-d49f66ab554c',
        manage_volume_type => true,
      }
      # make sure ceph pool exists before running Cinder API & Volume
      Exec['create-cinder'] -> Service['httpd']
      Exec['create-cinder'] -> Service['cinder-volume']
    }
    default: {
      fail("Unsupported backend (${backend})")
    }
  }
  class { '::cinder::backends':
    enabled_backends => ['BACKEND_1'],
  }

  if $cinder_backup == swift {
    class { '::cinder::backup::swift':
      backup_swift_user_domain    => 'Default',
      backup_swift_project_domain => 'Default',
      backup_swift_project        => 'Default',
    }
  }

}
