# Configure the RabbitMQ service
#
# [*ssl*]
#   (optional) Boolean to enable or not SSL.
#   Defaults to false.
#
class openstack_integration::rabbitmq (
  $ssl = false,
) {

  include ::openstack_integration::params

  case $::osfamily {
    'Debian': {
      $package_provider = 'apt'
    }
    'RedHat': {
      $package_provider = 'yum'
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }

  if $ssl {
    file { '/etc/rabbitmq/ssl/private':
      ensure                  => directory,
      owner                   => 'root',
      mode                    => '0755',
      selinux_ignore_defaults => true,
      before                  => File["/etc/rabbitmq/ssl/private/${::fqdn}.pem"],
    }
    openstack_integration::ssl_key { 'rabbitmq':
      key_path => "/etc/rabbitmq/ssl/private/${::fqdn}.pem",
      require  => File['/etc/rabbitmq/ssl'],
      notify   => Service['rabbitmq-server'],
    }
    class { '::rabbitmq':
      delete_guest_user => true,
      package_provider  => $package_provider,
      ssl               => true,
      ssl_only          => true,
      ssl_cacert        => $::openstack_integration::params::cacert_path,
      ssl_cert          => $::openstack_integration::params::cert_path,
      ssl_key           => "/etc/rabbitmq/ssl/private/${::fqdn}.pem",
    }
  } else {
    class { '::rabbitmq':
      delete_guest_user => true,
      package_provider  => $package_provider,
    }
  }
  rabbitmq_vhost { '/':
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }

}
