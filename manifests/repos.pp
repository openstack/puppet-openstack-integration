class openstack_integration::repos {

  # To make beaker tests work.
  if $::ceph_version != '' {
    $ceph_version_real = $::ceph_version
  } else {
    $ceph_version_real = 'mimic'
  }
  case $::osfamily {
    'Debian': {
      case $::os_package_type {
        'ubuntu': {
          include ::apt
          class { '::openstack_extras::repo::debian::ubuntu':
            release         => 'rocky',
            package_require => true,
            uca_location    => pick($::uca_mirror_host, 'http://ubuntu-cloud.archive.canonical.com/ubuntu'),
            before          => File['/tmp/update-packages'],
          }
        }
        'debian': {
          include ::apt
          class { '::openstack_extras::repo::debian::debian':
            release         => 'queens',
            package_require => true,
            before          => File['/tmp/update-packages'],
          }
        }
        default: {
          fail("Unsupported package type (${::os_package_type})")
        }
      }
      # Ceph is both packaged on UCA and official download.ceph.com packages
      # which we mirror. We want to use the official packages or our mirror.
      if $::nodepool_mirror_host != '' {
        $ceph_version_cap = capitalize($ceph_version_real)
        apt::pin { 'ceph':
          priority   => 1001,
          originator => "Ceph ${ceph_version_cap}",
          before     => File['/tmp/update-packages'],
        }
      } else {
        apt::pin { 'ceph':
          priority => 1001,
          origin   => 'download.ceph.com',
          before   => File['/tmp/update-packages'],
        }
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
          'master-puppet-passed-ci' => {
            'baseurl'  => pick($::rdo_mirror_host, 'https://trunk.rdoproject.org/centos7-master/puppet-passed-ci/'),
            'descr'    => 'master puppet-passed-ci',
            'gpgcheck' => 'no',
            'priority' => 1,
          },
          'master-delorean-deps'    => {
            'baseurl'  => pick($::deps_mirror_host, 'https://trunk.rdoproject.org/centos7-master/deps/latest/'),
            'descr'    => 'master delorean-deps',
            'gpgcheck' => 'no',
          },
        },
        before            => File['/tmp/update-packages'],
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
      # Remove Fedora Base repos as stable-base repo is configured which includes
      # all required packages
      if $::operatingsystem == 'Fedora' {
        tidy { 'delete-fedora-base-repos':
          path    => '/etc/yum.repos.d',
          recurse => true,
          matches => [ 'fedora*.repo' ],
          rmdirs  => false,
          require => Class['::openstack_extras::repo::redhat::redhat'],
          before  => File['/tmp/update-packages'],
        }
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
    before      => File['/tmp/update-packages'],
  }

  # We want to upgrade packages after repos is added but only once
  # to not break idempotency. Must be done in here so it applies to
  # both integration and beaker tests.
  if $::osfamily == 'RedHat' {
    if $::operatingsystem == 'Fedora' {
      $yum_cmd = '/usr/bin/dnf'
    } else {
      $yum_cmd = '/usr/bin/yum'
    }
    $update_cmd = "${yum_cmd} update -y"
  } else {
    $update_cmd = '/usr/bin/apt upgrade -y'
  }

  file { '/tmp/update-packages':
    ensure => 'present',
    notify => Exec['update-packages'],
  }
  exec { 'update-packages':
    command     => $update_cmd,
    refreshonly => true,
  }

}
