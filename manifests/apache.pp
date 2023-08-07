class openstack_integration::apache {

  include openstack_integration::params
  include openstack_integration::config
  class { 'apache':
    default_mods  => false,
    default_vhost => false,
  }
}
