class openstack_integration {

  Exec { logoutput => 'on_failure' }

  if $::osfamily == 'RedHat' {
    package { 'openstack-selinux':
      # TODO(aschultz): remove this when openstack-selinux is updated BZ#1402926
      ensure => '0.7.4-2.el7'
    }
    package { 'qemu-kvm-ev':
      # TODO(zhongshengping): remove this when the dependency problem of qemu-kvm-ev is resolved
      ensure => '2.3.0-31.0.el7_2.21.1'
    }
    # Some packages provided by RDO are virtual
    # allow_virtual is false in Puppet 3 and will be true
    # in Puppet 4. So let's set it to True.
    # We still support Puppet 3 until distros ship Puppet 4 by default.
    Package<| tag == 'openstack' |> { allow_virtual => true }
  }
}
