# Configure the Horizon service
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
class openstack_integration::horizon (
  $heat_enabled    = false,
  $manila_enabled  = false,
  $ironic_enabled  = false,
  $octavia_enabled = false,
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

  class { 'horizon':
    secret_key                     => 'big_secret',
    cache_backend                  => 'django.core.cache.backends.memcached.PyMemcacheCache',
    cache_server_ip                => $::openstack_integration::config::host,
    allowed_hosts                  => $::openstack_integration::config::ip_for_url,
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
  if $manila_enabled {
    class { 'horizon::dashboards::manila': }
  }
}
