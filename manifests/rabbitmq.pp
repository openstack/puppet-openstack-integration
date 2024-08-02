class openstack_integration::rabbitmq {

  include openstack_integration::params
  include openstack_integration::config

  if $::openstack_integration::config::ssl {
    file { '/etc/rabbitmq/ssl/private':
      ensure                  => directory,
      owner                   => 'root',
      mode                    => '0755',
      selinux_ignore_defaults => true,
      require                 => Class['rabbitmq::install'],
    }
    openstack_integration::ssl_key { 'rabbitmq':
      key_path => "/etc/rabbitmq/ssl/private/${facts['networking']['fqdn']}.pem",
      require  => File['/etc/rabbitmq/ssl/private'],
      notify   => Service['rabbitmq-server'],
    }
  }

  class { 'rabbitmq':
    package_provider      => $facts['package_provider'],
    delete_guest_user     => true,
    ssl                   => $::openstack_integration::config::ssl,
    ssl_only              => $::openstack_integration::config::ssl,
    # the parameters below are ignored when ssl is false
    ssl_cacert            => $::openstack_integration::params::ca_bundle_cert_path,
    ssl_cert              => $::openstack_integration::params::cert_path,
    ssl_key               => "/etc/rabbitmq/ssl/private/${facts['networking']['fqdn']}.pem",
    environment_variables => {
      'LC_ALL'            => 'en_US.UTF-8',
      'HOSTNAME'          => $::openstack_integration::config::hostname,
      'RABBITMQ_NODENAME' => "rabbit@${::openstack_integration::config::hostname}"
    },
    repos_ensure          => false,
    manage_python         => false,
    # the interface parameter is ignored if ssl_only is true
    interface             => $::openstack_integration::config::host,
    # the ssl_interface parameter is ignored if ssl is false
    ssl_interface         => $::openstack_integration::config::host,
    node_ip_address       => $::openstack_integration::config::host,
    management_ip_address => $::openstack_integration::config::host,
    ipv6                  => $::openstack_integration::config::ipv6,
  }
  rabbitmq_vhost { '/':
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
  }

}
