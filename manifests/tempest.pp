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
# [*zaqar*]
#   (optional) Define if Zaqar needs to be tested.
#   Default to false.
#
# [*attach_encrypted_volume*]
#   (optional) Define if Encrypted Volumes need to be tested.
#   Default to false.
#
class openstack_integration::tempest (
  $aodh                    = false,
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
  $mistral                 = false,
  $murano                  = false,
  $neutron                 = true,
  $nova                    = true,
  $sahara                  = false,
  $swift                   = false,
  $trove                   = false,
  $zaqar                   = false,
  $attach_encrypted_volume = false,
) {

  include ::openstack_integration::config
  include ::openstack_integration::params

  # Install missed dependency for neutron tests
  # https://github.com/openstack/neutron/blob/master/test-requirements.txt#L20
  if ($::operatingsystem == 'Ubuntu') and (versioncmp($::operatingsystemmajrelease, '16') >= 0) {
    package { ['python-ddt', 'python-oslotest']:
      ensure => present
    }
  }

  class { '::tempest':
    debug                   => true,
    use_stderr              => false,
    log_file                => 'tempest.log',
    tempest_clone_owner     => $::id,
    git_clone               => false,
    tempest_clone_path      => '/tmp/openstack/tempest',
    lock_path               => '/tmp/openstack/tempest',
    tempest_config_file     => '/tmp/openstack/tempest/etc/tempest.conf',
    configure_images        => true,
    configure_networks      => true,
    identity_uri            => "${::openstack_integration::config::keystone_auth_uri}/v2.0",
    identity_uri_v3         => "${::openstack_integration::config::keystone_auth_uri}/v3",
    admin_username          => 'admin',
    admin_project_name      => 'openstack',
    admin_password          => 'a_big_secret',
    admin_domain_name       => 'Default',
    auth_version            => 'v3',
    tempest_roles           => ['Member', 'creator'], # needed to use barbican.
    image_name              => 'cirros',
    image_name_alt          => 'cirros_alt',
    cinder_available        => $cinder,
    cinder_backup_available => $cinder_backup,
    designate_available     => $designate,
    glance_available        => $glance,
    horizon_available       => $horizon,
    nova_available          => $nova,
    neutron_available       => $neutron,
    neutron_lbaas_available => true,
    neutron_fwaas_available => true,
    ceilometer_available    => $ceilometer,
    aodh_available          => $aodh,
    trove_available         => $trove,
    sahara_available        => $sahara,
    heat_available          => $heat,
    swift_available         => $swift,
    ironic_available        => $ironic,
    zaqar_available         => $zaqar,
    mistral_available       => $mistral,
    gnocchi_available       => $gnocchi,
    ec2api_available        => $ec2api,
    public_network_name     => 'public',
    dashboard_url           => $::openstack_integration::config::base_url,
    flavor_ref              => '42',
    flavor_ref_alt          => '84',
    db_flavor_ref           => '42',
    image_ssh_user          => 'cirros',
    image_alt_ssh_user      => 'cirros',
    img_file                => 'cirros-0.3.4-x86_64-disk.img',
    compute_build_interval  => 10,
    ca_certificates_file    => $::openstack_integration::params::ca_bundle_cert_path,
    manage_tests_packages   => true,
    attach_encrypted_volume => $attach_encrypted_volume,
    murano_available        => $murano,
    # TODO(emilien) optimization by 1/ using Hiera to configure Glance image source
    # and 2/ if running in the gate, use /home/jenkins/cache/files/ cirros image.
    # img_dir               => '/home/jenkins/cache/files',
    img_dir                 => '/tmp/openstack/tempest',
  }

}
