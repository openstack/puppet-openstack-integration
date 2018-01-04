# Deploy OpenStack resources needed to run Tempest

class openstack_integration::provision {

  include ::openstack_integration::config

  nova_flavor { 'm1.nano':
    ensure => present,
    id     => '42',
    ram    => '128',
    disk   => '0',
    vcpus  => '1',
  }
  nova_flavor { 'm1.micro':
    ensure => present,
    id     => '84',
    ram    => '128',
    disk   => '0',
    vcpus  => '1',
  }
  # NOTE(ykarel): "m1.small" flavor is required by murano scenario tests
  nova_flavor { 'm1.small':
    ensure => present,
    id     => '2',
    ram    => '128',
    disk   => '0',
    vcpus  => '1',
  }
  # NOTE(amoralej): "m1.tiny" flavor is required by murano scenario tests
  # https://review.openstack.org/#/c/480848/ moved jobs from m1.small
  nova_flavor { 'm1.tiny':
    ensure => present,
    id     => '1',
    ram    => '128',
    disk   => '0',
    vcpus  => '1',
  }
  Keystone_user_role <||>-> Nova_flavor<||>
  Keystone_endpoint <||>-> Nova_flavor<||>
  Keystone_user_role['admin@openstack'] -> Nova_flavor<||>

  neutron_network { 'public':
    tenant_name               => 'openstack',
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
    tenant_name      => 'openstack',
  }

  glance_image { 'cirros':
    ensure           => present,
    container_format => 'bare',
    disk_format      => 'qcow2',
    is_public        => 'yes',
    source           => '/tmp/openstack/image/cirros-0.4.0-x86_64-disk.img'
  }
  glance_image { 'cirros_alt':
    ensure           => present,
    container_format => 'bare',
    disk_format      => 'qcow2',
    is_public        => 'yes',
    source           => '/tmp/openstack/image/cirros-0.4.0-x86_64-disk.img'
  }
  Keystone_user_role['admin@openstack'] -> Glance_image<||>
}
