class openstack_integration::repos {

  $ceph_version_real = pick($facts['ceph_version'], 'reef')

  if $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['major'], '22') >= 0 {
    # NOTE(tkajinam): Upstream ceph repository does not provide packages for
    #                 Ubuntu Jammy, so we use packages from UCA.
    $enable_ceph_repository = false
  } else {
    $enable_ceph_repository = true
  }

  case $facts['os']['family'] {
    'Debian': {
      case $facts['os']['name'] {
        'Ubuntu': {
          include apt
          class { 'openstack_extras::repo::debian::ubuntu':
            release         => 'caracal',
            package_require => true,
            uca_location    => pick($facts['uca_mirror_host'], 'http://ubuntu-cloud.archive.canonical.com/ubuntu'),
          }
        }
        'Debian': {
          include apt
          class { 'openstack_extras::repo::debian::debian':
            release         => 'caracal',
            package_require => true,
          }
        }
        default: {
          fail("Unsupported package type (${facts['os']['name']})")
        }
      }

      $ceph_mirror = pick($facts['ceph_mirror_host'], "http://download.ceph.com/debian-${ceph_version_real}/")
      if $enable_ceph_repository {
        # Ceph is both packaged on UCA and official download.ceph.com packages
        # which we mirror. We want to use the official packages or our mirror.
        if $ceph_mirror !~ '^http://download.ceph.com/.*' {
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
      }

      $enable_sig  = false
      $enable_epel = false
    }
    'RedHat': {
      $centos_mirror = pick(
        $facts['centos_mirror_host'],
        'http://mirror.stream.centos.org'
      )
      $delorean_repo = pick(
        $facts['delorean_repo_path'],
        "https://trunk.rdoproject.org/centos${facts['os']['release']['major']}-caracal/puppet-passed-ci/delorean.repo"
      )
      $delorean_deps_repo = pick(
        $facts['delorean_deps_repo_path'],
        "https://trunk.rdoproject.org/centos${facts['os']['release']['major']}-caracal/delorean-deps.repo"
      )

      class { 'openstack_extras::repo::redhat::redhat':
        manage_rdo        => false,
        manage_epel       => false,
        centos_mirror_url => $centos_mirror,
        repo_source_hash  => {
          'delorean.repo'      => $delorean_repo,
          'delorean-deps.repo' => $delorean_deps_repo
        },
        repo_replace      => false,
        update_packages   => true,
      }

      $ceph_mirror = pick(
        $facts['ceph_mirror_host'],
        "${centos_mirror}/SIGs/${facts['os']['release']['major']}-stream/storage/x86_64/ceph-${ceph_version_real}/"
      )

      # On CentOS, deploy Ceph using SIG repository and get rid of EPEL.
      # https://wiki.centos.org/SpecialInterestGroup/Storage/
      $enable_sig  = true
      $enable_epel = false

      exec { 'enable-crb':
        command => 'dnf config-manager --enable crb',
        path    => '/usr/bin/',
        unless  => 'test 0 -ne $(dnf repolist --enabled crb | wc -l)'
      }
    }
    default: {
      fail("Unsupported osfamily (${facts['os']['family']})")
    }
  }

  if $enable_ceph_repository {
    class { 'ceph::repo':
      enable_sig  => $enable_sig,
      enable_epel => $enable_epel,
      ceph_mirror => $ceph_mirror,
    }
  }

  # NOTE(tobias-urdin): Needed where augeas is used, like puppet-ovn.
  package { 'ruby-augeas':
    ensure => 'present',
  }

  if $facts['os']['family'] == 'RedHat' {
    # NOTE(tobias-urdin): Install libibverbs to fix an issue where OVS outputs errors
    # that causes the puppet-openvswitch module to fail parsing the output.
    # This issue does not occur in integration testing but only module tests since some
    # other package (probably nova) causes this package to be installed, or the yum upgrade
    # part in integration catches it.
    # Reported upstream: https://bugzilla.redhat.com/show_bug.cgi?id=1658141
    package { 'libibverbs':
      ensure => 'present',
    }

    Yumrepo<||> -> Package<| title == 'ruby-augeas' |>
  }
}
