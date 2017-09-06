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
# [*token_provider*]
#   (optional) Define the token provider to use.
#   Default to 'uuid'.
#
# [*token_expiration*]
#   (optional) Define the token expiration to use.
#   Default to '600'.
#

class openstack_integration::keystone (
  $default_domain      = undef,
  $using_domain_config = false,
  $token_provider      = 'uuid',
  $token_expiration    = '600',
) {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'keystone':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'keystone@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }
  Rabbitmq_user_permissions['keystone@/'] -> Service<| tag == 'keystone-service' |>

  if $::openstack_integration::config::messaging_default_proto == 'amqp' {
    qdr_user { 'keystone':
      password => 'an_even_bigger_secret',
      provider => 'sasl',
      require  => Class['::qdr'],
    }
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'keystone':
      notify  => Service['httpd'],
      require => Package['keystone'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  if $token_provider == 'fernet' {
    $enable_fernet_setup = true
    class { '::keystone::cron::fernet_rotate':
      hour   => '*',
      minute => '*/5',
    }
  } else {
    $enable_fernet_setup = false
  }

  # Keystone credential setup is not packaged in UCA yet.
  # It should be done when Newton is released.
  if $::osfamily == 'RedHat' {
    $enable_credential_setup = true
  } else {
    $enable_credential_setup = false
  }

  class { '::keystone::client': }
  class { '::keystone::cron::token_flush': }
  class { '::keystone::db::mysql':
    password => 'keystone',
  }
  class { '::keystone':
    debug                      => true,
    database_connection        => 'mysql+pymysql://keystone:keystone@127.0.0.1/keystone',
    admin_token                => 'a_big_token',
    admin_password             => 'a_big_secret',
    enabled                    => true,
    service_name               => 'httpd',
    default_domain             => $default_domain,
    using_domain_config        => $using_domain_config,
    enable_ssl                 => $::openstack_integration::config::ssl,
    public_bind_host           => $::openstack_integration::config::host,
    admin_bind_host            => $::openstack_integration::config::host,
    manage_policyrcd           => true,
    token_provider             => $token_provider,
    enable_fernet_setup        => $enable_fernet_setup,
    enable_credential_setup    => $enable_credential_setup,
    fernet_max_active_keys     => '4',
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
  class { '::keystone::messaging::amqp':
    amqp_sasl_mechanisms => 'PLAIN',
  }
  include ::apache
  class { '::keystone::wsgi::apache':
    bind_host       => $::openstack_integration::config::ip_for_url,
    admin_bind_host => $::openstack_integration::config::ip_for_url,
    ssl             => $::openstack_integration::config::ssl,
    ssl_key         => "/etc/keystone/ssl/private/${::fqdn}.pem",
    ssl_cert        => $::openstack_integration::params::cert_path,
    workers         => 2,
  }
  # Workaround to purge Keystone vhost that is provided & activated by default with running
  # Canonical packaging (called 'keystone').
  if ($::operatingsystem == 'Ubuntu') and (versioncmp($::operatingsystemmajrelease, '16') >= 0) {
    ensure_resource('file', '/etc/apache2/sites-available/keystone.conf', {
      'ensure'  => 'absent',
    })
    ensure_resource('file', '/etc/apache2/sites-enabled/keystone.conf', {
      'ensure'  => 'absent',
    })

    Package['keystone'] -> File['/etc/apache2/sites-available/keystone.conf']
    -> File['/etc/apache2/sites-enabled/keystone.conf'] ~> Anchor['keystone::install::end']
  }
  class { '::keystone::roles::admin':
    email    => 'test@example.tld',
    password => 'a_big_secret',
  }
  class { '::keystone::endpoint':
    default_domain => $default_domain,
    public_url     => $::openstack_integration::config::keystone_auth_uri,
    admin_url      => $::openstack_integration::config::keystone_admin_uri,
    version        => '',
  }
  class { '::keystone::disable_admin_token_auth': }

  class { '::openstack_extras::auth_file':
    password       => 'a_big_secret',
    project_domain => 'default',
    user_domain    => 'default',
    auth_url       => "${::openstack_integration::config::keystone_auth_uri}/v3/",
  }

  # We need tempest users to have the creator role to be able to store
  # secrets in barbican.  We do this by adding the creator role to the
  # tempest_roles list in tempest.conf.
  # We also need the Member role for some swift container tests.
  # Ordinarily tempest code in dynamic_creds.py would create
  # this role and assign users to it.  This code is not executed, however,
  # when tempest_roles is defined.  Therefore we need to make sure this
  # role is created here, and added to tempest_roles.
  keystone_role { 'creator':
    ensure => present,
  }
  keystone_role { 'Member':
    ensure => present,
  }
}
