# Configures the BIND service for use with Designate's BIND backend
#

class openstack_integration::bind {

  include openstack_integration::config
  include openstack_integration::params

  $bind_host = $openstack_integration::config::host

  $listen_on = $openstack_integration::config::ipv6 ? {
    true    => 'none',
    default => $bind_host,
  }
  $listen_on_v6 = $openstack_integration::config::ipv6 ? {
    true    => $bind_host,
    default => 'none',
  }

  # NOTE (dmsimard): listen_on_v6 is false and overridden due to extended port
  # configuration in additional_options
  class { 'dns':
    recursion          => 'no',
    allow_recursion    => [],
    listen_on_v6       => false,
    additional_options => {
      'listen-on'         => "port 5322 { ${listen_on}; }",
      'listen-on-v6'      => "port 5322 { ${listen_on_v6}; }",
      'auth-nxdomain'     => 'no',
      'allow-new-zones'   => 'yes',
      # Recommended by Designate docs as a mitigation for potential cache
      # poisoning attacks:
      # https://docs.openstack.org/designate/latest/admin/production-guidelines.html#bind9-mitigation
      'minimal-responses' => 'yes',
    },
    controls           => {
      $bind_host => {
        'port'              => 953,
        'allowed_addresses' => [$bind_host],
        'keys'              => ['rndc-key'],
      },
    },
  }
}
