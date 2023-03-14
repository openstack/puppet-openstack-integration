# Configures the BIND service for use with Designate's BIND backend
#

class openstack_integration::bind {

  include openstack_integration::config
  include openstack_integration::params

  $bind_host = $::openstack_integration::config::host

  $listen_on = $::openstack_integration::config::ipv6 ? {
    true    => 'none',
    default => $bind_host,
  }
  $listen_on_v6 = $::openstack_integration::config::ipv6 ? {
    true    => $bind_host,
    default => 'none',
  }

  # NOTE(tkajinam) Disable config check in Ubuntu due to
  #                https://github.com/theforeman/puppet-dns/issues/227
  if $facts['os']['name'] == 'Ubuntu' {
    $config_check = false
  } else {
    $config_check = true
  }

  # NOTE (dmsimard): listen_on_v6 is false and overridden due to extended port
  # configuration in additional_options
  class { 'dns':
    config_check       => $config_check,
    recursion          => 'no',
    allow_recursion    => [],
    listen_on_v6       => false,
    additional_options => {
      'listen-on'     => "port 5322 { ${listen_on}; }",
      'listen-on-v6'  => "port 5322 { ${listen_on_v6}; }",
      'auth-nxdomain' => 'no',
    },
    controls           => {
      $bind_host => {
        'port'              => 953,
        'allowed_addresses' => [$bind_host],
        'keys'              => ['rndc-key'],
      }
    },
  }

  # ::dns creates the rndc key but not a rndc.conf.
  # Contribute this in upstream ::dns ?
  file { '/etc/rndc.conf':
    ensure  => present,
    owner   => $::dns::params::user,
    group   => $::dns::params::group,
    content => template("${module_name}/rndc.conf.erb"),
    require => Package[$dns::params::dns_server_package]
  }
}
