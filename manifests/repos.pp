class openstack_integration::repos {

  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        release         => 'pike',
        package_require => true,
        uca_location    => $::uca_mirror_host,
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
        manage_rdo  => false,
        manage_epel => false,
        repo_hash   => {
          'pike-puppet-passed-ci' => {
            'baseurl'  => $::rdo_mirror_host,
            'descr'    => 'Pike puppet-passed-ci',
            'gpgcheck' => 'no',
            'priority' => 1,
          },
          'pike-delorean-deps'    => {
            'baseurl'  => 'https://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-pike',
            'descr'    => 'Pike delorean-deps',
            'gpgcheck' => 'no',
          },
        },
      }
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

  # On CentOS, deploy Ceph using SIG repository and get rid of EPEL.
  # https://wiki.centos.org/SpecialInterestGroup/Storage/
  if $::operatingsystem == 'CentOS' {
    $enable_sig  = true
    $enable_epel = false
  } else {
    $enable_sig  = false
    $enable_epel = true
  }

  class { '::ceph::repo':
    enable_sig  => $enable_sig,
    enable_epel => $enable_epel,
    ceph_mirror => $::ceph_mirror_host,
  }

}
