# Configure the Nova Placement service
#
class openstack_integration::nova_placement {

  include ::openstack_integration::config
  include ::openstack_integration::params

  class { '::nova::db::mysql_placement':
    password => 'nova',
  }

  if ($::os_package_type == 'debian') {
    class { '::nova::keystone::auth_placement':
      public_url   => "${::openstack_integration::config::base_url}:8778",
      internal_url => "${::openstack_integration::config::base_url}:8778",
      admin_url    => "${::openstack_integration::config::base_url}:8778",
      password     => 'a_big_secret',
    }
  } else {
    class { '::nova::keystone::auth_placement':
      public_url   => "${::openstack_integration::config::base_url}:8778/placement",
      internal_url => "${::openstack_integration::config::base_url}:8778/placement",
      admin_url    => "${::openstack_integration::config::base_url}:8778/placement",
      password     => 'a_big_secret',
    }
  }

  if ($::os_package_type != 'debian') {
    class { '::nova::wsgi::apache_placement':
      bind_host => $::openstack_integration::config::ip_for_url,
      api_port  => '8778',
      ssl_key   => "/etc/nova/ssl/private/${::fqdn}.pem",
      ssl_cert  => $::openstack_integration::params::cert_path,
      ssl       => $::openstack_integration::config::ssl,
      workers   => '2',
    }
  }
}
