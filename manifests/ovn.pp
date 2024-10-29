# Configure the ovn service
#
class openstack_integration::ovn(
){

  include openstack_integration::config
  include openstack_integration::params

  require openstack_integration::ovs

  if $::openstack_integration::config::ssl {
    class { 'vswitch::pki::cacert': }
    vswitch::pki::cert { ['ovnnb', 'ovnsb', 'ovncontroller']: }

    $ovn_nb_db_ssl_key     = '/etc/openvswitch/ovnnb-privkey.pem'
    $ovn_nb_db_ssl_cert    = '/etc/openvswitch/ovnnb-cert.pem'
    $ovn_nb_db_ssl_ca_cert = '/var/lib/openvswitch/pki/switchca/cacert.pem'
    $ovn_sb_db_ssl_key     = '/etc/openvswitch/ovnsb-privkey.pem'
    $ovn_sb_db_ssl_cert    = '/etc/openvswitch/ovnsb-cert.pem'
    $ovn_sb_db_ssl_ca_cert = '/var/lib/openvswitch/pki/switchca/cacert.pem'

    $ovn_controller_ssl_key     = '/etc/openvswitch/ovncontroller-privkey.pem'
    $ovn_controller_ssl_cert    = '/etc/openvswitch/ovncontroller-cert.pem'
    $ovn_controller_ssl_ca_cert = '/var/lib/openvswitch/pki/switchca/cacert.pem'

    ['ovnnb', 'ovnsb'].each |$ovndb| {
      file { "/etc/openvswitch/${ovndb}-privkey.pem":
        ensure  => present,
        mode    => '0600',
        owner   => 'openvswitch',
        group   => 'openvswitch',
        require => Vswitch::Pki::Cert[$ovndb],
      } ~> Service['northd']
    }

    file { '/etc/openvswitch/ovncontroller-privkey.pem':
      ensure  => present,
      mode    => '0600',
      owner   => 'openvswitch',
      group   => 'openvswitch',
      require => Vswitch::Pki::Cert['ovncontroller'],
    } ~> Service['controller']

  } else {
    $ovn_nb_db_ssl_key     = undef
    $ovn_nb_db_ssl_cert    = undef
    $ovn_nb_db_ssl_ca_cert = undef
    $ovn_sb_db_ssl_key     = undef
    $ovn_sb_db_ssl_cert    = undef
    $ovn_sb_db_ssl_ca_cert = undef

    $ovn_controller_ssl_key     = undef
    $ovn_controller_ssl_cert    = undef
    $ovn_controller_ssl_ca_cert = undef
  }

  $inactivity_probe = $facts['os']['family'] ? {
    'RedHat' => 0,
    default  => 60000,
  }
  class { 'ovn::northd':
    dbs_listen_ip              => $::openstack_integration::config::ip_for_url,
    ovn_nb_db_ssl_key          => $ovn_nb_db_ssl_key,
    ovn_nb_db_ssl_cert         => $ovn_nb_db_ssl_cert,
    ovn_nb_db_ssl_ca_cert      => $ovn_nb_db_ssl_ca_cert,
    ovn_sb_db_ssl_key          => $ovn_sb_db_ssl_key,
    ovn_sb_db_ssl_cert         => $ovn_sb_db_ssl_cert,
    ovn_sb_db_ssl_ca_cert      => $ovn_sb_db_ssl_ca_cert,
    ovn_nb_db_inactivity_probe => $inactivity_probe,
    ovn_sb_db_inactivity_probe => $inactivity_probe,
  }
  class { 'ovn::controller':
    ovn_remote                 => $::openstack_integration::config::ovn_sb_connection,
    ovn_encap_ip               => $::openstack_integration::config::host,
    ovn_bridge_mappings        => ['external:br-ex'],
    ovn_cms_options            => 'enable-chassis-as-gw',
    manage_ovs_bridge          => false,
    ovn_controller_ssl_key     => $ovn_controller_ssl_key,
    ovn_controller_ssl_cert    => $ovn_controller_ssl_cert,
    ovn_controller_ssl_ca_cert => $ovn_controller_ssl_ca_cert,
  }
}
