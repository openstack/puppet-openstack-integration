class openstack_integration::repos {

  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        repo            => 'proposed',
        release         => 'mitaka', # drop this line when mitaka is stable released
        package_require => true,
      }
    }
    'RedHat': {
      class { '::openstack_extras::repo::redhat::redhat':
        # pin a recent delorean but will be current-passed-ci later when RDO will be ready
        manage_rdo => false,
        repo_hash  => {
          'mitaka-current' => {
            'baseurl'  => 'http://trunk.rdoproject.org/centos7/ec/f9/ecf9888afcfccabdbb1d4c2f04f5ccd96ffa2f3d_0294440f/',
            'descr'    => 'Mitaka trunk',
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

}
