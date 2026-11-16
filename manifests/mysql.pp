class openstack_integration::mysql {
  include openstack_integration::config
  include openstack_integration::params

  $mysql_conf_dir = $openstack_integration::params::mysql_conf_dir

  if $openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'mysql':
      root_path => $mysql_conf_dir,
      require   => Package['mysql-server'],
      notify    => Service['mysqld'],
    }
  }

  $ssl_opts = $openstack_integration::config::ssl ? {
    true    => {
      'ssl'      => true,
      'ssl-ca'   => $openstack_integration::params::ca_bundle_cert_path,
      'ssl-cert' => "${mysql_conf_dir}/certs/cert.pem",
      'ssl-key'  => "${mysql_conf_dir}/private/key.pem",
    },
    default => {
      'ssl' => false,
    }
  }

  class { 'mysql::server':
    override_options => {
      'mysqld' => stdlib::merge(
        {
          'bind-address' => $openstack_integration::config::host,
        },
        $ssl_opts,
      ),
    },
  }
}
