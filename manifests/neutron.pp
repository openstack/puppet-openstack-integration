# Configure the Neutron service
#
# [*driver*]
#   (optional) Neutron Driver to test
#   Can be: openvswitch or linuxbridge.
#   Defaults to 'openvswitch'.
#
class openstack_integration::neutron (
  $driver = 'openvswitch',
) {

  include ::openstack_integration::config
  include ::openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'neutron':
      notify  => Service['neutron-server'],
      require => Package['neutron'],
    }
    Exec['update-ca-certificates'] ~> Service['neutron-server']
  }

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
  Rabbitmq_user_permissions['neutron@/'] -> Service<| tag == 'neutron-service' |>

  case $driver {
    'openvswitch': {
      include ::vswitch::ovs
      # Functional test for Open-vSwitch:
      # create dummy loopback interface to exercise adding a port to a bridge
      vs_bridge { 'br-ex':
        ensure => present,
        notify => Exec['create_loop1_port'],
      }
      exec { 'create_loop1_port':
        path        => '/usr/bin:/bin:/usr/sbin:/sbin',
        provider    => shell,
        command     => 'ip link add name loop1 type dummy && ip addr add 127.2.0.1/24 dev loop1',
        refreshonly => true,
      } ->
      vs_port { 'loop1':
        ensure => present,
        bridge => 'br-ex',
        notify => Exec['create_br-ex_vif'],
      }
      # creates br-ex virtual interface to reach floating-ip network
      exec { 'create_br-ex_vif':
        path        => '/usr/bin:/bin:/usr/sbin:/sbin',
        provider    => shell,
        command     => 'ip addr add 172.24.5.1/24 dev br-ex && ip link set br-ex up',
        refreshonly => true,
      }
      class { '::neutron::agents::ml2::ovs':
        local_ip        => '127.0.0.1',
        tunnel_types    => ['vxlan'],
        bridge_mappings => ['external:br-ex'],
        manage_vswitch  => false,
      }
      $firewall_driver  = 'iptables_hybrid'
    }
    'linuxbridge': {
      exec { 'create_dummy_iface':
        path     => '/usr/bin:/bin:/usr/sbin:/sbin',
        provider => shell,
        unless   => 'ip l show loop0',
        command  => 'ip link add name loop0 type dummy && ip addr add 172.24.5.1/24 dev loop0 && ip link set loop0 up',
      }
      class { '::neutron::agents::ml2::linuxbridge':
        local_ip                    => $::ipaddress,
        tunnel_types                => ['vxlan'],
        physical_interface_mappings => ['external:loop0'],
      }
      $firewall_driver         = 'iptables'
    }
    default: {
      fail("Unsupported neutron driver (${driver})")
    }
  }

  class { '::neutron::db::mysql':
    password => 'neutron',
  }
  class { '::neutron::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9696",
    internal_url => "${::openstack_integration::config::base_url}:9696",
    admin_url    => "${::openstack_integration::config::base_url}:9696",
    password     => 'a_big_secret',
  }
  class { '::neutron':
    default_transport_url => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'neutron',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    allow_overlapping_ips => true,
    core_plugin           => 'ml2',
    service_plugins       => ['router', 'metering', 'firewall', 'lbaasv2'],
    debug                 => true,
    bind_host             => $::openstack_integration::config::host,
    use_ssl               => $::openstack_integration::config::ssl,
    cert_file             => $::openstack_integration::params::cert_path,
    key_file              => "/etc/neutron/ssl/private/${::fqdn}.pem",
  }
  class { '::neutron::client': }
  class { '::neutron::keystone::authtoken':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }
  class { '::neutron::server':
    database_connection => 'mysql+pymysql://neutron:neutron@127.0.0.1/neutron?charset=utf8',
    sync_db             => true,
    api_workers         => 2,
    rpc_workers         => 2,
    service_providers   => ['LOADBALANCER:Haproxy:neutron_lbaas.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default',
                            'LOADBALANCERV2:Haproxy:neutron_lbaas.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default',
                            'FIREWALL:Iptables:neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver:default'],
  }
  class { '::neutron::services::lbaas': }
  class { '::neutron::plugins::ml2':
    type_drivers         => ['vxlan', 'vlan', 'flat'],
    tenant_network_types => ['vxlan', 'vlan', 'flat'],
    extension_drivers    => 'port_security',
    mechanism_drivers    => $driver,
    firewall_driver      => $firewall_driver,
  }
  if $::openstack_integration::config::ssl {
    $metadata_protocol    = 'https'
    $nova_client_cert     = $::openstack_integration::params::cert_path
    $nova_client_priv_key = "/etc/neutron/ssl/private/${::fqdn}.pem"
  } else {
    $metadata_protocol    = $::os_service_default
    $nova_client_cert     = $::os_service_default
    $nova_client_priv_key = $::os_service_default
  }
  class { '::neutron::agents::metadata':
    debug                => true,
    shared_secret        => 'a_big_secret',
    metadata_workers     => 2,
    metadata_protocol    => $metadata_protocol,
    metadata_insecure    => true,
    nova_client_cert     => $nova_client_cert,
    nova_client_priv_key => $nova_client_priv_key,
  }
  class { '::neutron::agents::lbaas':
    interface_driver => $driver,
    debug            => true,
  }
  class { '::neutron::agents::l3':
    interface_driver => $driver,
    debug            => true,
    extensions       => 'fwaas',
  }
  class { '::neutron::agents::dhcp':
    interface_driver => $driver,
    debug            => true,
  }
  class { '::neutron::agents::metering':
    interface_driver => $driver,
    debug            => true,
  }
  class { '::neutron::server::notifications':
    auth_url => $::openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }
  class { '::neutron::services::fwaas':
    enabled       => true,
    agent_version => 'v1',
    driver        => 'neutron_fwaas.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver',

  }

}
