class openstack_integration::neutron {

  rabbitmq_user { 'neutron':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'neutron@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::neutron::db::mysql':
    password => 'neutron',
  }
  class { '::neutron::keystone::auth':
    password => 'a_big_secret',
  }
  class { '::neutron':
    rabbit_user           => 'neutron',
    rabbit_password       => 'an_even_bigger_secret',
    rabbit_host           => '127.0.0.1',
    allow_overlapping_ips => true,
    core_plugin           => 'ml2',
    service_plugins       => ['router', 'metering'],
    debug                 => true,
    verbose               => true,
  }
  class { '::neutron::client': }
  class { '::neutron::server':
    database_connection => 'mysql+pymysql://neutron:neutron@127.0.0.1/neutron?charset=utf8',
    auth_password       => 'a_big_secret',
    identity_uri        => 'http://127.0.0.1:35357/',
    sync_db             => true,
    api_workers         => 4,
  }
  class { '::neutron::plugins::ml2':
    type_drivers         => ['vxlan'],
    tenant_network_types => ['vxlan'],
    mechanism_drivers    => ['openvswitch'],
  }
  class { '::neutron::agents::ml2::ovs':
    enable_tunneling => true,
    local_ip         => '127.0.0.1',
    tunnel_types     => ['vxlan'],
  }
  class { '::neutron::agents::metadata':
    debug            => true,
    auth_password    => 'a_big_secret',
    shared_secret    => 'a_big_secret',
    metadata_workers => 2,
  }
  class { '::neutron::agents::lbaas':
    debug => true,
  }
  class { '::neutron::agents::l3':
    debug => true,
  }
  class { '::neutron::agents::dhcp':
    debug => true,
  }
  class { '::neutron::agents::metering':
    debug => true,
  }
  class { '::neutron::server::notifications':
    password => 'a_big_secret',
  }
  include ::vswitch::ovs

}
