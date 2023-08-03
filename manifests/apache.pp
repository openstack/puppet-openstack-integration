class openstack_integration::apache {

  include openstack_integration::params
  include openstack_integration::config
  include apache
}
