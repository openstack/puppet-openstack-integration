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
        manage_rdo => false,
        repo_hash  => {
          'mitaka-current-passed-ci' => {
            'baseurl'  => 'http://trunk.rdoproject.org/centos7/current-passed-ci/',
            'descr'    => 'Mitaka tested',
            'gpgcheck' => 'no',
            'priority' => 1,
          },
          'delorean-deps'            => {
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
