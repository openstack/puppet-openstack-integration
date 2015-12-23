# Configure the Tempest service
#
# [*aodh*]
#   (optional) Define if Aodh needs to be tested.
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
# [*glance*]
#   (optional) Define if Glance needs to be tested.
#   Default to true.
#
# [*heat*]
#   (optional) Define if Heat needs to be tested.
#   Default to false.
#
# [*horizon*]
#   (optional) Define if Horizon needs to be tested.
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
# [*sahara*]
#   (optional) Define if Sahara needs to be tested.
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
class openstack_integration::tempest (
  $aodh       = false,
  $ceilometer = false,
  $cinder     = false,
  $glance     = true,
  $heat       = false,
  $horizon    = false,
  $neutron    = true,
  $nova       = true,
  $sahara     = false,
  $swift      = false,
  $trove      = false,
) {

  class { '::tempest':
    debug                => true,
    use_stderr           => false,
    log_file             => 'tempest.log',
    tempest_clone_owner  => $::id,
    git_clone            => false,
    tempest_clone_path   => '/tmp/openstack/tempest',
    lock_path            => '/tmp/openstack/tempest',
    tempest_config_file  => '/tmp/openstack/tempest/etc/tempest.conf',
    configure_images     => true,
    configure_networks   => true,
    identity_uri         => 'http://127.0.0.1:5000/v2.0',
    identity_uri_v3      => 'http://127.0.0.1:5000/v3',
    admin_username       => 'admin',
    admin_tenant_name    => 'openstack',
    admin_password       => 'a_big_secret',
    admin_domain_name    => 'Default',
    auth_version         => 'v3',
    image_name           => 'cirros',
    image_name_alt       => 'cirros_alt',
    cinder_available     => $cinder,
    glance_available     => $glance,
    horizon_available    => $horizon,
    nova_available       => $nova,
    neutron_available    => $neutron,
    ceilometer_available => $ceilometer,
    aodh_available       => $aodh,
    trove_available      => $trove,
    sahara_available     => $sahara,
    heat_available       => $heat,
    swift_available      => $swift,
    public_network_name  => 'public',
    dashboard_url        => "http://${::hostname}/",
    flavor_ref           => '42',
    flavor_ref_alt       => '84',
    image_ssh_user       => 'cirros',
    image_alt_ssh_user   => 'cirros',
    img_file             => 'cirros-0.3.4-x86_64-disk.img',
    # TODO(emilien) optimization by 1/ using Hiera to configure Glance image source
    # and 2/ if running in the gate, use /home/jenkins/cache/files/ cirros image.
    # img_dir            => '/home/jenkins/cache/files',
    img_dir              => '/tmp/openstack/tempest',
  }
}
