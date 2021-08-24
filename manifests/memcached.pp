class openstack_integration::memcached {
  include openstack_integration::config

  class { 'memcached':
    listen   => $::openstack_integration::config::host,
    udp_port => 0,
  }
}
