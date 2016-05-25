class openstack_integration::rabbitmq {

  case $::osfamily {
    'Debian': {
      $package_provider = 'apt'
    }
    'RedHat': {
      $package_provider = 'yum'
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

  class { '::rabbitmq':
    delete_guest_user => true,
    package_provider  => $package_provider,
    repos_ensure      => false,
  }
  rabbitmq_vhost { '/':
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }

}
