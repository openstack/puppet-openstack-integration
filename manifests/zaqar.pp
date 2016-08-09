class openstack_integration::zaqar {

  include ::openstack_integration::config

  # zaqar is not packaged in Ubuntu Cloud Archive
  if $::osfamily == 'RedHat' {
    class { '::zaqar::keystone::auth':
      password => 'a_big_secret',
    }
    $zaqar_mongodb_conn_string = 'mongodb://127.0.0.1:27017'
    class {'::zaqar::management::mongodb':
      uri => $zaqar_mongodb_conn_string
    }
    class {'::zaqar::messaging::mongodb':
      uri => $zaqar_mongodb_conn_string
    }
    class {'::zaqar::keystone::authtoken':
      auth_url => $::openstack_integration::config::keystone_admin_uri,
      auth_uri => $::openstack_integration::config::keystone_auth_uri,
      password => 'a_big_secret',
    }
    class {'::zaqar':
      unreliable => true,
    }
    Mongodb_replset['openstack'] -> Package['zaqar-common']
    include ::zaqar::server
    # run a second instance using websockets
    zaqar::server_instance{ '1':
      transport => 'websocket'
    }
  }

}
