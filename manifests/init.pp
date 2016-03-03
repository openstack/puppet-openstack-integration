class openstack_integration {

  Exec { logoutput => 'on_failure' }

  if $::osfamily == 'RedHat' {
    package { 'openstack-selinux':
        ensure => 'latest'
    }
    # temporary hack to make sure RabbitMQ does not steal UID
    # of Keystone
    Package<| title == 'keystone' |> -> Package<| title == 'rabbitmq-server' |>
  }
}
