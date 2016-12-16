class openstack_integration {

  Exec { logoutput => 'on_failure' }

  if $::osfamily == 'RedHat' {
    package { 'openstack-selinux':
        ensure => 'latest'
    }
    # Some packages provided by RDO are virtual
    # allow_virtual is false in Puppet 3 and will be true
    # in Puppet 4. So let's set it to True.
    # We still support Puppet 3 until distros ship Puppet 4 by default.
    Package<| tag == 'openstack' |> { allow_virtual => true }
  }
}
