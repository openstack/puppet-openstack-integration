# Configure the Designate service
#

class openstack_integration::designate {

  include ::openstack_integration::config
  include ::openstack_integration::params
  include ::openstack_integration::bind

  rabbitmq_user { 'designate':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'designate@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::designate::db::mysql':
    password => 'designate',
  }

  class { '::designate':
    rabbit_userid   => 'designate',
    rabbit_password => 'an_even_bigger_secret',
    rabbit_host     => $::openstack_integration::config::ip_for_url,
    rabbit_port     => $::openstack_integration::config::rabbit_port,
    rabbit_use_ssl  => $::openstack_integration::config::ssl,
    debug           => true,
  }

  class { '::designate::db':
    database_connection => 'mysql+pymysql://designate:designate@127.0.0.1/designate?charset=utf8'
  }

  include '::designate::client'

  # TODO: Support SSL
  class { '::designate::keystone::auth':
    password     => 'a_big_secret',
    public_url   => "http://${::openstack_integration::config::ip_for_url}:9001",
    internal_url => "http://${::openstack_integration::config::ip_for_url}:9001",
    admin_url    => "http://${::openstack_integration::config::ip_for_url}:9001",
  }
  class { '::designate::keystone::authtoken':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }

  class { '::designate::api':
    listen           => "${::openstack_integration::config::host}:9001",
    api_base_uri     => "http://${::openstack_integration::config::ip_for_url}:9001",
    auth_strategy    => 'keystone',
    enable_api_v2    => true,
    enable_api_admin => true
  }

  # IPv6 doesn't work for mdns ? https://bugs.launchpad.net/designate/+bug/1501396
  class { '::designate::mdns':
    listen => '127.0.0.1:5354'
  }

  class { '::designate::central':
    backend_driver => 'bind9',
  }

  class { '::designate::pool_manager':
    pool_id => '794ccc2c-d751-44fe-b57f-8894c9f5c842',
  }

  class { '::designate::pool_manager_cache::memcache':
    memcached_servers => $::openstack_integration::config::memcached_servers,
  }

  class { '::designate::backend::bind9':
    rndc_host        => $::openstack_integration::config::host,
    rndc_config_file => '/etc/rndc.conf',
    rndc_key_file    => $::dns::params::rndckeypath,
  }

  # TODO: Implement pools.yaml management in puppet-designate
  file { '/etc/designate/pools.yaml':
    ensure  => present,
    content => template("${module_name}/pools.yaml.erb"),
    require => Package['designate-common'],
  }

  # Validate that designate-central is ready for pool update
  $command = "openstack --os-auth-url ${::openstack_integration::config::keystone_auth_uri} \
--os-project-name services --os-username designate --os-password a_big_secret zone list"
  openstacklib::service_validation { 'designate-central':
    command     => $command,
    timeout     => '15',
    refreshonly => true,
    require     => Service['designate-central']
  }

  exec { 'Update designate pools':
    command     => 'designate-manage pool update --file /etc/designate/pools.yaml',
    path        => '/usr/bin',
    refreshonly => true,
    logoutput   => 'on_failure',
    subscribe   => File['/etc/designate/pools.yaml'],
    require     => Openstacklib::Service_validation['designate-central']
  }
}
