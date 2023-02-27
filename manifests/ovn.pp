# Configure the ovn service
#
class openstack_integration::ovn(
){

  include openstack_integration::config
  include openstack_integration::params

  class { 'ovn::northd':
    dbs_listen_ip => $::openstack_integration::config::ip_for_url,
  }
  class { 'ovn::controller':
    ovn_remote          => "tcp:${::openstack_integration::config::ip_for_url}:6642",
    ovn_encap_ip        => '127.0.0.1',
    ovn_bridge_mappings => ['external:br-ex'],
    ovn_cms_options     => 'enable-chassis-as-gw',
    manage_ovs_bridge   => false,
  }
}
