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
      require => Package['keystone'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { 'keystone::client': }
  class { 'keystone::cron::fernet_rotate':
    hour   => '*',
    minute => '*/30',
  }
  class { 'keystone::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    password => 'keystone',
  }
  class { 'keystone::db':
    database_connection => 'mysql+pymysql://keystone:keystone@127.0.0.1/keystone',
  }
  class { 'keystone::logging':
    debug => true,
  }
  include keystone::cache
  class { 'keystone':
    enabled                    => true,
    service_name               => 'httpd',
    default_domain             => $default_domain,
    using_domain_config        => $using_domain_config,
    public_endpoint            => $::openstack_integration::config::keystone_auth_uri,
    manage_policyrcd           => true,
    fernet_key_repository      => '/etc/keystone/fernet-keys/',
    fernet_max_active_keys     => '5',
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
  class { 'keystone::messaging::amqp':
    amqp_sasl_mechanisms => 'PLAIN',
  }
  include apache
  class { 'keystone::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/keystone/ssl/private/${::fqdn}.pem",
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
    ensure  => 'present',
    enabled => true,
  }
  keystone_user_role { "${::keystone::bootstrap::username}@openstack":
    ensure => 'present',
    roles  => [$::keystone::bootstrap::role_name],
  }

  class { 'openstack_extras::auth_file':
    password            => 'a_big_secret',
    project_domain_name => 'Default',
    user_domain_name    => 'Default',
    auth_url            => "${::openstack_integration::config::keystone_auth_uri}/v3/",
  }

  # We need tempest users to have the creator role to be able to store
  # secrets in barbican.  We do this by adding the creator role to the
  # tempest_roles list in tempest.conf.
  # We also need the member role for some swift container tests.
  # Ordinarily tempest code in dynamic_creds.py would create
  # this role and assign users to it.  This code is not executed, however,
  # when tempest_roles is defined.  Therefore we need to make sure this
  # role is created here, and added to tempest_roles.
  keystone_role { 'creator':
    ensure => present,
  }
  keystone_role { 'member':
    ensure => present,
  }
}
