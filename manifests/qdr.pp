class openstack_integration::qdr {

  include ::openstack_integration::params
  include ::openstack_integration::config

  if $::osfamily == 'Debian' {
    include ::apt
    Class['apt::update'] -> Package<| provider == 'apt' |>
    apt::ppa { 'ppa:qpid/released' : }
    package { 'pyngus':
      ensure   => present,
      provider => 'pip'
    }
  }
  $extra_addresses = [{'prefix'       => 'openstack.org/om/rpc/multicast',
                      'distribution' => 'multicast'},
                      {'prefix'       => 'openstack.org/om/rpc/unicast',
                      'distribution' => 'closest'},
                      {'prefix'       => 'openstack.org/om/rpc/anycast',
                      'distribution' => 'balanced'},
                      {'prefix'       => 'openstack.org/om/notify/multicast',
                      'distribution' => 'multicast'},
                      {'prefix'       => 'openstack.org/om/notify/unicast',
                      'distribution' => 'closest'},
                      {'prefix'       => 'openstack.org/om/notify/anycast',
                      'distribution' => 'balanced'}]
  if $::openstack_integration::config::ssl {
    file { '/etc/qpid-dispatch/ssl/private':
      ensure                  => directory,
      owner                   => 'root',
      mode                    => '0755',
      selinux_ignore_defaults => true,
      before                  => File["/etc/qpid-dispatch/ssl/private/${::fqdn}.pem"],
    }
    openstack_integration::ssl_key { 'qdrouterd':
      key_path => "/etc/qpid-dispatch/ssl/private/${::fqdn}.pem",
      require  => File['/etc/qpid-dispatch/ssl/private'],
      notify   => Service['qdrouterd'],
    }
    class { '::qdr':
      listener_require_ssl   => 'yes',
      listener_ssl_cert_db   => $::openstack_integration::params::ca_bundle_cert_path,
      listener_ssl_cert_file => $::openstack_integration::params::cert_path,
      listener_ssl_key_file  => "/etc/qpid-dispatch/ssl/private/${::fqdn}.pem",
      listener_addr          => $::openstack_integration::config::host,
      listener_port          => $::openstack_integration::config::messaging_default_port,
      listener_sasl_mech     => 'PLAIN',
      listener_auth_peer     => 'yes',
      extra_addresses        => $extra_addresses,
    }
  } else {
    class { '::qdr':
      listener_addr      => $::openstack_integration::config::host,
      listener_port      => $::openstack_integration::config::messaging_default_port,
      listener_sasl_mech => 'PLAIN',
      listener_auth_peer => 'yes',
      extra_addresses    => $extra_addresses,
    }
  }
}
