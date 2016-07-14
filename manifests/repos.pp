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
            'baseurl'  => 'https://trunk.rdoproject.org/centos7-master/8e/03/8e035655d276917f0044fd35a0af534f94a097c7_7754ba49/',
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
