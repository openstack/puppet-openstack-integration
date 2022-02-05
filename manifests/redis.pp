class openstack_integration::redis {
  include openstack_integration::config

  # TODO(tkajinam): Remove this once puppet-redis supports CentOS 9
  case $::osfamily {
    'Debian': {
      $redis_config   = '/etc/redis/redis.conf'
    }
    'RedHat': {
      if versioncmp($::operatingsystemmajrelease, '8') > 0 {
        $redis_config = '/etc/redis/redis.conf'
      } else {
        $redis_config = '/etc/redis.conf'
      }
    }
    default: {
      fail("redis.pp manifest does not support family: ${::osfamily}")
    }
  }

  class { 'redis':
    bind             => $::openstack_integration::config::host,
    config_file      => $redis_config,
    config_file_orig => "${redis_config}.puppet",
    ulimit_managed   => false,
  }
}
