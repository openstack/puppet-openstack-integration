class openstack_integration::mongodb {

  include ::mongodb::globals
  include ::mongodb::client
  class { '::mongodb::server':
    replset         => 'openstack',
    replset_members => ['127.0.0.1:27017'],
  }

}
