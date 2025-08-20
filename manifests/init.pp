class openstack_integration {
  Exec { logoutput => 'on_failure' }

  if $facts['os']['family'] == 'RedHat' {
    package { 'openstack-selinux':
      ensure => 'present',
    }
  }
}
