class openstack_integration::mysql {

  class { 'mysql::server':
    override_options => {
      'mysqld' => {
        'ssl-ca'   => undef,
        'ssl-cert' => undef,
        'ssl-key'  => undef,
      },
    },
  }

}
