# Configure the Sahara service
#
# [*integration_enable*]
#   (optional) Boolean to run integration tests.
#   Defaults to true.
#
class openstack_integration::sahara (
  $integration_enable = true,
){

  include ::openstack_integration::config
  include ::openstack_integration::params

  openstack_integration::mq_user { 'sahara':
    password => 'an_even_bigger_secret',
    before   => Anchor['sahara::service::begin'],
  }

  class { '::sahara::db::mysql':
    password => 'sahara',
  }
  class { '::sahara::keystone::auth':
    # SSL does not seem to work in Sahara
    # https://bugs.launchpad.net/sahara/+bug/1565082
    public_url   => "http://${::openstack_integration::config::ip_for_url}:8386/v1.1/%(tenant_id)s",
    internal_url => "http://${::openstack_integration::config::ip_for_url}:8386/v1.1/%(tenant_id)s",
    admin_url    => "http://${::openstack_integration::config::ip_for_url}:8386/v1.1/%(tenant_id)s",
    password     => 'a_big_secret',
  }
  class { '::sahara':
    host                  => $::openstack_integration::config::host,
    database_connection   => 'mysql+pymysql://sahara:sahara@127.0.0.1/sahara?charset=utf8',
    default_transport_url => os_transport_url({
      'transport' => $::openstack_integration::config::messaging_default_proto,
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::messaging_default_port,
      'username'  => 'sahara',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms  => 'PLAIN',
    debug                 => true,
  }
  class { '::sahara::keystone::authtoken':
    password             => 'a_big_secret',
    user_domain_name     => 'Default',
    project_domain_name  => 'Default',
    auth_url             => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers    => $::openstack_integration::config::memcached_servers,
  }
  class { '::sahara::service::api':
    api_workers => 2,
  }
  class { '::sahara::service::engine': }
  class { '::sahara::client': }
  class { '::sahara::notify': }

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
    Class['::sahara::keystone::auth'] -> Sahara_node_group_template<||>
    Class['::openstack_extras::auth_file'] -> Sahara_node_group_template<||>
  }
}
