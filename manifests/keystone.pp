# Configure the Keystone service
#
# [*default_domain*]
#   (optional) Define the default domain id.
#   Set to 'undef' for 'Default' domain.
#   Default to undef.
#
# [*using_domain_config*]
#   (optional) Eases the use of the keystone_domain_config resource type.
#   It ensures that a directory for holding the domain configuration is present
#   and the associated configuration in keystone.conf is set up right.
#   Defaults to false
#
# [*token_expiration*]
#   (optional) Define the token expiration to use.
#   Default to '600'.
#

class openstack_integration::keystone (
  $default_domain      = undef,
  $using_domain_config = false,
  $token_expiration    = '600',
) {

  include openstack_integration::config
  include openstack_integration::params

  openstack_integration::mq_user { 'keystone':
    password => 'an_even_bigger_secret',
    before   => Anchor['keystone::service::begin'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'keystone':
      notify  => Service['httpd'],
      require => Anchor['keystone::install::end'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { 'keystone::cron::fernet_rotate':
    hour   => '*',
    minute => '*/30',
  }
  class { 'keystone::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'keystone',
    host     => $::openstack_integration::config::host,
  }
  class { 'keystone::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'keystone',
      'password' => 'keystone',
      'database' => 'keystone',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'keystone::logging':
    debug => true,
  }
  class { 'keystone::cache':
    backend          => $::openstack_integration::config::cache_driver,
    enabled          => true,
    memcache_servers => $::openstack_integration::config::memcache_servers,
    redis_server     => $::openstack_integration::config::redis_server,
    redis_password   => 'a_big_secret',
    redis_sentinels  => $::openstack_integration::config::redis_sentinel_server,
    tls_enabled      => $::openstack_integration::config::cache_tls_enabled,
  }
  class { 'keystone':
    enabled                    => true,
    service_name               => 'httpd',
    default_domain             => $default_domain,
    using_domain_config        => $using_domain_config,
    public_endpoint            => $::openstack_integration::config::keystone_auth_uri,
    manage_policyrcd           => true,
    token_expiration           => $token_expiration,
    default_transport_url      => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'keystone',
      'password'  => 'an_even_bigger_secret',
    }),
    notification_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_notify_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_notify_port,
      'username'  => 'keystone',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
  }
  class { 'keystone::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/keystone/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'keystone::bootstrap':
    password   => 'a_big_secret',
    email      => 'test@example.tld',
    public_url => $::openstack_integration::config::keystone_auth_uri,
    admin_url  => $::openstack_integration::config::keystone_admin_uri,
  }

  keystone_tenant { 'openstack':
    ensure  => present,
    enabled => true,
  }
  keystone_user_role { "${::keystone::bootstrap::username}@openstack":
    ensure => present,
    roles  => [$::keystone::bootstrap::role_name],
  }

  keystone_user { 'demo':
    ensure   => present,
    enabled  => true,
    password => 'secrete'
  }
  keystone_tenant { 'demo':
    ensure  => present,
    enabled => true,
  }
  keystone_user_role { 'demo@demo':
    ensure => 'present',
    roles  => ['member'],
  }

  # We need tempest users to have the creator role to be able to store
  # secrets in barbican.  We do this by adding the creator role to the
  # tempest_roles list in tempest.conf.
  keystone_role { 'creator':
    ensure => present,
  }
}
