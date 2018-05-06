class openstack_integration::redis {
  include ::openstack_integration::config

  # NOTE(tobasco): Manually manage redis until arioch/puppet-redis support
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
      $redis_config       = '/etc/redis.conf'
    }
    default: {
      fail("redis.pp manifest does not support family: ${::osfamily}")
    }
  }

  # due to issues in OpenStack CI with the redis package, we need to disable
  # the service enable flag. The service still starts but the management of
  # the service with systemd errors.
  if ($::os_package_type == 'debian') {
    $service_enable = false
  } else {
    $service_enable = true
  }

  # NOTE(tobasco): Manually manage redis until arioch/puppet-redis support
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
    enable  => $service_enable,
    require => File_line['redis_config'],
  }
}
