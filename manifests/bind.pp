# Configures the BIND service for use with Designate's BIND backend
#

class openstack_integration::bind {

  include ::openstack_integration::config
  include ::openstack_integration::params

  # Need some particular options that aren't default in ::dns when using
  # designate with bind9 backend. Set them up.
  $controls = {
    '127.0.0.1' => {
      'port'              => 953,
      'allowed_addresses' => [ '127.0.0.1' ],
      'keys'              => [ 'rndc-key' ]
    },
  }
  # NOTE (dmsimard): listen_on_v6 is false and overridden due to extended port
  # configuration in additional_options
  class { '::dns':
    recursion          => 'no',
    allow_recursion    => [],
    controls           => $controls,
    listen_on_v6       => false,
    additional_options => {
      'listen-on'     => 'port 5322 { any; }',
      'listen-on-v6'  => 'port 5322 { any; }',
      'auth-nxdomain' => 'no',
    }
  }

  # ::dns creates the rndc key but not a rndc.conf.
  # Contribute this in upstream ::dns ?
  file { '/etc/rndc.conf':
    ensure  => present,
    owner   => $::dns::params::owner,
    group   => $::dns::params::group,
    content => template("${module_name}/rndc.conf.erb"),
    require => Package[$dns::params::dns_server_package]
  }
}
