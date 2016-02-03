# Configure the Cinder service
#
# [*backend*]
#   (optional) Cinder backend to use.
#   Can be 'iscsi' or 'rbd'.
#   Defaults to 'iscsi'.
#
class openstack_integration::cinder (
  $backend = 'iscsi',
) {

  include ::openstack_integration::config

  rabbitmq_user { 'cinder':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'cinder@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::cinder::db::mysql':
    password => 'cinder',
  }
  class { '::cinder::keystone::auth':
    password => 'a_big_secret',
  }
  class { '::cinder':
    database_connection => 'mysql+pymysql://cinder:cinder@127.0.0.1/cinder?charset=utf8',
    rabbit_host         => $::openstack_integration::config::rabbit_host,
    rabbit_port         => $::openstack_integration::config::rabbit_port,
    rabbit_userid       => 'cinder',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_use_ssl      => $::openstack_integration::config::ssl,
    verbose             => true,
    debug               => true,
  }
  class { '::cinder::api':
    keystone_password   => 'a_big_secret',
    identity_uri        => 'http://127.0.0.1:35357/',
    default_volume_type => 'BACKEND_1',
    service_workers     => 2,
  }
  class { '::cinder::quota': }
  class { '::cinder::scheduler': }
  class { '::cinder::scheduler::filter': }
  class { '::cinder::volume':
    volume_clear => 'none',
  }
  class { '::cinder::cron::db_purge': }
  class { '::cinder::glance':
    glance_api_servers  => 'localhost:9292',
  }
  case $backend {
    'iscsi': {
      class { '::cinder::setup_test_volume':
        size => '15G',
      }
      cinder::backend::iscsi { 'BACKEND_1':
        iscsi_ip_address => '127.0.0.1',
      }
    }
    'rbd': {
      cinder::backend::rbd { 'BACKEND_1':
        rbd_user        => 'openstack',
        rbd_pool        => 'cinder',
        rbd_secret_uuid => '7200aea0-2ddd-4a32-aa2a-d49f66ab554c',
      }
      # make sure ceph pool exists before running Cinder API & Volume
      Exec['create-cinder'] -> Service['cinder-api']
      Exec['create-cinder'] -> Service['cinder-volume']
    }
    default: {
      fail("Unsupported backend (${backend})")
    }
  }
  class { '::cinder::backends':
    enabled_backends => ['BACKEND_1'],
  }
  cinder_type { 'BACKEND_1':
    ensure     => present,
    properties => ['volume_backend_name=BACKEND_1'],
  }

}
