class openstack_integration::redis {
  include openstack_integration::config

  $port = $openstack_integration::config::ssl ? {
    true    => 0,
    default => 6379
  }
  $tls_port = $openstack_integration::config::ssl ? {
    true    => 6379,
    default => undef
  }
  $sentinel_port = $openstack_integration::config::ssl ? {
    true    => 0,
    default => 26379
  }
  $sentinel_tls_port = $openstack_integration::config::ssl ? {
    true    => 26379,
    default => undef
  }

  class { 'redis':
    bind             => $::openstack_integration::config::host,
    port             => $port,
    tls_port         => $tls_port,
    tls_cert_file    => $::openstack_integration::params::cert_path,
    tls_key_file     => "/etc/redis/ssl/private/${facts['networking']['fqdn']}.pem",
    tls_ca_cert_file => $::openstack_integration::params::ca_bundle_cert_path,
    ulimit_managed   => false,
    requirepass      => 'a_big_secret',
  }

  class { 'redis::sentinel':
    auth_pass         => 'a_big_secret',
    redis_host        => $::openstack_integration::config::host,
    redis_port        => 6379,
    requirepass       => 'a_big_secret',
    quorum            => 1,
    sentinel_port     => $sentinel_port,
    sentinel_tls_port => $sentinel_tls_port,
    sentinel_bind     => $::openstack_integration::config::host,
    tls_cert_file     => $::openstack_integration::params::cert_path,
    tls_key_file      => "/etc/redis/ssl/private/${facts['networking']['fqdn']}.pem",
    tls_ca_cert_file  => $::openstack_integration::params::ca_bundle_cert_path,
    tls_replication   => $openstack_integration::config::ssl,
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'redis':
      require => Package[$::redis::package_name],
      notify  => Service[$::redis::service_name],
    }
  }
}
