class openstack_integration::apache {

  include openstack_integration::params
  include openstack_integration::config

  if ($::os['family'] == 'Debian') {
    $wsgi_mod_package = 'libapache2-mod-wsgi-py3'
    $wsgi_mod_lib     = 'mod_wsgi.so'
  }
  elsif ($::os['name'] == 'Fedora') or
    ($::os['family'] == 'RedHat' and Integer.new($::os['release']['major']) > 7) {
    $wsgi_mod_package = 'python3-mod_wsgi'
    $wsgi_mod_lib     = 'mod_wsgi_python3.so'
  }
  if ($::os['family'] == 'Debian') or ($::os['name'] == 'Fedora') or
    ($::os['family'] == 'RedHat' and Integer.new($::os['release']['major']) > 7) {
    include apache::params
    class { 'apache':
      mod_packages => merge($::apache::params::mod_packages, {
        'wsgi' => $wsgi_mod_package,
      }),
      mod_libs     => merge($::apache::params::mod_libs, {
        'wsgi' => $wsgi_mod_lib,
      })
    }
  }
}
