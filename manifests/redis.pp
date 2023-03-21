class openstack_integration::redis {
  include openstack_integration::config

  $port = $openstack_integration::config::ssl ? {
    true    => 0,
    default => 6379
  }
  $tls_port = $openstack_integration::config::ssl ? {
    true    => 6379,
    default => 0
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

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'redis':
      require => Package[$::redis::package_name],
      notify  => Service[$::redis::service_name],
    }
  }
}
