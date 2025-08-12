# Configure the Neutron service
#
# [*driver*]
#   (optional) Neutron Driver to test
#   Can be: openvswitch or ovn.
#   Defaults to 'openvswitch'.
#
# [*ovn_metadata_agent_enabled*]
#   (optional) Enable ovn-metadata-agent
#   Defaults to true
#
# [*metering_enabled*]
#   (optional) Flag to enable metering agent
#   Defaults to false.
#
# [*vpnaas_enabled*]
#   (optional) Flag to enable VPNaaS.
#   Defaults to false.
#
# [*taas_enabled*]
#   (optional) Flag to enable TAPaaS.
#   Defaults to false.
#
# [*bgpvpn_enabled*]
#   (optional) Flag to enable BGPVPN API extensions.
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
# [*designate_enabled*]
#   (optional) Flag to enable external dns integration with Designate
#   Defaults to false.
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
class openstack_integration::neutron (
  $driver                     = 'openvswitch',
  $ovn_metadata_agent_enabled = true,
  $metering_enabled           = false,
  $vpnaas_enabled             = false,
  $taas_enabled               = false,
  $bgpvpn_enabled             = false,
  $l2gw_enabled               = false,
  $bgp_dragent_enabled        = false,
  $baremetal_enabled          = false,
  $designate_enabled          = false,
  $notification_topics        = $facts['os_service_default'],
) {

  $use_httpd = $facts['os']['family'] ? {
    'RedHat' => true,
    default  => false,
  }

  include openstack_integration::config
  include openstack_integration::params

  if $driver == 'ovn' {
    if $metering_enabled {
      fail('Metering agent is not supported when ovn mechanism driver is used.')
    }
    if $bgpvpn_enabled {
      fail('BGP VPN is not supported when ovn mechanism driver is used.')
    }
    if $l2gw_enabled {
      fail('L2GW is not supported when ovn mechanism driver is used.')
    }
    if $bgp_dragent_enabled {
      fail('BGP dragent is not supported when ovn mechanism driver is used.')
    }
  }

  if $driver != 'openvswitch' and $taas_enabled {
    fail('TaaS is supported only when ovs mechanism driver is used.')
  }

  if $::openstack_integration::config::ssl {
    $api_service = $use_httpd ? {
      true    => 'httpd',
      default => 'neutron-server',
    }

    openstack_integration::ssl_key { 'neutron':
      notify  => Service[$api_service],
      require => Anchor['neutron::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service[$api_service]

    if $driver == 'ovn' {
      openstack_integration::ovn::ssl_key { 'neutron':
        notify  => Anchor['neutron::service::begin'],
        require => Anchor['neutron::install::end'],
      }
    }
  }

  if $facts['os']['name'] == 'CentOS' {
    # os_neutron_dac_override should be on to start privsep-helper
    # See https://bugzilla.redhat.com/show_bug.cgi?id=1850973
    selboolean { 'os_neutron_dac_override':
      persistent => true,
      value      => on,
      require    => Package['openstack-selinux'],
      before     => Anchor['neutron::service::begin'],
    }

    if $driver == 'openvswitch' {
      selboolean { 'os_dnsmasq_dac_override':
        persistent => true,
        value      => on,
        require    => Package['openstack-selinux'],
        before     => Anchor['neutron::service::begin'],
      }
      selboolean { 'os_keepalived_dac_override':
        persistent => true,
        value      => on,
        require    => Package['openstack-selinux'],
        before     => Anchor['neutron::service::begin'],
      }
    }
  }

  openstack_integration::mq_user { 'neutron':
    password => 'an_even_bigger_secret',
    before   => Anchor['neutron::service::begin'],
  }

  case $driver {
    'openvswitch': {
      require openstack_integration::ovs
    }
    'ovn': {
      require openstack_integration::ovn
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
    $vpaaas_plugin = $vpnaas_enabled ? {
      true    => 'ovn-vpnaas',
      default => undef,
    }
    $plugins_list = delete_undef_values([
      'qos', 'ovn-router', 'trunk', $vpaaas_plugin,
    ])
  } else {
    $dhcp_agent_notification = true
    $metering_plugin = $metering_enabled ? {
      true    => 'metering',
      default => undef,
    }
    $vpaaas_plugin = $vpnaas_enabled ? {
      true    => 'vpnaas',
      default => undef,
    }
    $taas_plugin = $taas_enabled ? {
      true    => 'taas',
      default => undef,
    }
    $bgpvpn_plugin = $bgpvpn_enabled ? {
      true    => 'bgpvpn',
      default => undef,
    }
    $l2gw_plugin = $l2gw_enabled ? {
      true    => 'l2gw',
      default => undef,
    }
    $bgp_dr_plugin = $bgp_dragent_enabled ? {
      true    => 'bgp',
      default => undef,
    }

    $plugins_list = delete_undef_values([
      'router', 'qos', 'trunk',
      $metering_plugin,
      $vpaaas_plugin,
      $taas_plugin,
      $bgpvpn_plugin,
      $l2gw_plugin,
      $bgp_dr_plugin
    ])
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
    core_plugin                => 'ml2',
    service_plugins            => $plugins_list,
    bind_host                  => $::openstack_integration::config::host,
    use_ssl                    => $::openstack_integration::config::ssl,
    cert_file                  => $::openstack_integration::params::cert_path,
    key_file                   => "/etc/neutron/ssl/private/${facts['networking']['fqdn']}.pem",
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
    dhcp_agent_notification    => $dhcp_agent_notification,
  }
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

  class { 'neutron::cache':
    backend          => $::openstack_integration::config::cache_driver,
    enabled          => true,
    memcache_servers => $::openstack_integration::config::memcache_servers,
    redis_server     => $::openstack_integration::config::redis_server,
    redis_password   => 'a_big_secret',
    redis_sentinels  => $::openstack_integration::config::redis_sentinel_server,
    tls_enabled      => $::openstack_integration::config::cache_tls_enabled,
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

  if $use_httpd {
    class { 'neutron::wsgi::apache':
      bind_host => $::openstack_integration::config::host,
      ssl_key   => "/etc/neutron/ssl/private/${facts['networking']['fqdn']}.pem",
      ssl_cert  => $::openstack_integration::params::cert_path,
      ssl       => $::openstack_integration::config::ssl,
      workers   => 2,
    }

    $vpnaas_conf = $vpnaas_enabled ? {
      true    => 'neutron_vpnaas.conf',
      default => undef,
    }
    $taas_conf = $taas_enabled ? {
      true    => 'taas_plugin.ini',
      default => undef,
    }
    $bgpvpn_conf = $bgpvpn_enabled ? {
      true    => 'networking_bgpvpn.conf',
      default => undef,
    }
    $l2gw_conf = $l2gw_enabled ? {
      true    => 'networking_l2gw.conf',
      default => undef,
    }

    $neutron_conf_files = delete_undef_values([
      'neutron.conf', 'plugins/ml2/ml2_conf.ini',
      $vpnaas_conf, $taas_conf, $bgpvpn_conf, $l2gw_conf
    ])

    # TODO(tkajinam): Should this be in puppet-neutron ?
    systemd::dropin_file { 'apache-os-neutron':
      unit     => "${::apache::service::service_name}.service",
      filename => 'os-neutron.conf',
      content  => "[Service]
Environment=OS_NEUTRON_CONFIG_FILES=${join($neutron_conf_files, ';')}",
      require  => Package['httpd'],
    }

    $server_service_name = false
    $api_service_name = 'httpd'
  } else {
    $server_service_name = $::neutron::params::server_service
    $api_service_name = $::neutron::params::api_service_name
  }

  $rpc_workers = $driver ? {
    'ovn'   => $vpnaas_enabled ? {
      true    => 2,
      default => 0,
    },
    default => 2,
  }
  $rpc_state_report_workers = $driver ? {
    'ovn'   => 0,
    default => $facts['os_service_default'],
  }
  $rpc_service_name = $rpc_workers ? {
    0       => false,
    default => $::neutron::params::rpc_service_name
  }

  class { 'neutron::server':
    sync_db                  => true,
    api_workers              => 2,
    rpc_workers              => $rpc_workers,
    rpc_state_report_workers => $rpc_state_report_workers,
    rpc_response_max_timeout => 300,
    service_name             => $server_service_name,
    api_service_name         => $api_service_name,
    rpc_service_name         => $rpc_service_name,
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
    tenant_network_types => [$overlay_network_type],
    extension_drivers    => 'port_security,qos',
    mechanism_drivers    => $drivers_real,
    network_vlan_ranges  => 'external:1000:2999',
    max_header_size      => $max_header_size,
    overlay_ip_version   => $::openstack_integration::config::ip_version,
  }

  case $driver {
    'openvswitch': {
      $agent_extensions = $taas_enabled ? {
        true    => ['taas'],
        default => $facts['os_service_default'],
      }

      class { 'neutron::agents::ml2::ovs':
        local_ip          => $::openstack_integration::config::host,
        tunnel_types      => ['vxlan'],
        bridge_mappings   => ['external:br-ex'],
        manage_vswitch    => false,
        firewall_driver   => 'iptables_hybrid',
        of_listen_address => $::openstack_integration::config::host,
        extensions        => $agent_extensions,
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
    default: {
      fail("Unsupported neutron driver (${driver})")
    }
  }

  if $driver == 'ovn' {
    $ovn_agent_extensions = $ovn_metadata_agent_enabled ? {
      false   => ['metadata'],
      default => undef
    }
    if ! $ovn_metadata_agent_enabled {
      class { 'neutron::agents::ml2::ovn::metadata':
        shared_secret     => 'a_big_secret',
        metadata_host     => $::openstack_integration::config::host,
        metadata_protocol => $::openstack_integration::config::proto,
      }
    }
    class { 'neutron::agents::ml2::ovn':
      debug              => true,
      extensions         => $ovn_agent_extensions,
      ovn_nb_connection  => $::openstack_integration::config::ovn_nb_connection,
      ovn_nb_private_key => '/etc/neutron/ovnnb-privkey.pem',
      ovn_nb_certificate => '/etc/neutron/ovnnb-cert.pem',
      ovn_nb_ca_cert     => '/etc/neutron/switchcacert.pem',
      ovn_sb_connection  => $::openstack_integration::config::ovn_sb_connection,
      ovn_sb_private_key => '/etc/neutron/ovnsb-privkey.pem',
      ovn_sb_certificate => '/etc/neutron/ovnsb-cert.pem',
      ovn_sb_ca_cert     => '/etc/neutron/switchcacert.pem',
    }

    if $ovn_metadata_agent_enabled {
      class { 'neutron::agents::ovn_metadata':
        debug              => true,
        shared_secret      => 'a_big_secret',
        metadata_host      => $::openstack_integration::config::host,
        metadata_protocol  => $::openstack_integration::config::proto,
        ovn_sb_connection  => $::openstack_integration::config::ovn_sb_connection,
        ovn_sb_private_key => '/etc/neutron/ovnsb-privkey.pem',
        ovn_sb_certificate => '/etc/neutron/ovnsb-cert.pem',
        ovn_sb_ca_cert     => '/etc/neutron/switchcacert.pem',
      }
    }

    $vpn_device_driver = $facts['os']['family'] ? {
      'Debian' => 'neutron_vpnaas.services.vpn.device_drivers.ovn_ipsec.OvnStrongSwanDriver',
      default  => 'neutron_vpnaas.services.vpn.device_drivers.ovn_ipsec.OvnLibreSwanDriver',
    }
    $vpnaas_driver = 'neutron_vpnaas.services.vpn.service_drivers.ovn_ipsec.IPsecOvnVPNDriver'
    if $vpnaas_enabled {
      class { 'neutron::agents::vpnaas::ovn':
        debug              => true,
        vpn_device_driver  => $vpn_device_driver,
        interface_driver   => 'openvswitch',
        ovn_sb_connection  => $::openstack_integration::config::ovn_sb_connection,
        ovn_sb_private_key => '/etc/neutron/ovnsb-privkey.pem',
        ovn_sb_certificate => '/etc/neutron/ovnsb-cert.pem',
        ovn_sb_ca_cert     => '/etc/neutron/switchcacert.pem',
      }
    }

    if $use_httpd {
      class { 'neutron::plugins::ml2::ovn::maintenance_worker': }
    }
  } else {
    class { 'neutron::agents::metadata':
      debug             => true,
      shared_secret     => 'a_big_secret',
      metadata_workers  => 2,
      metadata_host     => $::openstack_integration::config::host,
      metadata_protocol => $::openstack_integration::config::proto,
    }

    $l3_extensions = $vpnaas_enabled ? {
      true    => ['vpnaas'],
      default => $facts['os_service_default'],
    }
    class { 'neutron::agents::l3':
      interface_driver => $driver,
      debug            => true,
      extensions       => $l3_extensions,
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

    $vpn_device_driver = $facts['os']['family'] ? {
      'Debian' => 'neutron_vpnaas.services.vpn.device_drivers.strongswan_ipsec.StrongSwanDriver',
      default  => 'neutron_vpnaas.services.vpn.device_drivers.libreswan_ipsec.LibreSwanDriver'
    }
    $vpnaas_driver = 'neutron_vpnaas.services.vpn.service_drivers.ipsec.IPsecVPNDriver'
    if $vpnaas_enabled {
      class { 'neutron::agents::vpnaas':
        vpn_device_driver => $vpn_device_driver,
        interface_driver  => $driver,
      }
    }

    if $taas_enabled {
      class { 'neutron::agents::taas': }
      class { 'neutron::services::taas': }
    }
    if $l2gw_enabled {
      class { 'neutron::services::l2gw':
        # NOTE(tkajinm): This value is picked up from the one used in CI, but is
        # apparently wrong (It should have rpc_l2gw), but we can't enable
        # the correct provider because of incomplete setup we have in CI.
        service_providers => ['L2GW:l2gw:networking_l2gw.services.l2gateway.service_drivers.L2gwDriver:default']
      }
      class { 'neutron::agents::l2gw': }
    }
    if $bgpvpn_enabled {
      class {'neutron::services::bgpvpn':
        service_providers => 'BGPVPN:Dummy:networking_bgpvpn.neutron.services.service_drivers.driver_api.BGPVPNDriver:default'
      }
    }
    if $bgp_dragent_enabled {
      class {'neutron::services::dr': }
      class {'neutron::agents::bgp_dragent':
        bgp_router_id => '127.0.0.1'
      }
    }
  }

  if $vpnaas_enabled {
    $vpnaas_service_provider = $facts['os']['family'] ? {
      'Debian' => 'strongswan',
      default  => 'openswan'
    }

    class { 'neutron::services::vpnaas':
      service_providers => join([
        'VPN',
        $vpnaas_service_provider,
        $vpnaas_driver,
        'default'
      ], ':')
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

  if $designate_enabled {
    class { 'neutron::designate':
      password => 'a_big_secret',
      url      => "${::openstack_integration::config::base_url}:9001",
      auth_url => $::openstack_integration::config::keystone_admin_uri,
    }
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

  # TODO(tkajinam): Remove this once the following change is available
  # https://review.opendev.org/c/x/networking-l2gw/+/951422
  if $l2gw_enabled {
    file { '/etc/neutron/networking_l2gw.conf':
      ensure  => 'link',
      target  => '/etc/neutron/l2gw_plugin.ini',
      replace => false,
      require => Anchor['neutron::install::end'],
      before  => Anchor['neutron::config::begin'],
    }
  }
}
