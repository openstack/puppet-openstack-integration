class openstack_integration::sahara {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'sahara':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'sahara@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::sahara::db::mysql':
    password => 'sahara',
  }
  class { '::sahara::keystone::auth':
    # SSL does not seem to work in Sahara
    # https://bugs.launchpad.net/sahara/+bug/1565082
    public_url   => "http://${::openstack_integration::config::ip_for_url}:8386/v1.1/%(tenant_id)s",
    internal_url => "http://${::openstack_integration::config::ip_for_url}:8386/v1.1/%(tenant_id)s",
    admin_url    => "http://${::openstack_integration::config::ip_for_url}:8386/v1.1/%(tenant_id)s",
    password     => 'a_big_secret',
  }
  class { '::sahara':
    host                => $::openstack_integration::config::host,
    database_connection => 'mysql+pymysql://sahara:sahara@127.0.0.1/sahara?charset=utf8',
    rabbit_userid       => 'sahara',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => $::openstack_integration::config::ip_for_url,
    rabbit_port         => $::openstack_integration::config::rabbit_port,
    rabbit_use_ssl      => $::openstack_integration::config::ssl,
    rpc_backend         => 'rabbit',
    admin_password      => 'a_big_secret',
    admin_user          => 'sahara',
    admin_tenant_name   => 'services',
    debug               => true,
    auth_uri            => "${::openstack_integration::config::keystone_admin_uri}/v2.0",
    identity_uri        => $::openstack_integration::config::keystone_admin_uri,
  }
  class { '::sahara::service::api':
    api_workers => 2,
  }
  class { '::sahara::service::engine': }
  class { '::sahara::client': }
  class { '::sahara::notify':
    enable_notifications => true,
  }

}
