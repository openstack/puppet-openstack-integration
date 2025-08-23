# Configure the openvswitch service
#
# [*manage_bridge*]
#   (Optional) Set up br-ex bridge.
#   Defaults to true.
#
class openstack_integration::ovs (
  $manage_bridge = true
) {
  include vswitch::ovs

  if $manage_bridge {
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
}
