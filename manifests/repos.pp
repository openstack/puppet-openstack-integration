class openstack_integration::repos {

  case $facts['os']['family'] {
    'Debian': {
      case $facts['os']['name'] {
        'Ubuntu': {
          include apt
          class { 'openstack_extras::repo::debian::ubuntu':
            release         => 'epoxy',
            manage_uca      => true,
            package_require => true,
            uca_location    => pick($facts['uca_mirror_host'], 'http://ubuntu-cloud.archive.canonical.com/ubuntu'),
          }
        }
        'Debian': {
          include apt
          class { 'openstack_extras::repo::debian::debian':
            release         => 'epoxy',
            package_require => true,
          }
        }
        default: {
          fail("Unsupported package type (${facts['os']['name']})")
        }
      }
    }
    'RedHat': {
      $centos_mirror = pick(
        $facts['centos_mirror_host'],
        'http://mirror.stream.centos.org'
      )
      $delorean_repo = pick(
        $facts['delorean_repo_path'],
        "https://trunk.rdoproject.org/centos${facts['os']['release']['major']}-epoxy/puppet-passed-ci/delorean.repo"
      )
      $delorean_deps_repo = pick(
        $facts['delorean_deps_repo_path'],
        "https://trunk.rdoproject.org/centos${facts['os']['release']['major']}-epoxy/delorean-deps.repo"
      )

      class { 'openstack_extras::repo::redhat::redhat':
        manage_rdo        => false,
        centos_mirror_url => $centos_mirror,
        repo_source_hash  => {
          'delorean.repo'      => $delorean_repo,
          'delorean-deps.repo' => $delorean_deps_repo
        },
        repo_replace      => false,
        update_packages   => true,
      }

      $ceph_version_real = pick($facts['ceph_version'], 'reef')
      $ceph_mirror = pick(
        $facts['ceph_mirror_host'],
        "${centos_mirror}/SIGs/${facts['os']['release']['major']}-stream/storage/x86_64/ceph-${ceph_version_real}/"
      )

      # On CentOS, deploy Ceph using SIG repository and get rid of EPEL.
      # https://wiki.centos.org/SpecialInterestGroup/Storage/
      class { 'ceph::repo':
        enable_sig  => true,
        enable_epel => false,
        ceph_mirror => $ceph_mirror,
      }

      yumrepo { 'crb':
        enabled => true
      }
    }
    default: {
      fail("Unsupported osfamily (${facts['os']['family']})")
    }
  }
}
