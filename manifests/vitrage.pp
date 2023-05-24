class openstack_integration::vitrage {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'vitrage':
    password => 'an_even_bigger_secret',
    before   => Anchor['vitrage::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'vitrage':
      notify  => Service['httpd'],
      require => Package['vitrage'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { 'vitrage::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'vitrage',
    host     => $::openstack_integration::config::host,
  }

  class { 'vitrage::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'vitrage',
      'password' => 'vitrage',
      'database' => 'vitrage',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }

  class { 'vitrage::db::sync': }

  class { 'vitrage::logging':
    debug => true,
  }

  class { 'vitrage':
    # TODO(ansmith): separate transports when bug/1711716 closed
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'vitrage',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'vitrage',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms       => 'PLAIN',
    snapshots_interval         => 120,
    types                      => 'nova.host,nova.instance,nova.zone,cinder.volume,neutron.port,neutron.network,doctor',
    notification_driver        => 'messagingv2',
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

  class { 'vitrage::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8999",
    internal_url => "${::openstack_integration::config::base_url}:8999",
    admin_url    => "${::openstack_integration::config::base_url}:8999",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'vitrage::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'vitrage::api':
    enabled      => true,
    service_name => 'httpd',
  }
  include apache
  class { 'vitrage::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/vitrage/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'vitrage::service_credentials':
    auth_url => $::openstack_integration::config::keystone_auth_uri,
    password => 'a_big_secret',
  }
  class { 'vitrage::graph': }
  class { 'vitrage::notifier':
    notifiers => ['nova'],
  }
  class { 'vitrage::persistor': }
  class { 'vitrage::coordination':
    backend_url => $::openstack_integration::config::tooz_url,
  }
  class { 'vitrage::client': }

}
