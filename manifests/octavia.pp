# Configure the octavia service
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
# [*provider_driver*]
#   (optional) Provider driver used in Octavia.
#   Defaults to 'amphora'.
#
# [*jobboard_backend*]
#   (optional) Jobboard backend.
#   Defaults to 'redis'.
#
class openstack_integration::octavia (
  $notification_topics = $facts['os_service_default'],
  $provider_driver     = 'amphora',
  $jobboard_backend    = 'redis',
) {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'octavia':
    password => 'an_even_bigger_secret',
    before   => Anchor['octavia::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'octavia':
      notify  => Service['httpd'],
      require => Anchor['octavia::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']

    if $provider_driver == 'ovn' {
      openstack_integration::ovn::ssl_key { 'octavia':
        notify  => Anchor['octavia::service::begin'],
        require => Anchor['octavia::install::end'],
      }
    }
  }

  class { 'octavia::logging':
    debug => true,
  }
  class { 'octavia::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'octavia',
      'password' => 'octavia',
      'database' => 'octavia',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'octavia':
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'octavia',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'octavia',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
  }
  class { 'octavia::db::mysql':
    charset            => $::openstack_integration::params::mysql_charset,
    collate            => $::openstack_integration::params::mysql_collate,
    password           => 'octavia',
    host               => $::openstack_integration::config::host,
    persistence_dbname => 'octavia_persistence',
  }
  class { 'octavia::db::sync': }
  class { 'octavia::db::sync_persistence': }
  class { 'octavia::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9876",
    internal_url => "${::openstack_integration::config::base_url}:9876",
    admin_url    => "${::openstack_integration::config::base_url}:9876",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'octavia::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'octavia::neutron':
    password => 'a_big_secret',
    auth_url => $::openstack_integration::config::keystone_admin_uri,
  }

  class { 'octavia::certificates':
    ca_private_key_passphrase => 'not-secure-passphrase',
    ca_certificate            => '/etc/octavia/certs/server_ca.cert.pem',
    ca_certificate_data       => file("${module_name}/octavia-certs/server_ca.cert.pem"),
    ca_private_key            => '/etc/octavia/certs/server_ca.key.pem',
    ca_private_key_data       => file("${module_name}/octavia-certs/server_ca.key.pem"),
    client_ca                 => '/etc/octavia/certs/client_ca.cert.pem',
    client_ca_data            => file("${module_name}/octavia-certs/client_ca.cert.pem"),
    client_cert               => '/etc/octavia/certs/client.cert-and-key.pem',
    client_cert_data          => file("${module_name}/octavia-certs/client.cert-and-key.pem"),
  }

  if $provider_driver == 'ovn' {
    # NOTE(tkajinam): Because noop drivers does not work with the ovn provider,
    #                 amphora provider is also enabled. All tests are currently
    #                 executed with amphora provider + noop drivers but we
    #                 might want to revisit this later.
    $enabled_provider_drivers = {
      'amphora' => 'The Octavia Amphora driver.',
      'octavia' => 'Deprecated alias of the Octavia Amphora driver.',
      'ovn'     => 'OVN provider driver.'
    }
    $enabled_provider_agents = 'ovn'

    class { 'octavia::provider::ovn':
      ovn_nb_connection  => $::openstack_integration::config::ovn_nb_connection,
      ovn_nb_private_key => '/etc/octavia/ovnnb-privkey.pem',
      ovn_nb_certificate => '/etc/octavia/ovnnb-cert.pem',
      ovn_nb_ca_cert     => '/etc/octavia/switchcacert.pem',
      ovn_sb_connection  => $::openstack_integration::config::ovn_sb_connection,
      ovn_sb_private_key => '/etc/octavia/ovnsb-privkey.pem',
      ovn_sb_certificate => '/etc/octavia/ovnsb-cert.pem',
      ovn_sb_ca_cert     => '/etc/octavia/switchcacert.pem',
    }
    require openstack_integration::ovn
  } else{
    $enabled_provider_drivers = undef
    $enabled_provider_agents = undef
  }

  class { 'octavia::api':
    enabled                  => true,
    service_name             => 'httpd',
    sync_db                  => true,
    enabled_provider_drivers => $enabled_provider_drivers,
  }
  class { 'octavia::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/octavia/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'octavia::client': }

  class { 'octavia::networking':
  }

  class { 'octavia::controller':
    amp_flavor_id  => '65',
    amphora_driver => 'amphora_noop_driver',
    compute_driver => 'compute_noop_driver',
    image_driver   => 'image_noop_driver',
    network_driver => 'network_noop_driver',
    heartbeat_key  => 'abcdefghijkl',
  }

  $jobboard_redis_sentinel = $jobboard_backend ? {
    'redis_sentinel' => 'mymaster',
    default          => undef
  }
  $jobboard_backend_port = $jobboard_backend ? {
    'redis_sentinel' => 26379,
    default          => 6379,
  }

  class { 'octavia::task_flow':
    max_workers                         => 2,
    persistence_connection              => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'octavia',
      'password' => 'octavia',
      'database' => 'octavia_persistence',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
    jobboard_enabled                    => true,
    jobboard_backend_hosts              => $::openstack_integration::config::host,
    jobboard_backend_port               => $jobboard_backend_port,
    jobboard_backend_password           => 'a_big_secret',
    jobboard_redis_sentinel             => $jobboard_redis_sentinel,
    jobboard_redis_sentinel_password    => 'a_big_secret',
    jobboard_redis_backend_ssl_options  => {
      'ssl' => $::openstack_integration::config::ssl
    },
    jobboard_redis_sentinel_ssl_options => {
      'ssl' => $::openstack_integration::config::ssl
    }
  }

  class { 'octavia::worker':
    workers => 2,
  }
  class { 'octavia::health_manager':
    health_update_threads => 2,
    stats_update_threads  => 2,
  }
  class { 'octavia::housekeeping':
  }
  class { 'octavia::driver_agent':
    enabled_provider_agents => $enabled_provider_agents,
  }
  class { 'octavia::service_auth':
    auth_url => $::openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }
}
