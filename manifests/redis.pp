class openstack_integration::redis {
  include ::openstack_integration::config

  # due to issues in OpenStack CI with the redis package, we need to disable
  # the service enable flag. The service still starts but the management of
  # the service with systemd errors.
  if ($::os_package_type == 'debian') {
    $service_enable = false
  } else {
    $service_enable = true
  }

  class { '::redis':
    bind           => $::openstack_integration::config::host,
    service_enable => $service_enable
  }
}
