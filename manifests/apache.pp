class openstack_integration::apache {

  include openstack_integration::params
  include openstack_integration::config

  if ($::os['family'] == 'Debian') {
    include apache::params
    class { 'apache':
      mod_packages => merge($::apache::params::mod_packages, {
        'wsgi' => 'libapache2-mod-wsgi-py3',
      }),
      mod_libs     => merge($::apache::params::mod_libs, {
        'wsgi' => 'mod_wsgi.so',
      })
    }
  }
}
