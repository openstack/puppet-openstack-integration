class openstack_integration::memcached {
  include ::openstack_integration::config

  class { '::memcached':
    listen_ip => $::openstack_integration::config::host,
    udp_port  => 0,
  }
}
