class openstack_integration::repos {

  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        release         => 'pike',
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
      $ceph_mirror = pick($::ceph_mirror_host, 'http://download.ceph.com/debian-luminous/')
    }
    'RedHat': {
      class { '::openstack_extras::repo::redhat::redhat':
        manage_rdo        => false,
        manage_epel       => false,
        centos_mirror_url => $::centos_mirror_host,
        repo_hash         => {
          'pike-puppet-passed-ci' => {
            'baseurl'  => pick($::rdo_mirror_host, 'https://trunk.rdoproject.org/centos7-master/puppet-passed-ci/'),
            'descr'    => 'Pike puppet-passed-ci',
            'gpgcheck' => 'no',
            'priority' => 1,
          },
          'pike-delorean-deps'    => {
            'baseurl'  => pick($::buildlogs_mirror_host, 'https://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-pike'),
            'descr'    => 'Pike delorean-deps',
            'gpgcheck' => 'no',
          },
        },
      }
      $ceph_mirror = pick($::ceph_mirror_host, 'https://buildlogs.centos.org/centos/7/storage/x86_64/ceph-luminous/')
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
