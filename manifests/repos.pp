class openstack_integration::repos {

  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        release         => 'liberty',
        package_require => true,
        uca_location    => $::ubuntu_mirror_host,
      }
      $package_provider = 'apt'
    }
    'RedHat': {
      class { '::openstack_extras::repo::redhat::redhat':
        release           => 'liberty',
        centos_mirror_url => $::centos_mirror_host,
      }
      package { 'openstack-selinux': ensure => 'latest' }
      $package_provider = 'yum'
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

}
