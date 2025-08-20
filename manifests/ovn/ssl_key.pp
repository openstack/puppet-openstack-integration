#
# [*key_owner*]
#   (optional) Owner of SSL private key
#   Defaults to $name.
#
define openstack_integration::ovn::ssl_key (
  $key_owner = $name,
) {
  ['ovnnb', 'ovnsb'].each |$ovndb| {
    ["${ovndb}-privkey.pem", "${ovndb}-cert.pem"].each |$ovn_ssl_file| {
      file { "/etc/${key_owner}/${ovn_ssl_file}":
        ensure  => file,
        owner   => $key_owner,
        mode    => '0600',
        source  => "/etc/openvswitch/${ovn_ssl_file}",
        require => Vswitch::Pki::Cert[$ovndb],
      }
    }
  }

  file { "/etc/${key_owner}/switchcacert.pem":
    ensure  => file,
    owner   => $key_owner,
    mode    => '0600',
    source  => '/var/lib/openvswitch/pki/switchca/cacert.pem',
    require => Class['vswitch::pki::Cacert'],
  }
}
