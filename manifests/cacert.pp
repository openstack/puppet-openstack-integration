class openstack_integration::cacert {

  include ::openstack_integration::params

  file { $::openstack_integration::params::cert_path:
    ensure                  => present,
    owner                   => 'root',
    group                   => 'root',
    mode                    => '0444',
    source                  => 'puppet:///modules/openstack_integration/puppet_openstack.pem',
    selinux_ignore_defaults => true,
    replace                 => true,
  }
  exec { 'update-ca-certificates':
    command     => $::openstack_integration::params::update_ca_certs_cmd,
    subscribe   => File[$::openstack_integration::params::cert_path],
    refreshonly => true,
  }

}
