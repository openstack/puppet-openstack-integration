# Configure the Sahara service
#
# [*integration_enable*]
#   (optional) Boolean to run integration tests.
#   Defaults to true.
#
class openstack_integration::sahara (
  $integration_enable = true,
){

  include openstack_integration::config
  include openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'sahara':
      notify  => Service['httpd'],
      require => Package['sahara-api'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  openstack_integration::mq_user { 'sahara':
    password => 'an_even_bigger_secret',
    before   => Anchor['sahara::service::begin'],
  }

  class { 'sahara::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'sahara',
    host     => $::openstack_integration::config::host,
  }

  class { 'sahara::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8386",
    internal_url => "${::openstack_integration::config::base_url}:8386",
    admin_url    => "${::openstack_integration::config::base_url}:8386",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'sahara::logging':
    debug => true,
  }
  class { 'sahara::db':
    database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'sahara',
      'password' => 'sahara',
      'database' => 'sahara',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'sahara':
    host                  => $::openstack_integration::config::host,
    default_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'sahara',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
  }
  class { 'sahara::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'sahara::service::api':
    service_name => 'httpd',
  }
  class { 'sahara::wsgi::apache':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/sahara/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }
  class { 'sahara::service::engine': }
  class { 'sahara::client': }
  class { 'sahara::notify': }

  if $integration_enable {
    # create simple sahara templates
    sahara_node_group_template { 'master':
      ensure         => present,
      plugin         => 'vanilla',
      plugin_version => '2.7.1',
      flavor         => 'm1.micro',
      node_processes => [ 'namenode', 'resourcemanager' ],
    }

    sahara_node_group_template { 'worker':
      ensure         => present,
      plugin         => 'vanilla',
      plugin_version => '2.7.1',
      flavor         => 'm1.micro',
      node_processes => [ 'datanode', 'nodemanager' ],
    }

    sahara_cluster_template { 'cluster':
      ensure      => present,
      node_groups => [ 'master:1', 'worker:2' ]
    }

    Nova_flavor<||> -> Sahara_node_group_template<||>
    Class['sahara::keystone::auth'] -> Sahara_node_group_template<||>
  }
}
