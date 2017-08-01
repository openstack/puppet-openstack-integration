class openstack_integration::vitrage {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'vitrage':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'vitrage@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'vitrage':
      notify  => Service['httpd'],
      require => Package['vitrage'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }


  class { '::vitrage':
    default_transport_url => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'vitrage',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    debug                 => true,
    snapshots_interval    => 120,
    types                 => 'nova.host,nova.instance,nova.zone,cinder.volume,neutron.port,neutron.network,doctor'
  }

  # Make sure tempest can read the configuration files
  # default installation has a 640 premission
  -> file { '/etc/vitrage':
    ensure  => directory,
    recurse => true,
    mode    => '0644',
  }

  # Make sure tempest can write to the log directory
  # default installation has a 755 premission
  -> file { '/var/log/vitrage':
    ensure => directory,
    mode   => '0766',
  }

  class { '::vitrage::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8999",
    internal_url => "${::openstack_integration::config::base_url}:8999",
    admin_url    => "${::openstack_integration::config::base_url}:8999",
    password     => 'a_big_secret',
  }
  class { '::vitrage::keystone::authtoken':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }
  class { '::vitrage::api':
    enabled      => true,
    service_name => 'httpd',
  }
  include ::apache
  class { '::vitrage::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/vitrage/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { '::vitrage::auth':
    auth_url      => $::openstack_integration::config::keystone_auth_uri,
    auth_password => 'a_big_secret',
  }
  class { '::vitrage::graph': }
  class { '::vitrage::notifier': }
  class { '::vitrage::client': }

}
