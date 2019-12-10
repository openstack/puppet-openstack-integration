class openstack_integration::mysql {

  class { 'mysql::server': }

  # FIXME (amoralej) Required until a new release of mariadb-libs is released by RDO
  # Fedora and CentOS8 do not have mariadb-libs, so changing only for CentOS
  if ($::operatingsystem == 'CentOS') and (versioncmp($::operatingsystemmajrelease, '7') == 0) {
    package { 'mariadb-libs':
      ensure => 'latest'
    }
    Package['mariadb-libs'] -> Class['mysql::server']
    Package['mariadb-libs'] -> Class['mysql::client']
  }

}
