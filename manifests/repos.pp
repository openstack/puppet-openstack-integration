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
          include apt
          class { 'openstack_extras::repo::debian::ubuntu':
            release         => 'train',
            package_require => true,
            uca_location    => pick($::uca_mirror_host, 'http://ubuntu-cloud.archive.canonical.com/ubuntu'),
          }
        }
        'debian': {
          include apt
          class { 'openstack_extras::repo::debian::debian':
            release         => 'ussuri',
            package_require => true,
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
      class { 'openstack_extras::repo::redhat::redhat':
        manage_rdo        => false,
        manage_epel       => false,
        centos_mirror_url => $::centos_mirror_host,
        repo_hash         => {
          'master-puppet-passed-ci' => {
            'baseurl'  => pick($::rdo_mirror_host, "https://trunk.rdoproject.org/centos${::os['release']['major']}-master/puppet-passed-ci/"),
            'descr'    => 'master puppet-passed-ci',
            'gpgcheck' => 'no',
            'priority' => 1,
          },
          'master-delorean-deps'    => {
            'baseurl'  => pick($::deps_mirror_host, "https://trunk.rdoproject.org/centos${::os['release']['major']}-master/deps/latest/"),
            'descr'    => 'master delorean-deps',
            'gpgcheck' => 'no',
          },
        },
      }
      # NOTE(tobias-urdin): Mimic was never released by Storage SIG to official mirros.
      $ceph_mirror_fallback = $ceph_version_real ? {
        'mimic' => "https://trunk.rdoproject.org/centos${::os['release']['major']}/deps/storage/storage${::os['release']['major']}-ceph-mimic/x86_64/",
        default => "${::centos_mirror_host}/centos/${::os['release']['major']}/storage/x86_64/ceph-${ceph_version_real}/"
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
          require => Class['openstack_extras::repo::redhat::redhat'],
        }
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
    package { 'python2-chardet':
      ensure => 'latest',
    }
    Yumrepo<||> -> Package<| title == 'python2-chardet' |>
    # NOTE(tobias-urdin): Install libibverbs to fix an issue where OVS outputs errors
    # that causes the puppet-openvswitch module to fail parsing the output.
    # This issue does not occur in integration testing but only beaker tests since some
    # other package (probably nova) causes this package to be installed, or the yum upgrade
    # part in integration catches it.
    # Reported upstream: https://bugzilla.redhat.com/show_bug.cgi?id=1658141
    package { 'libibverbs':
      ensure => 'present',
    }
  }

  if $::operatingsystem == 'Ubuntu' {
    # TODO(tobias-urdin): Something changed in packages that was installed in puppet-nova
    # on Ubuntu so the rbd and rados python libs are not installed anymore.
    # Need to figure out a good place to add them back in, until then just testing with this.
    ensure_packages(['python3-rados', 'python3-rbd'], {
      'ensure' => 'present',
      'tag'    => 'nova-python3-libs',
    })
    Apt::Source<||> -> Package<| tag == 'nova-python3-libs' |>
  }
}
