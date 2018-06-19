class openstack_integration::repos {

  # To make beaker tests work.
  if $::ceph_version != '' {
    $ceph_version_real = $::ceph_version
  } else {
    $ceph_version_real = 'luminous'
  }
  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        release         => 'queens',
        package_require => true,
        uca_location    => pick($::uca_mirror_host, 'http://ubuntu-cloud.archive.canonical.com/ubuntu'),
      }
      # Ceph is both packaged on UCA & ceph.com
      # Official packages are on ceph.com so we want to make sure
      # Ceph will be installed from there.
      apt::pin { 'ceph':
        priority => 1001,
        origin   => 'download.ceph.com',
      }
      $enable_sig  = false
      $enable_epel = false
      $ceph_mirror = pick($::ceph_mirror_host, "http://download.ceph.com/debian-${ceph_version_real}/")
    }
    'RedHat': {
      class { '::openstack_extras::repo::redhat::redhat':
        manage_rdo        => false,
        manage_epel       => false,
        centos_mirror_url => $::centos_mirror_host,
        repo_hash         => {
          'queens-puppet-passed-ci' => {
            'baseurl'  => pick($::rdo_mirror_host, 'https://trunk.rdoproject.org/centos7-queens/puppet-passed-ci/'),
            'descr'    => 'queens puppet-passed-ci',
            'gpgcheck' => 'no',
            'priority' => 1,
          },
          'queens-delorean-deps'    => {
            'baseurl'  => pick($::deps_mirror_host, 'https://trunk.rdoproject.org/centos7-queens/deps/latest/'),
            'descr'    => 'queens delorean-deps',
            'gpgcheck' => 'no',
          },
        },
      }
      # TODO(tobasco): Remove this CBS candidate repo for Mimic when Storage SIG release it.
      $ceph_mirror_fallback = $ceph_version_real ? {
        'mimic' => 'http://cbs.centos.org/repos/storage7-ceph-mimic-candidate/x86_64/os/',
        default => "https://buildlogs.centos.org/centos/7/storage/x86_64/ceph-${ceph_version_real}/"
      }
      $ceph_mirror = pick($::ceph_mirror_host, $ceph_mirror_fallback)
      # On CentOS, deploy Ceph using SIG repository and get rid of EPEL.
      # https://wiki.centos.org/SpecialInterestGroup/Storage/
      if $::operatingsystem == 'CentOS' {
        $enable_sig  = true
        $enable_epel = false
      } else {
        $enable_sig  = false
        $enable_epel = true
      }
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

  class { '::ceph::repo':
    enable_sig  => $enable_sig,
    enable_epel => $enable_epel,
    ceph_mirror => $ceph_mirror,
  }

}
