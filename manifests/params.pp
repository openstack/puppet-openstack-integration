class openstack_integration::params {
  case $facts['os']['family'] {
    'RedHat': {
      $ca_bundle_cert_path = '/etc/ssl/certs/ca-bundle.crt'
      $cert_path           = '/etc/pki/ca-trust/source/anchors/puppet_openstack.pem'
      $update_ca_certs_cmd = '/usr/bin/update-ca-trust extract'
      $mysql_charset       = 'utf8'
      $mysql_collate       = 'utf8_general_ci'
      $mysql_conf_dir      = '/etc/my.cnf.d'
    }
    'Debian': {
      $ca_bundle_cert_path = '/etc/ssl/certs/puppet_openstack.pem'
      $cert_path           = '/usr/local/share/ca-certificates/puppet_openstack.crt'
      $update_ca_certs_cmd = '/usr/sbin/update-ca-certificates -f'
      $mysql_charset       = 'utf8mb3'
      $mysql_collate       = 'utf8mb3_general_ci'
      $mysql_conf_dir      = '/etc/mysql'
    }
    default: {
      fail("Unsupported osfamily: ${facts['os']['family']} operatingsystem")
    }
  }
}
