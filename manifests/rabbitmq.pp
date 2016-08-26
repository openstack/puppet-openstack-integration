class openstack_integration::rabbitmq {

  include ::openstack_integration::params
  include ::openstack_integration::config

  if $::openstack_integration::config::ssl {
    file { '/etc/rabbitmq/ssl/private':
      ensure                  => directory,
      owner                   => 'root',
      mode                    => '0755',
      selinux_ignore_defaults => true,
      before                  => File["/etc/rabbitmq/ssl/private/${::fqdn}.pem"],
    }
    openstack_integration::ssl_key { 'rabbitmq':
      key_path => "/etc/rabbitmq/ssl/private/${::fqdn}.pem",
      require  => File['/etc/rabbitmq/ssl/private'],
      notify   => Service['rabbitmq-server'],
    }
    class { '::rabbitmq':
      package_provider      => $::package_provider,
      delete_guest_user     => true,
      ssl                   => true,
      ssl_only              => true,
      ssl_cacert            => $::openstack_integration::params::ca_bundle_cert_path,
      ssl_cert              => $::openstack_integration::params::cert_path,
      ssl_key               => "/etc/rabbitmq/ssl/private/${::fqdn}.pem",
      environment_variables => $::openstack_integration::config::rabbit_env,
      repos_ensure          => false,
    }
  } else {
    class { '::rabbitmq':
      package_provider      => $::package_provider,
      delete_guest_user     => true,
      environment_variables => $::openstack_integration::config::rabbit_env,
      repos_ensure          => false,
    }
  }
  rabbitmq_vhost { '/':
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }

}
