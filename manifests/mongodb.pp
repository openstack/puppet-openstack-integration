class openstack_integration::mongodb {

  include ::mongodb::globals
  include ::mongodb::server
  include ::mongodb::client

}
