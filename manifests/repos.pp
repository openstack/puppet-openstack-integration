class openstack_integration::repos {

  # To make litmus tests work.
  if defined('$::ceph_version') and $::ceph_version != '' {
    $ceph_version_real = $::ceph_version
  } else {
    $ceph_version_real = 'pacific'
  }
  case $::osfamily {
    'Debian': {
      case $::operatingsystem {
        'Ubuntu': {
          include apt
          class { 'openstack_extras::repo::debian::ubuntu':
            release         => 'xena',
            package_require => true,
            uca_location    => pick($::uca_mirror_host, 'http://ubuntu-cloud.archive.canonical.com/ubuntu'),
          }
        }
        'Debian': {
          include apt
          class { 'openstack_extras::repo::debian::debian':
            release         => 'xena',
            package_require => true,
          }
        }
        default: {
          fail("Unsupported package type (${::operatingsystem})")
        }
      }
      # Ceph is both packaged on UCA and official download.ceph.com packages
      # which we mirror. We want to use the official packages or our mirror.
      if defined('$::nodepool_mirror_host') and $::nodepool_mirror_host != '' {
        $ceph_version_cap = capitalize($ceph_version_real)
        apt::pin { 'ceph':
          priority   => 1001,
          originator => "Ceph ${ceph_version_cap}",
        }
      } else {
        apt::pin { 'ceph':
          priority => 1001,
          origin   => 'download.ceph.com',
        }
      }
      $enable_sig  = false
      $enable_epel = false
      $ceph_mirror = pick($::ceph_mirror_host, "http://download.ceph.com/debian-${ceph_version_real}/")
    }
    'RedHat': {
      # Set specific variables for CentOS Stream 9
      if $::os['release']['major'] >= '9' {
        $powertools_repo = 'crb'
        $manage_virt     = false
      } else {
        $powertools_repo = 'powertools'
        $manage_virt     = true
      }
      if defined('$::centos_mirror_host') and $::centos_mirror_host != '' {
        $centos_mirror = $::centos_mirror_host
      } else {
        $centos_mirror = 'http://mirror.centos.org'
      }

      if defined('$::delorean_repo_path') and $::delorean_repo_path != '' {
        $delorean_repo = $::delorean_repo_path
      } else {
        $delorean_repo = "https://trunk.rdoproject.org/centos${::os['release']['major']}-yoga/puppet-passed-ci/delorean.repo"
      }

      if defined('$::delorean_deps_repo_path') and $::delorean_deps_repo_path != '' {
        $delorean_deps_repo = $::delorean_deps_repo_path
      } else {
        $delorean_deps_repo = "https://trunk.rdoproject.org/centos${::os['release']['major']}-yoga/delorean-deps.repo"
      }

      class { 'openstack_extras::repo::redhat::redhat':
        manage_rdo        => false,
        manage_epel       => false,
        manage_virt       => $manage_virt,
        centos_mirror_url => $centos_mirror,
        repo_source_hash  => {
          'delorean.repo'      => $delorean_repo,
          'delorean-deps.repo' => $delorean_deps_repo
        },
        repo_replace      => false,
        update_packages   => true,
      }
      $ceph_mirror_fallback = "${centos_mirror}/centos/${::os['release']['major']}-stream/storage/x86_64/ceph-${ceph_version_real}/"
      if defined('$::ceph_mirror_host') and $::ceph_mirror_host != '' {
        $ceph_mirror = pick($::ceph_mirror_host, $ceph_mirror_fallback)
      } else {
        $ceph_mirror = $ceph_mirror_fallback
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

      # PowerTools is required on CentOS8 since Ussuri.
      exec { 'enable-powertools':
        command => "dnf config-manager --enable ${powertools_repo}",
        path    => '/usr/bin/',
        unless  => "test 0 -ne $(dnf repolist --enabled ${powertools_repo} | wc -l)"
      }
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

  if $::osfamily == 'RedHat' or $::operatingsystem == 'Ubuntu' {
    class { 'ceph::repo':
      enable_sig  => $enable_sig,
      enable_epel => $enable_epel,
      ceph_mirror => $ceph_mirror,
    }
  }

  if $::osfamily == 'RedHat' {
    # NOTE(tobias-urdin): Install libibverbs to fix an issue where OVS outputs errors
    # that causes the puppet-openvswitch module to fail parsing the output.
    # This issue does not occur in integration testing but only module tests since some
    # other package (probably nova) causes this package to be installed, or the yum upgrade
    # part in integration catches it.
    # Reported upstream: https://bugzilla.redhat.com/show_bug.cgi?id=1658141
    package { 'libibverbs':
      ensure => 'present',
    }

    # NOTE(tobias-urdin): Needed where augeas is used, like puppet-ovn.
    package { 'ruby-augeas':
      ensure => 'present',
    }
    Yumrepo<||> -> Package<| title == 'ruby-augeas' |>
  }

  if $::operatingsystem == 'Ubuntu' {
    # NOTE(tobias-urdin): Needed where augeas is used, like puppet-ovn.
    package { 'ruby-augeas':
      ensure => 'present',
    }
  }
}
