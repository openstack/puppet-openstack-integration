# Create a message queue user for a service
#
# [*password*]
#   The password for the message queue account
#
# [*admin*]
#   (optional) If the acconut is an admin account
#   Defaults to true
#
# [*vhost*]
#   The virtual host assigned to the user
#   Defaults to /
#
define openstack_integration::mq_user (
  $password,
  $admin = true,
  $vhost = '/',
) {
  include ::openstack_integration::config
  include ::openstack_integration::rabbitmq

  rabbitmq_user { $name:
    admin    => $admin,
    password => $password,
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }

  rabbitmq_user_permissions { "${name}@${vhost}":
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  if $::openstack_integration::config::messaging_default_proto == 'amqp' {
    include ::openstack_integration::qdr

    qdr_user { $name:
      password => $password,
      provider => 'sasl',
      require  => Class['::qdr'],
    }
  }
}