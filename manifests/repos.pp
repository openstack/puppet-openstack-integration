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
        manage_epel       => false,
        repo_hash         => {
          'mitaka-current' => {
            'baseurl'  => 'https://trunk.rdoproject.org/centos7-mitaka/ac/bd/acbdb030430df2af7d0e884ea7a2851e99b42944_a4c7ab2d/',
            'descr'    => 'Mitaka current',
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
