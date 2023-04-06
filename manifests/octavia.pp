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
class openstack_integration::octavia (
  $notification_topics = $facts['os_service_default'],
  $provider_driver     = 'amphora',
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
      require => Package['octavia'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']

    if $provider_driver == 'ovn' {
      ['ovnnb', 'ovnsb'].each |$ovndb| {
        ["${ovndb}-privkey.pem", "${ovndb}-cert.pem"].each |$ovn_ssl_file| {
          file { "/etc/octavia/${ovn_ssl_file}":
            ensure  => present,
            owner   => 'octavia',
            mode    => '0600',
            source  => "/etc/openvswitch/${ovn_ssl_file}",
            require => [
              Anchor['octavia::install::end'],
              Vswitch::Pki::Cert[$ovndb]
            ],
            notify  => Anchor['octavia::service::begin'],
          }
        }
      }

      file { '/etc/octavia/switchcacert.pem':
        ensure  => present,
        owner   => 'octavia',
        mode    => '0600',
        source  => '/var/lib/openvswitch/pki/switchca/cacert.pem',
        require => [
          Anchor['octavia::install::end'],
          Class['vswitch::pki::Cacert'],
        ],
        notify  => Anchor['octavia::service::begin'],
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
    amqp_sasl_mechanisms       => 'PLAIN',
    notification_topics        => $notification_topics,
    notification_driver        => 'messagingv2',
  }
  class { 'octavia::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'octavia',
    host     => $::openstack_integration::config::host,
  }
  class { 'octavia::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:9876",
    internal_url => "${::openstack_integration::config::base_url}:9876",
    admin_url    => "${::openstack_integration::config::base_url}:9876",
    password     => 'a_big_secret',
  }
  class { 'octavia::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }

  File { '/etc/octavia/certs':
    ensure => directory,
    owner  => 'octavia',
    group  => 'octavia',
    mode   => '0700',
    tag    => 'octavia-certs',
  }

  [
    'server_ca.cert.pem',
    'server_ca.key.pem',
    'client_ca.cert.pem',
    'client.cert-and-key.pem'
  ].each |String $cert | {
    File { "/etc/octavia/certs/${cert}":
      ensure => present,
      owner  => 'octavia',
      group  => 'octavia',
      mode   => '0700',
      source => "puppet:///modules/${module_name}/octavia-certs/${cert}",
      tag    => 'octavia-certs',
    }
  }
  Anchor['octavia::config::begin'] -> File<| tag == 'octavia-certs' |> -> Anchor['octavia::config::end']

  class { 'octavia::certificates':
    ca_private_key_passphrase => 'not-secure-passphrase',
    ca_certificate            => '/etc/octavia/certs/server_ca.cert.pem',
    ca_private_key            => '/etc/octavia/certs/server_ca.key.pem',
    client_ca                 => '/etc/octavia/certs/client_ca.cert.pem',
    client_cert               => '/etc/octavia/certs/client.cert-and-key.pem',
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
  include apache
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

  class { 'octavia::worker':
  }
  class { 'octavia::health_manager':
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
