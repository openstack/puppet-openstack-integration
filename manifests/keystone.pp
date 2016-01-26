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
class openstack_integration::keystone (
  $default_domain      = undef,
  $using_domain_config = false,
) {

  class { '::keystone::client': }
  class { '::keystone::cron::token_flush': }
  class { '::keystone::db::mysql':
    password => 'keystone',
  }
  class { '::keystone':
    verbose             => true,
    debug               => true,
    database_connection => 'mysql+pymysql://keystone:keystone@127.0.0.1/keystone',
    admin_token         => 'admin_token',
    enabled             => true,
    service_name        => 'httpd',
    default_domain      => $default_domain,
    using_domain_config => $using_domain_config,
  }
  include ::apache
  class { '::keystone::wsgi::apache':
    ssl     => false,
    workers => 2,
  }
  class { '::keystone::roles::admin':
    email    => 'test@example.tld',
    password => 'a_big_secret',
  }
  class { '::keystone::endpoint':
    default_domain => 'admin',
  }

}
