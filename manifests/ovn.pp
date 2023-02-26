# Configure the ovn service
#
class openstack_integration::ovn(
){

  include openstack_integration::config
  include openstack_integration::params

  if $::openstack_integration::config::ssl {
    class { 'vswitch::pki::cacert': }
    vswitch::pki::cert { ['ovnnb', 'ovnsb', 'ovncontroller']: }

    $proto = 'ssl'

    $ovn_nb_db_ssl_key     = '/etc/openvswitch/ovnnb-privkey.pem'
    $ovn_nb_db_ssl_cert    = '/etc/openvswitch/ovnnb-cert.pem'
    $ovn_nb_db_ssl_ca_cert = '/var/lib/openvswitch/pki/switchca/cacert.pem'
    $ovn_sb_db_ssl_key     = '/etc/openvswitch/ovnsb-privkey.pem'
    $ovn_sb_db_ssl_cert    = '/etc/openvswitch/ovnsb-cert.pem'
    $ovn_sb_db_ssl_ca_cert = '/var/lib/openvswitch/pki/switchca/cacert.pem'

    $ovn_controller_ssl_key     = '/etc/openvswitch/ovncontroller-privkey.pem'
    $ovn_controller_ssl_cert    = '/etc/openvswitch/ovncontroller-cert.pem'
    $ovn_controller_ssl_ca_cert = '/var/lib/openvswitch/pki/switchca/cacert.pem'

    # NOTE(tkajinam): ovn-pki generates a private key with 0600, owned by root
    #                 but that does not allow access by ovn/neutron/octavia.
    file { '/etc/openvswitch/ovnnb-privkey.pem':
      ensure    => present,
      mode      => '0644',
      subscribe => Exec['ovs-req-and-sign-cert-ovnnb'],
    }
    file { '/etc/openvswitch/ovnsb-privkey.pem':
      ensure    => present,
      mode      => '0644',
      subscribe => Exec['ovs-req-and-sign-cert-ovnsb'],
    }
    file { '/etc/openvswitch/ovncontroller-privkey.pem':
      ensure    => present,
      mode      => '0644',
      subscribe => Exec['ovs-req-and-sign-cert-ovncontroller'],
    }

    File['/etc/openvswitch/ovnnb-privkey.pem'] -> Service['northd']
    File['/etc/openvswitch/ovnsb-privkey.pem'] -> Service['northd']
    File['/etc/openvswitch/ovncontroller-privkey.pem'] -> Service['controller']

  } else {
    $proto = 'tcp'

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

  $ovn_nb_connection = "${proto}:${::openstack_integration::config::ip_for_url}:6641"
  $ovn_sb_connection = "${proto}:${::openstack_integration::config::ip_for_url}:6642"

  class { 'ovn::northd':
    dbs_listen_ip         => $::openstack_integration::config::ip_for_url,
    ovn_nb_db_ssl_key     => $ovn_nb_db_ssl_key,
    ovn_nb_db_ssl_cert    => $ovn_nb_db_ssl_cert,
    ovn_nb_db_ssl_ca_cert => $ovn_nb_db_ssl_ca_cert,
    ovn_sb_db_ssl_key     => $ovn_sb_db_ssl_key,
    ovn_sb_db_ssl_cert    => $ovn_sb_db_ssl_cert,
    ovn_sb_db_ssl_ca_cert => $ovn_sb_db_ssl_ca_cert,
  }
  class { 'ovn::controller':
    ovn_remote                 => $ovn_sb_connection,
    ovn_encap_ip               => $::openstack_integration::config::host,
    ovn_bridge_mappings        => ['external:br-ex'],
    ovn_cms_options            => 'enable-chassis-as-gw',
    manage_ovs_bridge          => false,
    ovn_controller_ssl_key     => $ovn_controller_ssl_key,
    ovn_controller_ssl_cert    => $ovn_controller_ssl_cert,
    ovn_controller_ssl_ca_cert => $ovn_controller_ssl_ca_cert,
  }
}
