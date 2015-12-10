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
            'baseurl'  => 'http://trunk.rdoproject.org/centos7/f9/69/f9694ad5989d24363df812b08e36bd3b30807257_e3635ace/',
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
