class openstack_integration::zaqar {

  include ::openstack_integration::config

  class { '::zaqar::db::mysql':
    password => 'zaqar',
  }
  class { '::zaqar::keystone::auth':
    password => 'a_big_secret',
    roles    => ['admin', 'ResellerAdmin'],
  }
  class {'::zaqar::management::sqlalchemy':
    uri => 'mysql+pymysql://zaqar:zaqar@127.0.0.1/zaqar?charset=utf8',
  }
  class {'::zaqar::messaging::swift':
    auth_url => "${::openstack_integration::config::keystone_auth_uri}/v3",
    uri      => 'swift://zaqar:a_big_secret@/services',
  }
  class {'::zaqar::keystone::authtoken':
    auth_url => $::openstack_integration::config::keystone_admin_uri,
    auth_uri => $::openstack_integration::config::keystone_auth_uri,
    password => 'a_big_secret',
  }
  class {'::zaqar':
    unreliable       => true,
    management_store => 'sqlalchemy',
    message_store    => 'swift',
  }
  class {'::zaqar::server':
    service_name => 'httpd',
  }
  include ::apache
  class { '::zaqar::wsgi::apache':
    ssl => false,
  }
  # run a second instance using websockets, the Debian system does
  # not support the use of services to run a second instance.
  if $::osfamily == 'RedHat' {
    zaqar::server_instance{ '1':
      transport => 'websocket'
    }
  }

}
