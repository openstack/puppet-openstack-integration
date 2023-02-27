class openstack_integration::mysql {

  include openstack_integration::config

  class { 'mysql::server':
    override_options => {
      'mysqld' => {
        'bind-address' => $::openstack_integration::config::host,
      },
    },
  }

}
