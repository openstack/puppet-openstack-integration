class openstack_integration::mysql {

  include openstack_integration::config
  include openstack_integration::params

  $mysql_conf_dir = $::openstack_integration::params::mysql_conf_dir

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'mysql':
      key_path => "${mysql_conf_dir}/${facts['networking']['fqdn']}.pem",
      require  => Package['mysql-server'],
      notify   => Service['mysqld'],
    }
  }

  class { 'mysql::server':
    override_options => {
      'mysqld' => {
        'bind-address' => $::openstack_integration::config::host,
        'ssl'          => $::openstack_integration::config::ssl,
        'ssl-ca'       => $::openstack_integration::params::ca_bundle_cert_path,
        'ssl-cert'     => $::openstack_integration::params::cert_path,
        'ssl-key'      => "${mysql_conf_dir}/${facts['networking']['fqdn']}.pem",
      },
    },
  }
}
