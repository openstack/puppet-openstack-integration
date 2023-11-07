# Deploy OpenStack resources needed to run Tempest
# Provision based on service enabled
#
# [*glance*]
#   (optional) Define if Glance Resources needs to be created.
#   Default to true.
#
# [*neutron*]
#   (optional) Define if Neutron Resources needs to be created.
#   Default to true.
#
# [*nova*]
#   (optional) Define if Nova Resources needs to be created.
#   Default to true.
#
# [*image_format*]
#   (optional) Format of glance images to be created.
#   Defaults to 'qcow2'
#
class openstack_integration::provision (
  $glance       = true,
  $nova         = true,
  $neutron      = true,
  $image_format = 'qcow2',
){

  include openstack_integration::config

  if $nova {
    nova_flavor { 'm1.nano':
      ensure => present,
      id     => '42',
      ram    => '128',
      disk   => '2',
      vcpus  => '1',
    }
    nova_flavor { 'm1.micro':
      ensure => present,
      id     => '84',
      ram    => '128',
      disk   => '2',
      vcpus  => '1',
    }

    # NOTE(amoralej): "m1.tiny" flavor is required by murano scenario tests
    nova_flavor { 'm1.tiny':
      ensure => present,
      id     => '1',
      ram    => '128',
      disk   => '2',
      vcpus  => '1',
    }
    Keystone_user_role['admin@openstack'] -> Nova_flavor<||>
  }

  if $neutron {
    neutron_network { 'public':
      project_name              => 'openstack',
      router_external           => true,
      provider_physical_network => 'external',
      provider_network_type     => 'flat',
    }
    Keystone_user_role['admin@openstack'] -> Neutron_network<||>

    neutron_subnet { 'public-subnet':
      cidr             => '172.24.5.0/24',
      ip_version       => '4',
      allocation_pools => ['start=172.24.5.10,end=172.24.5.200'],
      gateway_ip       => '172.24.5.1',
      enable_dhcp      => false,
      network_name     => 'public',
      project_name     => 'openstack',
    }
  }

  if $glance {
    $image_path = "/tmp/openstack/image/cirros-0.6.2-x86_64-disk-${image_format}.img"

    glance_image { 'cirros':
      ensure           => present,
      container_format => 'bare',
      disk_format      => $image_format,
      is_public        => 'yes',
      source           => $image_path,
    }
    glance_image { 'cirros_alt':
      ensure           => present,
      container_format => 'bare',
      disk_format      => $image_format,
      is_public        => 'yes',
      source           => $image_path,
    }
    Keystone_user_role['admin@openstack'] -> Glance_image<||>
  }
}
