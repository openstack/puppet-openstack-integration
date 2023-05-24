# Configure the Neutron service
#
# [*driver*]
#   (optional) Neutron Driver to test
#   Can be: openvswitch, linuxbridge or ovn.
#   Defaults to 'openvswitch'.
#
# [*metering_enabled*]
#   (optional) Flag to enable metering agent
#   Defaults to false.
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
# [*bgp_dragent_enabled*]
#   (optional) Flag to enable BGP dragent
#   Defaults to false.
#
# [*baremetal_enabled*]
#   (optional) Flag to enable networking-baremetal
#   Defaults to false.
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
class openstack_integration::neutron (
  $driver              = 'openvswitch',
  $metering_enabled    = false,
  $bgpvpn_enabled      = false,
  $l2gw_enabled        = false,
  $bgp_dragent_enabled = false,
  $baremetal_enabled   = false,
  $notification_topics = $facts['os_service_default'],
) {

  include openstack_integration::config
  include openstack_integration::params

  if $driver == 'ovn' and $metering_enabled {
    fail('Metering agent is not supported when ovn mechanism driver is used.')
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'neutron':
      notify  => Service['neutron-server'],
      require => Package['neutron'],
    }
    Exec['update-ca-certificates'] ~> Service<| tag == 'neutron-service' |>

    if $driver == 'ovn' {
      ['ovnnb', 'ovnsb'].each |$ovndb| {
        ["${ovndb}-privkey.pem", "${ovndb}-cert.pem"].each |$ovn_ssl_file| {
          file { "/etc/neutron/${ovn_ssl_file}":
            ensure  => present,
            owner   => 'neutron',
            mode    => '0600',
            source  => "/etc/openvswitch/${ovn_ssl_file}",
            require => [
              Anchor['neutron::install::end'],
              Vswitch::Pki::Cert[$ovndb]
            ],
            notify  => Anchor['neutron::service::begin'],
          }
        }
      }

      file { '/etc/neutron/switchcacert.pem':
        ensure  => present,
        owner   => 'neutron',
        mode    => '0600',
        source  => '/var/lib/openvswitch/pki/switchca/cacert.pem',
        require => [
          Anchor['neutron::install::end'],
          Class['vswitch::pki::Cacert'],
        ],
        notify  => Anchor['neutron::service::begin'],
      }
    }
  }

  if $facts['os']['name'] == 'CentOS' {
    # os_neutron_dac_override should be on to start privsep-helper
    # See https://bugzilla.redhat.com/show_bug.cgi?id=1850973
    selboolean { 'os_neutron_dac_override':
      persistent => true,
      value      => on,
    }

    if $driver == 'openvswitch' or $driver == 'linuxbridge' {
      selboolean { 'os_dnsmasq_dac_override':
        persistent => true,
        value      => on,
      }
    }
  }

  openstack_integration::mq_user { 'neutron':
    password => 'an_even_bigger_secret',
    before   => Anchor['neutron::service::begin'],
  }

  case $driver {
    'openvswitch', 'ovn': {
      include vswitch::ovs
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
    }
    'linuxbridge': {
      exec { 'create_dummy_iface':
        path     => '/usr/bin:/bin:/usr/sbin:/sbin',
        provider => shell,
        unless   => 'ip l show loop0',
        command  => 'ip link add name loop0 type dummy && ip addr add 172.24.5.1/24 dev loop0 && ip link set loop0 up',
      }
    }
    default: {
      fail("Unsupported neutron driver (${driver})")
    }
  }

  class { 'neutron::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'neutron',
    host     => $::openstack_integration::config::host,
  }
  class { 'neutron::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9696",
    internal_url => "${::openstack_integration::config::base_url}:9696",
    admin_url    => "${::openstack_integration::config::base_url}:9696",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }

  if $driver == 'ovn' {
    $dhcp_agent_notification = false
    $plugins_list = ['qos', 'ovn-router', 'trunk']
    $providers_list = undef
  } else {
    $dhcp_agent_notification = true
    $metering_plugin = $metering_enabled ? {
      true    => 'metering',
      default => undef,
    }
    $bgpvpn_plugin = $bgpvpn_enabled ? {
      true    => 'bgpvpn',
      default => undef,
    }
    if $l2gw_enabled {
      if ($facts['os']['name'] == 'Ubuntu') {
        class { 'neutron::services::l2gw': }
        $providers_list = ['L2GW:l2gw:networking_l2gw.services.l2gateway.service_drivers.L2gwDriver:default']
      }
      elsif ($facts['os']['name'] != 'Ubuntu') {
        class { 'neutron::services::l2gw':
          service_providers => ['L2GW:l2gw:networking_l2gw.services.l2gateway.service_drivers.L2gwDriver:default']
        }
        $providers_list = undef
      }
      class { 'neutron::agents::l2gw': }
    } else {
      $providers_list = undef
    }
    $l2gw_plugin = $l2gw_enabled ? {
      true    => 'networking_l2gw.services.l2gateway.plugin.L2GatewayPlugin',
      default => undef,
    }
    $bgp_dr_plugin = $bgp_dragent_enabled ? {
      true    => 'neutron_dynamic_routing.services.bgp.bgp_plugin.BgpPlugin',
      default => undef,
    }

    $plugins_list = delete_undef_values(['router', 'qos', 'trunk', $metering_plugin, $bgpvpn_plugin, $l2gw_plugin, $bgp_dr_plugin])
  }

  if $driver == 'linuxbridge' {
    $global_physnet_mtu = '1450'
  } else {
    $global_physnet_mtu = undef
  }

  class { 'neutron::logging':
    debug => true,
  }
  class { 'neutron':
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
    core_plugin                => 'ml2',
    service_plugins            => $plugins_list,
    bind_host                  => $::openstack_integration::config::host,
    use_ssl                    => $::openstack_integration::config::ssl,
    cert_file                  => $::openstack_integration::params::cert_path,
    key_file                   => "/etc/neutron/ssl/private/${facts['networking']['fqdn']}.pem",
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
    global_physnet_mtu         => $global_physnet_mtu,
    dhcp_agent_notification    => $dhcp_agent_notification,
  }
  class { 'neutron::client': }
  class { 'neutron::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }

  if $facts['os']['family'] == 'Debian' {
    $auth_url = $::openstack_integration::config::keystone_auth_uri
    $auth_opts = "--os-auth-url ${auth_url} --os-project-name services --os-username neutron --os-identity-api-version 3"
    exec { 'check-neutron-server':
      command     => "openstack ${auth_opts} network list",
      environment => ['OS_PASSWORD=a_big_secret'],
      path        => '/usr/bin:/bin:/usr/sbin:/sbin',
      provider    => shell,
      timeout     => 60,
      tries       => 10,
      try_sleep   => 2,
      refreshonly => true,
    }
    Anchor['neutron::service::end'] ~> Exec['check-neutron-server'] -> Neutron_network<||>
  }

  class { 'neutron::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'neutron',
      'password' => 'neutron',
      'database' => 'neutron',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'neutron::server':
    sync_db                  => true,
    api_workers              => 2,
    rpc_workers              => 2,
    rpc_response_max_timeout => 300,
    service_providers        => $providers_list,
    ensure_dr_package        => $bgp_dragent_enabled,
  }

  $overlay_network_type = $driver ? {
    'ovn'   => 'geneve',
    default => 'vxlan'
  }
  $max_header_size = $driver ? {
    'ovn'   => 38,
    default => $facts['os_service_default']
  }
  $drivers_real = $baremetal_enabled ? {
    true    => [$driver, 'baremetal'],
    default => [$driver],
  }
  class { 'neutron::plugins::ml2':
    type_drivers         => [$overlay_network_type, 'vlan', 'flat'],
    tenant_network_types => [$overlay_network_type, 'vlan', 'flat'],
    extension_drivers    => 'port_security,qos',
    mechanism_drivers    => $drivers_real,
    max_header_size      => $max_header_size,
    overlay_ip_version   => $::openstack_integration::config::ip_version,
  }

  case $driver {
    'openvswitch': {
      class { 'neutron::agents::ml2::ovs':
        local_ip          => $::openstack_integration::config::host,
        tunnel_types      => ['vxlan'],
        bridge_mappings   => ['external:br-ex'],
        manage_vswitch    => false,
        firewall_driver   => 'iptables_hybrid',
        of_listen_address => $::openstack_integration::config::host,
      }
    }
    'ovn': {
      # NOTE(tkajinam): neutron::plugins::ml2::ovn requires neutron::plugins::ml2,
      #                 thus it should be included after neutron::plugins::ml2.
      class { 'neutron::plugins::ml2::ovn':
        ovn_nb_connection    => $::openstack_integration::config::ovn_nb_connection,
        ovn_nb_private_key   => '/etc/neutron/ovnnb-privkey.pem',
        ovn_nb_certificate   => '/etc/neutron/ovnnb-cert.pem',
        ovn_nb_ca_cert       => '/etc/neutron/switchcacert.pem',
        ovn_sb_connection    => $::openstack_integration::config::ovn_sb_connection,
        ovn_sb_private_key   => '/etc/neutron/ovnsb-privkey.pem',
        ovn_sb_certificate   => '/etc/neutron/ovnsb-cert.pem',
        ovn_sb_ca_cert       => '/etc/neutron/switchcacert.pem',
        ovn_metadata_enabled => true,
      }
    }
    'linuxbridge': {
      class { 'neutron::agents::ml2::linuxbridge':
        local_ip                    => $facts['networking']['ip'],
        tunnel_types                => ['vxlan'],
        physical_interface_mappings => ['external:loop0'],
        firewall_driver             => 'iptables',
      }
    }
    default: {
      fail("Unsupported neutron driver (${driver})")
    }
  }

  if $::openstack_integration::config::ssl {
    # with nova metadata api running via wsgi it is ssl terminated, also
    # neutron metadata agent does not support an ipv6 address for the
    # metadata_host, so we need to use the hostname
    $metadata_host     = 'localhost'
    $metadata_protocol = 'https'
  } else {
    $metadata_host     = $::openstack_integration::config::host
    $metadata_protocol = 'http'
  }

  if $driver == 'ovn' {
    class { 'neutron::agents::ovn_metadata':
      debug              => true,
      shared_secret      => 'a_big_secret',
      metadata_host      => $metadata_host,
      metadata_protocol  => $metadata_protocol,
      ovn_sb_connection  => $::openstack_integration::config::ovn_sb_connection,
      ovn_sb_private_key => '/etc/neutron/ovnsb-privkey.pem',
      ovn_sb_certificate => '/etc/neutron/ovnsb-cert.pem',
      ovn_sb_ca_cert     => '/etc/neutron/switchcacert.pem',
    }
  } else {
    class { 'neutron::agents::metadata':
      debug             => true,
      shared_secret     => 'a_big_secret',
      metadata_workers  => 2,
      metadata_host     => $metadata_host,
      metadata_protocol => $metadata_protocol,
    }
    class { 'neutron::agents::l3':
      interface_driver => $driver,
      debug            => true,
    }
    class { 'neutron::agents::dhcp':
      interface_driver => $driver,
      debug            => true,
    }

    if $metering_enabled {
      class { 'neutron::agents::metering':
        interface_driver => $driver,
        debug            => true,
      }
    }
  }

  if $baremetal_enabled {
    class { 'neutron::plugins::ml2::networking_baremetal': }
    class { 'neutron::agents::ml2::networking_baremetal':
      auth_url => $::openstack_integration::config::keystone_admin_uri,
      password => 'a_big_secret',
    }
    class { 'neutron::server::notifications::ironic':
      auth_url => $::openstack_integration::config::keystone_admin_uri,
      password => 'a_big_secret',
    }

    Anchor['ironic::service::end'] -> Service['ironic-neutron-agent-service']
  }

  class { 'neutron::server::notifications::nova':
    auth_url => $::openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }
  class { 'neutron::server::notifications': }
  class { 'neutron::server::placement':
    auth_url => $::openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }
  if $bgpvpn_enabled {
    class {'neutron::services::bgpvpn':
      service_providers => 'BGPVPN:Dummy:networking_bgpvpn.neutron.services.service_drivers.driver_api.BGPVPNDriver:default'
    }
  }
  if $bgp_dragent_enabled {
    class {'neutron::agents::bgp_dragent':
      bgp_router_id => '127.0.0.1'
    }
  }
}
