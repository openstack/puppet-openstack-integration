class openstack_integration::repos {

  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        release         => 'mitaka',
        package_require => true,
        uca_location    => $::ubuntu_mirror_host,
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
        release           => 'mitaka',
        manage_epel       => false,
        centos_mirror_url => $::centos_mirror_host,
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
  if $::osfamily == 'RedHat' {
    # Hack to unblock mitaka gate
    # once unblock this will be in puppet-ceph
    # https://review.openstack.org/#/c/410823
    ini_setting { 'ceph priority':
      ensure  => present,
      path    => '/etc/yum.repos.d/CentOS-Ceph-Hammer.repo',
      section => 'centos-ceph-hammer',
      setting => 'priority',
      value   => 1,
    }
    Exec['installing_centos-release-ceph'] -> Ini_setting['ceph priority']
    Ini_setting['ceph priority'] -> Package<| tag == 'ceph' |>
  }

}
