# Configure the Designate service
#

class openstack_integration::designate {

  include openstack_integration::config
  include openstack_integration::params
  include openstack_integration::bind

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'designate':
      notify  => Service['httpd'],
      require => Package['designate-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  openstack_integration::mq_user { 'designate':
    password => 'an_even_bigger_secret',
    before   => Anchor['designate::service::begin'],
  }

  class { 'designate::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    password => 'designate',
  }
  class { 'designate::logging':
    debug => true,
  }
  class { 'designate':
    default_transport_url => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'designate',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
  }
  class { 'designate::db':
    database_connection => 'mysql+pymysql://designate:designate@127.0.0.1/designate?charset=utf8'
  }

  include 'designate::client'

  class { 'designate::keystone::auth':
    password     => 'a_big_secret',
    public_url   => "${::openstack_integration::config::base_url}:9001",
    internal_url => "${::openstack_integration::config::base_url}:9001",
    admin_url    => "${::openstack_integration::config::base_url}:9001",
  }
  class { 'designate::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }

  class { 'designate::api':
    api_base_uri     => "${::openstack_integration::config::base_url}:9001",
    auth_strategy    => 'keystone',
    enable_api_v2    => true,
    enable_api_admin => true,
    service_name     => 'httpd',
  }
  include apache
  class { 'designate::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl_key   => "/etc/designate/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    ssl       => $::openstack_integration::config::ssl,
    workers   => '2',
  }

  # IPv6 doesn't work for mdns ? https://bugs.launchpad.net/designate/+bug/1501396
  class { 'designate::mdns':
    listen => '127.0.0.1:5354'
  }

  class { 'designate::central': }

  class { 'designate::producer': }

  class { 'designate::worker': }

  class { 'designate::backend::bind9':
    dns_port         => 5322,
    rndc_config_file => '/etc/rndc.conf',
    rndc_key_file    => $::dns::params::rndckeypath,
    manage_pool      => true
  }
}
