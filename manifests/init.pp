class openstack_integration {

  Exec { logoutput => 'on_failure' }

  if $::osfamily == 'RedHat' {
    package { 'openstack-selinux':
        ensure => 'latest'
    }
  }
}
