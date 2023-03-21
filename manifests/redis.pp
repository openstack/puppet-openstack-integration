class openstack_integration::redis {
  include openstack_integration::config

  class { 'redis':
    bind           => $::openstack_integration::config::host,
    ulimit_managed => false,
    requirepass    => 'a_big_secret',
  }
}
