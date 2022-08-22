# Configure the Tempest service
#
# [*aodh*]
#   (optional) Define if Aodh needs to be tested.
#   Default to false.
#
# [*barbican*]
#   (optional) Define if Barbican needs to be tested.
#   Default to false.
#
# [*bgpvpn*]
#   (optional) Define if BGPVPN needs to be tested.
#   Default to false.
#
# [*ceilometer*]
#   (optional) Define if Ceilometer needs to be tested.
#   Default to false.
#
# [*cinder*]
#   (optional) Define if Cinder needs to be tested.
#   Default to false.
#
# [*cinder_backup*]
#   (optional) Define if Cinder Backup needs to be tested.
#   Default to false.
#
# [*designate*]
#   (optional) Define if Designate needs to be tested.
#   Default to false.
#
# [*ec2api*]
#   (optional) Define if EC2-API needs to be tested.
#   Default to false.
#
# [*glance*]
#   (optional) Define if Glance needs to be tested.
#   Default to true.
#
# [*gnocchi*]
#   (optional) Define if Gnocchi needs to be tested.
#   Default to false.
#
# [*heat*]
#   (optional) Define if Heat needs to be tested.
#   Default to false.
#
# [*horizon*]
#   (optional) Define if Horizon needs to be tested.
#   Default to false.
#
# [*ironic*]
#   (optional) Define if Ironic needs to be tested.
#   Default to false.
#
# [*l2gw*]
#   (optional) Define if L2GW needs to be tested.
#   Default to false.
#
# [*l2gw_switch*]
#   (optional) Define a switch name for testing.
#   Default to undef.
#
# [*dr*]
#   (optional) Define if Neutron Dynamic routing needs to be tested.
#   Default to false.
#
# [*magnum*]
#   (optional) Define if Magmum needs to be tested.
#   Default to false.
#
# [*mistral*]
#   (optional) Define if Mistral needs to be tested.
#   Default to false.
#
# [*neutron*]
#   (optional) Define if Neutron needs to be tested.
#   Default to true.
#
# [*nova*]
#   (optional) Define if Nova needs to be tested.
#   Default to true.
#
# [*octavia*]
#   (optional) Define if Octavia needs to be tested.
#   Default to false.
#
# [*sahara*]
#   (optional) Define if Sahara needs to be tested.
#   Default to false.
#
# [*murano*]
#   (optional) Define if Murano needs to be tested.
#   Default to false.
#
# [*swift*]
#   (optional) Define if Swift needs to be tested.
#   Default to false.
#
# [*trove*]
#   (optional) Define if Trove needs to be tested.
#   Default to false.
#
# [*vitrage*]
#   (optional) Define if Vitrage needs to be tested.
#   Default to false.
#
# [*watcher*]
#   (optional) Define if Watcher needs to be tested.
#   Default to false.
#
# [*zaqar*]
#   (optional) Define if Zaqar needs to be tested.
#   Default to false.
#
# [*attach_encrypted_volume*]
#   (optional) Define if Encrypted Volumes need to be tested.
#   Default to false.
#
# [*configure_images*]
#   (optional) Define if images are configured for tempest.
#   Default to true.
#
# [*configure_networks*]
#   (optional) Define if networks are configured for tempest.
#   Default to true.
#
# [*neutron_driver*]
#   (optional) Neutron Driver to test
#   Can be: openvswitch, linuxbridge or ovn.
#   Defaults to 'openvswitch'.
#
# [*neutron_api_extensions*]
#   (optional) Define list of neutron API extensions to test.
#   The list is known to work with the repo; this reflects extensions enabled
#   in neutron gate, for the most part (minus features not configured like
#   trunk, dns-integration, qos, or port_security support)
#
# [*image_format*]
#   (optional) Format of glance images to be created.
#   Defaults to 'qcow2'
#
class openstack_integration::tempest (
  $aodh                    = false,
  $barbican                = false,
  $bgpvpn                  = false,
  $ceilometer              = false,
  $cinder                  = false,
  $cinder_backup           = false,
  $designate               = false,
  $ec2api                  = false,
  $glance                  = true,
  $gnocchi                 = false,
  $heat                    = false,
  $horizon                 = false,
  $ironic                  = false,
  $l2gw                    = false,
  $l2gw_switch             = undef,
  $dr                      = false,
  $magnum                  = false,
  $mistral                 = false,
  $murano                  = false,
  $neutron                 = true,
  $nova                    = true,
  $octavia                 = false,
  $sahara                  = false,
  $swift                   = false,
  $trove                   = false,
  $watcher                 = false,
  $vitrage                 = false,
  $zaqar                   = false,
  $attach_encrypted_volume = false,
  $configure_images        = true,
  $configure_networks      = true,
  $neutron_driver          = 'openvswitch',
  $neutron_api_extensions  = undef,
  $image_format            = 'qcow2',
) {

  include openstack_integration::config
  include openstack_integration::params

  if $neutron_api_extensions != undef {
    $neutron_api_extensions_real = $neutron_api_extensions
  } else {
    $neutron_base_extensions = [
      'address-scope',
      'agent',
      'allowed-address-pairs',
      'auto-allocated-topology',
      'availability_zone',
      'binding',
      'default-subnetpools',
      'dns-domain-ports',
      'dns-integration',
      'ext-gw-mode',
      'external-net',
      'extra_dhcp_opt',
      'extraroute',
      'flavors',
      'multi-provider',
      'net-mtu',
      'network-ip-availability',
      'network_availability_zone',
      'pagination',
      'project-id',
      'provider',
      'quotas',
      'rbac-policies',
      'router',
      'router_availability_zone',
      'security-group',
      'service-type',
      'sorting',
      'standard-attr-description',
      'standard-attr-revisions',
      'standard-attr-timestamp',
      'subnet_allocation',
      'tag',
      'tag-ext',
    ]

    if $neutron_driver == 'ovn' {
      $neutron_agent_scheduler_extensions = []
      $neutron_l3_extensions = []
      $neutron_metering_extensions = []
    } else {
      $neutron_agent_scheduler_extensions = ['dhcp_agent_scheduler', 'l3_agent_scheduler']
      $neutron_l3_extensions = ['dvr', 'l3-flavors', 'l3-ha']
      $neutron_metering_extensions = ['metering']
    }

    $neutron_l2gw_extensions = $l2gw ? {
      true    => ['l2-gateway', 'l2gateway-connection'],
      default => []
    }

    $neutron_api_extensions_real = sort(
      $neutron_base_extensions +
      $neutron_agent_scheduler_extensions +
      $neutron_l3_extensions +
      $neutron_metering_extensions +
      $neutron_l2gw_extensions
    )
  }

  # Install missed dependency for neutron tests
  # https://github.com/openstack/neutron/blob/master/test-requirements.txt#L20
  if ($::operatingsystem == 'Ubuntu') and (versioncmp($::operatingsystemmajrelease, '16') >= 0) {
    package { ['python3-ddt', 'python3-oslotest', 'python3-gabbi']:
      ensure => present
    }
  }

  if ($::osfamily == 'RedHat') and (versioncmp($::operatingsystemmajrelease, '9') >= 0) {
    # NOTE(tkajinam): The latest openssl in c9s repo doesn't accept SHA1 by
    #                 default, which is causing ssh with rsa keys to fail.
    #                 See bug 1962507 for details.
    $ssh_key_type = 'ecdsa'
  } else {
    $ssh_key_type = 'rsa'
  }

  $dashboard_url = $::osfamily ? {
    'RedHat' => "${::openstack_integration::config::base_url}/dashboard",
    default  => "${::openstack_integration::config::base_url}/horizon"
  }

  class { 'tempest':
    debug                              => true,
    use_stderr                         => false,
    log_file                           => 'tempest.log',
    tempest_clone_owner                => $::id,
    git_clone                          => false,
    tempest_clone_path                 => '/tmp/openstack/tempest',
    lock_path                          => '/tmp/openstack/tempest',
    tempest_config_file                => '/tmp/openstack/tempest/etc/tempest.conf',
    configure_images                   => $configure_images,
    configure_networks                 => $configure_networks,
    identity_uri_v3                    => "${::openstack_integration::config::keystone_auth_uri}/v3",
    admin_username                     => 'admin',
    admin_project_name                 => 'openstack',
    admin_password                     => 'a_big_secret',
    admin_domain_name                  => 'Default',
    auth_version                       => 'v3',
    tempest_roles                      => ['member', 'creator'], # needed to use barbican.
    image_name                         => 'cirros',
    image_name_alt                     => 'cirros_alt',
    cinder_available                   => $cinder,
    cinder_backup_available            => $cinder_backup,
    designate_available                => $designate,
    glance_available                   => $glance,
    horizon_available                  => $horizon,
    nova_available                     => $nova,
    octavia_available                  => $octavia,
    neutron_available                  => $neutron,
    neutron_bgpvpn_available           => $bgpvpn,
    neutron_l2gw_available             => $l2gw,
    neutron_dr_available               => $dr,
    barbican_available                 => $barbican,
    ceilometer_available               => $ceilometer,
    aodh_available                     => $aodh,
    trove_available                    => $trove,
    sahara_available                   => $sahara,
    heat_available                     => $heat,
    swift_available                    => $swift,
    ironic_available                   => $ironic,
    zaqar_available                    => $zaqar,
    mistral_available                  => $mistral,
    vitrage_available                  => $vitrage,
    gnocchi_available                  => $gnocchi,
    ec2api_available                   => $ec2api,
    watcher_available                  => $watcher,
    public_network_name                => 'public',
    neutron_api_extensions             => join(any2array($neutron_api_extensions_real), ','),
    dashboard_url                      => $dashboard_url,
    flavor_ref                         => '42',
    flavor_ref_alt                     => '84',
    db_flavor_ref                      => '42',
    image_ssh_user                     => 'cirros',
    image_alt_ssh_user                 => 'cirros',
    # TODO(emilien) optimization by 1/ using Hiera to configure Glance image source
    # and 2/ if running in the gate, use /home/jenkins/cache/files/ cirros image.
    img_file                           => "/tmp/openstack/image/cirros-0.5.1-x86_64-disk-${image_format}.img",
    img_disk_format                    => $image_format,
    compute_build_interval             => 10,
    ca_certificates_file               => $::openstack_integration::params::ca_bundle_cert_path,
    manage_tests_packages              => true,
    attach_encrypted_volume            => $attach_encrypted_volume,
    murano_available                   => $murano,
    tempest_workspace                  => '/tmp/openstack/tempest',
    run_ssh                            => true,
    ssh_key_type                       => $ssh_key_type,
    l2gw_switch                        => $l2gw_switch,
    disable_dashboard_ssl_validation   => true,
    baremetal_driver                   => 'fake-hardware',
    baremetal_enabled_hardware_types   => 'ipmi,fake-hardware',
    ec2api_tester_roles                => ['member'],
    load_balancer_member_role          => 'member',
    load_balancer_admin_role           => 'admin',
    load_balancer_observer_role        => 'member',
    load_balancer_global_observer_role => 'admin',
    load_balancer_test_with_noop       => true,
  }

  if $magnum {
    class { 'tempest::magnum':
      tempest_config_file => '/tmp/openstack/tempest/etc/tempest.conf',
    }
  }
}
