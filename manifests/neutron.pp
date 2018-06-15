# Configure the Neutron service
#
# [*driver*]
#   (optional) Neutron Driver to test
#   Can be: openvswitch or linuxbridge.
#   Defaults to 'openvswitch'.
#
# [*bgpvpn_enabled*]
#   (optional) Flag to enable BGPVPN
#   API extensions.
#   Defaults to false.
#
# [*l2gw_enabled*]
#   (optional) Flag to enable L2GW.
#   Defaults to false.
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $::os_service_default.
#
class openstack_integration::neutron (
  $driver              = 'openvswitch',
  $bgpvpn_enabled      = false,
  $l2gw_enabled        = false,
  $notification_topics = $::os_service_default,
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

  openstack_integration::mq_user { 'neutron':
    password => 'an_even_bigger_secret',
    before   => Anchor['neutron::service::begin'],
  }

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
      }
      -> vs_port { 'loop1':
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
  $bgpvpn_plugin = $bgpvpn_enabled ? {
    true => 'bgpvpn',
    default => undef,
  }
  if $l2gw_enabled {
    if ($::operatingsystem == 'Ubuntu') {
      class {'::neutron::services::l2gw': }
      $l2gw_provider = 'L2GW:l2gw:networking_l2gw.services.l2gateway.service_drivers.L2gwDriver:default'
    }
    elsif ($::operatingsystem != 'Ubuntu') {
      class {'::neutron::services::l2gw':
        service_providers => ['L2GW:l2gw:networking_l2gw.services.l2gateway.service_drivers.L2gwDriver:default']
      }
      $l2gw_provider = undef
    }
  }
  $l2gw_plugin = $l2gw_enabled ? {
    true => 'networking_l2gw.services.l2gateway.plugin.L2GatewayPlugin',
    default => undef,
  }
  $plugins_list = delete_undef_values(['router', 'metering', 'firewall', 'lbaasv2', 'qos', 'trunk', $bgpvpn_plugin, $l2gw_plugin])

  if $driver == 'linuxbridge' {
      $global_physnet_mtu    = '1450'
  } else {
      $global_physnet_mtu    = undef
  }

  class { '::neutron':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'neutron',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'neutron',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms       => 'PLAIN',
    allow_overlapping_ips      => true,
    core_plugin                => 'ml2',
    service_plugins            => $plugins_list,
    debug                      => true,
    bind_host                  => $::openstack_integration::config::host,
    use_ssl                    => $::openstack_integration::config::ssl,
    cert_file                  => $::openstack_integration::params::cert_path,
    key_file                   => "/etc/neutron/ssl/private/${::fqdn}.pem",
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
    global_physnet_mtu         => $global_physnet_mtu,
  }
  class { '::neutron::client': }
  class { '::neutron::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  $providers_list = delete_undef_values(['LOADBALANCER:Haproxy:neutron_lbaas.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default',
                                        'LOADBALANCERV2:Haproxy:neutron_lbaas.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default',
                                        'FIREWALL:Iptables:neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver:default',
                                        $l2gw_provider])

  if $::osfamily == 'Debian' {
    Service<| title == 'neutron-server'|> -> Openstacklib::Service_validation<| title == 'neutron-server' |> -> Neutron_network<||>
    $validate_neutron_server_service = true
  } else {
    $validate_neutron_server_service = false
  }
  class { '::neutron::server':
    database_connection => 'mysql+pymysql://neutron:neutron@127.0.0.1/neutron?charset=utf8',
    sync_db             => true,
    api_workers         => 2,
    rpc_workers         => 2,
    validate            => $validate_neutron_server_service,
    service_providers   => $providers_list,
  }

  class { '::neutron::services::lbaas': }
  class { '::neutron::plugins::ml2':
    type_drivers         => ['vxlan', 'vlan', 'flat'],
    tenant_network_types => ['vxlan', 'vlan', 'flat'],
    extension_drivers    => 'port_security,qos',
    mechanism_drivers    => $driver,
    firewall_driver      => $firewall_driver,
  }
  class { '::neutron::agents::metadata':
    debug            => true,
    shared_secret    => 'a_big_secret',
    metadata_workers => 2,
  }
  class { '::neutron::agents::lbaas':
    interface_driver => $driver,
    debug            => true,
  }
  if ($::os_package_type == 'debian') {
    class { '::neutron::agents::l3':
      interface_driver => $driver,
      debug            => true,
    }
  } else {
    class { '::neutron::agents::l3':
      interface_driver => $driver,
      debug            => true,
      extensions       => 'fwaas',
    }
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
  if $bgpvpn_enabled {
    class {'::neutron::services::bgpvpn':
      service_providers => 'BGPVPN:Dummy:networking_bgpvpn.neutron.services.service_drivers.driver_api.BGPVPNDriver:default'
    }
  }
}
