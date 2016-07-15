class openstack_integration::repos {

  case $::osfamily {
    'Debian': {
      include ::apt
      # Mitaka is already packaged in 16.04, so we don't need UCA.
      if ($::operatingsystem == 'Ubuntu') and ! (versioncmp($::operatingsystemmajrelease, '16') >= 0) {
        class { '::openstack_extras::repo::debian::ubuntu':
          release         => 'mitaka',
          package_require => true,
        }
      } else {
        class { '::openstack_extras::repo::debian::ubuntu':
          release         => 'newton',
          repo            => 'updates',
          package_require => true,
          uca_location    => $::ubuntu_mirror_host,
        }
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
          'newton-current'       => {
            'baseurl'  => 'https://trunk.rdoproject.org/centos7-master/8e/d2/8ed254d2f1c21e085a75adeeb71272e61ce46d1e_2f7f1004/',
            'descr'    => 'Newton current',
            'gpgcheck' => 'no',
            'priority' => 1,
          },
          'newton-delorean-deps' => {
            'baseurl'  => 'http://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-newton',
            'descr'    => 'Newton delorean-deps',
            'gpgcheck' => 'no',
            'priority' => 1,
          },
        }
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
  }

}
