class openstack_integration::zaqar {

  include ::openstack_integration::config

  class { '::zaqar::keystone::auth':
    password => 'a_big_secret',
  }
  # TODO(zhongshengping): temporarily added this package
  if $::osfamily == 'Debian' {
    package { 'python-pymongo':
      ensure => present,
    }
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
  # run a second instance using websockets, the Debian system does
  # not support the use of services to run a second instance.
  if $::osfamily == 'RedHat' {
    zaqar::server_instance{ '1':
      transport => 'websocket'
    }
  }

}
