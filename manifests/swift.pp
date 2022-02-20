class openstack_integration::swift {

  include openstack_integration::config

  # Setup logging to /var/log/swift
  # TODO: Move rsyslog implementation to something more generic
  package { 'rsyslog':
    ensure => present,
  }
  service { 'rsyslog':
    ensure  => running,
    enable  => true,
    require => Package['rsyslog'],
    before  => Anchor['swift::service::begin'],
  }

  if ($::operatingsystem == 'Debian') {
    # Ubuntu/Debian requires particular permissions for rsyslog to work
    $log_dir_owner = $::operatingsystem ? {
      'Debian' => 'swift',
      default  => 'syslog'
    }

    file { '/var/log/swift':
      ensure => directory,
      mode   => '0750',
      owner  => $log_dir_owner,
      group  => 'adm'
    }

  } else {
    file { '/var/log/swift':
      ensure => directory,
      mode   => '0755',
    }

    # TODO(tkajinam): Remove this once fixed version of openstack-selinux is
    #                 released.
    #                 https://bugzilla.redhat.com/show_bug.cgi?id=2050636
    file { '/var/cache/swift':
      ensure  => directory,
      owner   => 'swift',
      group   => 'swift',
      mode    => '0755',
      seltype => 'swift_var_cache_t'
    }
    Anchor['swift::install::end']
      -> File['/var/cache/swift']
      -> Anchor['swift::config::begin']
  }

  file { '/etc/rsyslog.d/10-swift.conf':
    ensure  => present,
    source  => "puppet:///modules/${module_name}/rsyslog-swift.conf",
    require => [Package['rsyslog'], File['/var/log/swift']],
    notify  => Service['rsyslog'],
  }

  class { 'swift':
    swift_hash_path_suffix => 'secrete',
  }
  class { 'swift::proxy':
    proxy_local_net_ip => $::openstack_integration::config::host,
    workers            => '2',
    pipeline           => [
  'catch_errors', 'gatekeeper', 'healthcheck', 'proxy-logging', 'cache',
  'listing_formats', 'container_sync', 'bulk', 'tempurl', 'ratelimit',
  'authtoken', 'keystone', 'copy', 'formpost', 'staticweb', 'container_quotas',
  'account_quotas', 'slo', 'dlo', 'versioned_writes', 'symlink',
  'proxy-logging', 'proxy-server'
    ],
    node_timeout       => 30,
  }
  include swift::proxy::catch_errors
  include swift::proxy::gatekeeper
  include swift::proxy::healthcheck
  include swift::proxy::proxy_logging
  # Note (dmsimard): ipv6 parsing in Swift and keystone_authtoken are
  # different: https://bugs.launchpad.net/swift/+bug/1610064
  class { 'swift::proxy::cache':
    memcache_servers => $::openstack_integration::config::swift_memcached_servers
  }
  include swift::proxy::listing_formats
  include swift::proxy::tempurl
  include swift::proxy::ratelimit
  class { 'swift::proxy::authtoken':
    www_authenticate_uri => "${::openstack_integration::config::keystone_auth_uri}/v3",
    auth_url             => "${::openstack_integration::config::keystone_admin_uri}/",
    password             => 'a_big_secret',
  }
  class { 'swift::proxy::keystone':
    operator_roles => ['member', 'admin', 'SwiftOperator']
  }
  include swift::proxy::copy
  include swift::proxy::formpost
  include swift::proxy::staticweb
  include swift::proxy::container_quotas
  include swift::proxy::account_quotas
  include swift::proxy::bulk
  include swift::proxy::container_sync
  include swift::proxy::dlo
  include swift::proxy::slo
  include swift::proxy::symlink
  include swift::proxy::versioned_writes
  class { 'swift::keystone::auth':
    public_url     => "http://${::openstack_integration::config::ip_for_url}:8080/v1/AUTH_%(tenant_id)s",
    admin_url      => "http://${::openstack_integration::config::ip_for_url}:8080",
    internal_url   => "http://${::openstack_integration::config::ip_for_url}:8080/v1/AUTH_%(tenant_id)s",
    password       => 'a_big_secret',
    operator_roles => ['admin', 'SwiftOperator', 'ResellerAdmin'],
  }
  file { '/srv/node':
    ensure  => directory,
    owner   => 'swift',
    group   => 'swift',
    require => Package['swift'],
  }
  # Create 3 directories under /srv/node for 3 devices
  [1, 2, 3].each | $device | {
    file { "/srv/node/${device}":
      ensure  => directory,
      owner   => 'swift',
      group   => 'swift',
      require => File['/srv/node'],
    }
  }
  include swift::ringbuilder
  class { 'swift::storage::all':
    storage_local_net_ip => $::openstack_integration::config::host,
    incoming_chmod       => 'Du=rwx,g=rx,o=rx,Fu=rw,g=r,o=r',
    outgoing_chmod       => 'Du=rwx,g=rx,o=rx,Fu=rw,g=r,o=r',
    mount_check          => false,
  }
  $swift_components = ['account', 'container', 'object']
  swift::storage::filter::recon { $swift_components : }
  swift::storage::filter::healthcheck { $swift_components : }
  class { 'swift::objectexpirer':
    memcache_servers => $::openstack_integration::config::swift_memcached_servers
  }
  # As of mitaka swift-ring-builder requires devices >= replica count
  # Default replica count is 3
  ring_object_device { ["${::openstack_integration::config::ip_for_url}:6000/1", "${::openstack_integration::config::ip_for_url}:6000/2", "${::openstack_integration::config::ip_for_url}:6000/3"]:
    zone   => 1,
    weight => 1,
  }
  ring_container_device { ["${::openstack_integration::config::ip_for_url}:6001/1", "${::openstack_integration::config::ip_for_url}:6001/2", "${::openstack_integration::config::ip_for_url}:6001/3"]:
    zone   => 1,
    weight => 1,
  }
  ring_account_device { ["${::openstack_integration::config::ip_for_url}:6002/1", "${::openstack_integration::config::ip_for_url}:6002/2", "${::openstack_integration::config::ip_for_url}:6002/3"]:
    zone   => 1,
    weight => 1,
  }
}
