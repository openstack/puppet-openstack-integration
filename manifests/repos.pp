class openstack_integration::repos {
  case $facts['os']['family'] {
    'Debian': {
      case $facts['os']['name'] {
        'Ubuntu': {
          include apt
          class { 'openstack_extras::repo::debian::ubuntu':
            release         => 'flamingo',
            manage_uca      => true,
            package_require => true,
            uca_location    => pick($facts['uca_mirror_host'], 'http://ubuntu-cloud.archive.canonical.com/ubuntu'),
          }
        }
        'Debian': {
          include apt
          class { 'openstack_extras::repo::debian::debian':
            release         => 'flamingo',
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
        "https://trunk.rdoproject.org/centos${facts['os']['release']['major']}-master/current/delorean.repo"
      )
      $delorean_deps_repo = pick(
        $facts['delorean_deps_repo_path'],
        "https://trunk.rdoproject.org/centos${facts['os']['release']['major']}-master/delorean-deps.repo"
      )

      class { 'openstack_extras::repo::redhat::redhat':
        manage_rdo        => false,
        centos_mirror_url => $centos_mirror,
        repo_source_hash  => {
          'delorean.repo'      => $delorean_repo,
          'delorean-deps.repo' => $delorean_deps_repo,
        },
        repo_replace      => false,
        update_packages   => true,
      }

      yumrepo { 'crb':
        enabled => true,
      }
    }
    default: {
      fail("Unsupported osfamily (${facts['os']['family']})")
    }
  }
}
