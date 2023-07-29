# Configure the Manila service
#
# [*backend*]
#   (optional) Manila backend to use.
#   Can be 'lvm'.
#   Defaults to 'lvm'.
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
class openstack_integration::manila (
  $backend             = 'lvm',
  $notification_topics = $facts['os_service_default'],
) {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'manila':
    password => 'an_even_bigger_secret',
    before   => Anchor['manila::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'manila':
      notify  => Service['httpd'],
      require => Package['manila'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }
  include manila::client
  class { 'manila::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'manila',
    host     => $::openstack_integration::config::host,
  }
  class { 'manila::keystone::auth':
    public_url             => "${::openstack_integration::config::base_url}:8786/v1/%(tenant_id)s",
    internal_url           => "${::openstack_integration::config::base_url}:8786/v1/%(tenant_id)s",
    admin_url              => "${::openstack_integration::config::base_url}:8786/v1/%(tenant_id)s",
    public_url_v2          => "${::openstack_integration::config::base_url}:8786/v2",
    internal_url_v2        => "${::openstack_integration::config::base_url}:8786/v2",
    admin_url_v2           => "${::openstack_integration::config::base_url}:8786/v2",
    password               => 'a_big_secret',
    configure_user_v2      => false,
    configure_user_role_v2 => false,
  }
  class { 'manila::logging':
    debug => true,
  }
  class { 'manila::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'manila',
      'password' => 'manila',
      'database' => 'manila',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'manila':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'manila',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'manila',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms       => 'PLAIN',
  }
  class { 'manila::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }

  $share_protocol = $backend ? {
    'cephfsnative' => 'CEPHFS',
    default        => 'NFS'
  }

  class { 'manila::api':
    service_name            => 'httpd',
    enabled_share_protocols => $share_protocol,
  }
  include apache
  class { 'manila::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/manila/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'manila::quota': }
  class { 'manila::scheduler': }
  class { 'manila::share': }
  class { 'manila::backends':
    enabled_share_backends => [$backend],
  }
  case $backend {
    'lvm': {
      class { 'manila::setup_test_volume':
        size            => '15G',
        # NOTE(tkajinam): /dev/loop2 is used by cinder.
        loopback_device => '/dev/loop3',
      }
      manila::backend::lvm { 'lvm':
        lvm_share_export_ips => $::openstack_integration::config::host,
      }
    }
    'cephfsnative': {
      manila::backend::cephfs { 'cephfsnative':
        cephfs_conf_path => '/etc/ceph/ceph.conf',
      }
      Exec<| tag == 'create-cephfs' |> -> Anchor['manila::service::begin']
    }
    default: {
      fail("Unsupported backend (${backend})")
    }
  }
  class { 'manila::data': }

  class { 'manila::compute::nova': }
  class { 'manila::network::neutron': }
  class { 'manila::volume::cinder': }
  class { 'manila::cron::db_purge': }
}
