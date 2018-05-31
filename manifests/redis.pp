class openstack_integration::redis {
  include ::openstack_integration::config

  class { '::redis':
    bind           => $::openstack_integration::config::host,
    service_enable => false
  }
}
