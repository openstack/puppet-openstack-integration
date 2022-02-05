class openstack_integration::redis {
  include openstack_integration::config

  # NOTE(tobias-urdin): Manually manage redis until arioch/puppet-redis support
  # redis 4.x since that is used by Ubuntu Bionic.
  case $::osfamily {
    'Debian': {
      $redis_package_name = 'redis-server'
      $redis_service_name = 'redis-server'
      $redis_config       = '/etc/redis/redis.conf'
    }
    'RedHat': {
      $redis_package_name = 'redis'
      $redis_service_name = 'redis'
      if versioncmp($::operatingsystemmajrelease, '8') > 0 {
        $redis_config       = '/etc/redis/redis.conf'
      } else {
        $redis_config       = '/etc/redis.conf'
      }
    }
    default: {
      fail("redis.pp manifest does not support family: ${::osfamily}")
    }
  }

  # NOTE(tobias-urdin): Manually manage redis until arioch/puppet-redis support
  # redis 4.x since that is used by Ubuntu Bionic.
  package { 'redis':
    ensure => 'present',
    name   => $redis_package_name,
  }

  file_line { 'redis_config':
    ensure  => 'present',
    path    => $redis_config,
    line    => "bind ${::openstack_integration::config::host}",
    match   => '^bind\ ',
    require => Package['redis'],
    notify  => Service['redis'],
  }

  service { 'redis':
    ensure  => 'running',
    name    => $redis_service_name,
    enable  => true,
    require => File_line['redis_config'],
  }
}
