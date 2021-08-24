class openstack_integration::params {

  case $::osfamily {
    'RedHat': {
      $ca_bundle_cert_path = '/etc/ssl/certs/ca-bundle.crt'
      $cert_path           = '/etc/pki/ca-trust/source/anchors/puppet_openstack.pem'
      $update_ca_certs_cmd = '/usr/bin/update-ca-trust force-enable && /usr/bin/update-ca-trust extract'
      $mysql_charset       = 'utf8'
    }
    'Debian': {
      $ca_bundle_cert_path = '/etc/ssl/certs/puppet_openstack.pem'
      $cert_path           = '/usr/local/share/ca-certificates/puppet_openstack.crt'
      $update_ca_certs_cmd = '/usr/sbin/update-ca-certificates -f'
      if $::operatingsystem == 'Debian' {
        $mysql_charset     = 'utf8'
      } else {
        # TODO(tkajinam): This is to fix the gate quickly. We should revisit
        #                 this later. utf8mb4 would be the preferred option
        $mysql_charset     = 'utf8mb3'
      }
    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} operatingsystem")
    }
  }

}
