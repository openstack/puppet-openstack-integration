# Configure the Horizon service
#
# [*root_url*]
#  (optional) The base URL used to construct horizon web addresses.
#  Defaults to undef
#
# [*cache_backend*]
#  (optional) The django cache backend
#  Defaults to 'memcached'.
#
# [*cinder_backup_enabled*]
#  (optional) Flag to enable cinder-backup panel.
#  Defaults to false
#
# [*heat_enabled*]
#  (optional) Flag to enable heat dashboard
#  Defaults to false.
#
# [*manila_enabled*]
#  (optional) Flag to enable manila dashboard
#  Defaults to false.
#
# [*ironic_enabled*]
#  (optional) Flag to enable ironic dashboard
#  Defaults to false.
#
# [*octavia_enabled*]
#  (optional) Flag to enable octavia dashboard
#  Defaults to false.
#
# [*designate_enabled*]
#  (optional) Flag to enable designate dashboard
#  Defaults to false.
#
class openstack_integration::horizon (
  $root_url              = undef,
  $cache_backend         = 'memcached',
  $cinder_backup_enabled = false,
  $heat_enabled          = false,
  $manila_enabled        = false,
  $ironic_enabled        = false,
  $octavia_enabled       = false,
  $designate_enabled     = false,
) {

  include openstack_integration::config
  include openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'openstack-dashboard':
      key_owner => 'root',
      notify    => Service['httpd'],
      require   => Anchor['horizon::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  $redis_scheme = $::openstack_integration::config::ssl ? {
    true    => 'rediss',
    default => 'redis',
  }
  $redis_url = os_url({
    'scheme'   => $redis_scheme,
    'password' => 'a_big_secret',
    'host'     => $::openstack_integration::config::ip_for_url,
    'port'     => '6379',
  })
  $cache_server_url = $cache_backend ? {
    'redis' => $redis_url,
    default => ["${::openstack_integration::config::ip_for_url}:11211"]
  }

  $django_cache_backend = $cache_backend ? {
    'redis' => 'django.core.cache.backends.redis.RedisCache',
    default => 'django.core.cache.backends.memcached.PyMemcacheCache'
  }

  class { 'horizon':
    secret_key                     => 'big_secret',
    cache_backend                  => $django_cache_backend,
    cache_server_url               => $cache_server_url,
    allowed_hosts                  => $::openstack_integration::config::ip_for_url,
    root_url                       => $root_url,
    listen_ssl                     => $::openstack_integration::config::ssl,
    ssl_redirect                   => $::openstack_integration::config::ssl,
    ssl_cert                       => $::openstack_integration::params::cert_path,
    ssl_key                        => "/etc/openstack-dashboard/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_ca                         => $::openstack_integration::params::ca_bundle_cert_path,
    ssl_verify_client              => 'optional',
    enable_secure_proxy_ssl_header => $::openstack_integration::config::ssl,
    secure_cookies                 => $::openstack_integration::config::ssl,
    wsgi_processes                 => 2,
    keystone_url                   => $::openstack_integration::config::keystone_auth_uri,
    log_level                      => 'DEBUG',
    cinder_options                 => {
      'enable_backup' => $cinder_backup_enabled
    },
  }

  # TODO(tkajinam) Debian/Ubuntu package does not install the policy files
  #                to /etc/openstack-dashboard
  if $facts['os']['family'] == 'RedHat' {
    include horizon::policy
  }

  if $heat_enabled {
    class { 'horizon::dashboards::heat': }
  }
  if $ironic_enabled {
    class { 'horizon::dashboards::ironic': }
  }
  if $octavia_enabled {
    class { 'horizon::dashboards::octavia': }
  }
  if $designate_enabled {
    class { 'horizon::dashboards::designate': }
  }
  if $manila_enabled {
    class { 'horizon::dashboards::manila': }
  }
}
