class openstack_integration::repos {

  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        release         => 'liberty',
        package_require => true,
      }
    }
    'RedHat': {
      class { '::openstack_extras::repo::redhat::redhat':
        release => 'liberty',
      }
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

}
