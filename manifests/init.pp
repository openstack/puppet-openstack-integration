class openstack_integration {

  Exec { logoutput => 'on_failure' }

  if $::osfamily == 'RedHat' {
    package { 'openstack-selinux':
        ensure => 'latest'
    }
    # temporary hack to make sure RabbitMQ does not steal UID
    # of Keystone
    Package<| title == 'keystone' |> -> Package<| title == 'rabbitmq-server' |>

    # Some packages provided by RDO are virtual
    # allow_virtual is false in Puppet 3 and will be true
    # in Puppet 4. So let's set it to True.
    # We still support Puppet 3 until distros ship Puppet 4 by default.
    # Doing it conditionally as we still support Puppet < 3.6
    if versioncmp($::puppetversion, '3.6.0') >= 0 {
        Package<| tag == 'openstack' |> { allow_virtual => true }
    }
  }
}
