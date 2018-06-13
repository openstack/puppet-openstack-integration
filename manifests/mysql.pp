class openstack_integration::mysql {

  class { '::mysql::server': }

  # FIXME (amoralej) Required until a new release of mariadb-libs is released by RDO
  # Fedora do not have mariadb-libs, so changing only for CentOS
  if $::operatingsystem == 'CentOS' {
    package { 'mariadb-libs':
      ensure => 'latest'
    }
    Package['mariadb-libs'] -> Class['mysql::server']
    Package['mariadb-libs'] -> Class['mysql::client']
  }

}
