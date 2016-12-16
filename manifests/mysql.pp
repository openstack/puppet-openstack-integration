class openstack_integration::mysql {

  class { '::mysql::server': }

  # FIXME (amoralej) Required until a new release of mariadb-libs is released by RDO
  if $::osfamily == 'RedHat' {
    package { 'mariadb-libs':
      ensure => 'latest'
    }
    Package['mariadb-libs'] -> Class['mysql::server']
    Package['mariadb-libs'] -> Class['mysql::client']
  }

}
