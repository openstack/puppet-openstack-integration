class openstack_integration::repos {

  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        release         => 'liberty',
        package_require => true,
      }
      $package_provider = 'apt'
    }
    'RedHat': {
      class { '::openstack_extras::repo::redhat::redhat':
        release           => 'liberty',
        centos_mirror_url => $::nodepool_mirror_host,
      }
      package { 'openstack-selinux': ensure => 'latest' }
      $package_provider = 'yum'
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

}
