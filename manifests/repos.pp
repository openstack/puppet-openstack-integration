class openstack_integration::repos {

  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        repo            => 'proposed',
        release         => 'mitaka', # drop this line when mitaka is stable released
        package_require => true,
      }
      # Ceph is both packaged on UCA & ceph.com
      # Official packages are on ceph.com so we want to make sure
      # Ceph will be installed from there.
      apt::pin { 'ceph':
        priority => 1001,
        origin   => 'download.ceph.com',
      }
    }
    'RedHat': {
      class { '::openstack_extras::repo::redhat::redhat':
        # yum-plugin-priorities is already managed by ::ceph::repo
        manage_priorities => false,
        manage_rdo        => false,
        repo_hash         => {
          'mitaka-current' => {
            'baseurl'  => 'https://trunk.rdoproject.org/centos7/f1/32/f132dea0b534b75815439431dc2d9a927ade2030_c08cc25a/',
            'descr'    => 'Mitaka Current',
            'gpgcheck' => 'no',
            'priority' => 1,
          },
          'delorean-deps'  => {
            'baseurl'  => 'http://buildlogs.centos.org/centos/7/cloud/$basearch/openstack-liberty/',
            'descr'    => 'Liberty delorean-deps',
            'gpgcheck' => 'no',
            'priority' => 2,
          },
        }
      }
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

  class { '::ceph::repo': }

}
