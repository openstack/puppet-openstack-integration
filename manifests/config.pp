# Configure some common parameters
#
# [*ssl*]
#   (optional) Boolean to enable or not SSL.
#   Defaults to false.
#
# [*ipv6*]
#   (optional) Boolean to enable or not IPv6.
#   Defaults to false.
#
# [*rpc_backend*]
#   (optional) The oslo.messaging backend to configure for rpc.
#   Possible values include rabbit, amqp
#   Defaults to 'rabbit'.
#
# [*notify_backend*]
#   (optional) The oslo.messaging backend to configure for notify.
#   Defaults to 'rabbit'.
#
class openstack_integration::config (
  $ssl            = false,
  $ipv6           = false,
  $rpc_backend    = 'rabbit',
  $notify_backend = 'rabbit',
) {

  $messaging_default_proto = $rpc_backend
  $messaging_notify_proto  = $notify_backend

  if $ssl {
    $proto = 'https'
    if $rpc_backend == 'amqp' {
      $messaging_default_port = '31459'
    } else {
      $messaging_default_port = '5671'
    }
    $messaging_notify_port = '5671'
  } else {
    $proto = 'http'
    if $rpc_backend == 'amqp' {
      $messaging_default_port = '31459'
    } else {
      $messaging_default_port = '5672'
    }
    $messaging_notify_port = '5672'
  }

  $rabbit_port = $messaging_notify_port

  if $ipv6 {
    $host       = '::1'
    if $rpc_backend == 'rabbit' {
      $rabbit_env = {
        'RABBITMQ_NODE_IP_ADDRESS'   => $host,
        'RABBITMQ_SERVER_START_ARGS' => '"-proto_dist inet6_tcp"',
      }
    }
    $ip_version  = '6'
    # Note (dmsimard): ipv6 parsing in Swift and keystone_authtoken are
    # different: https://bugs.launchpad.net/swift/+bug/1610064
    $memcached_servers  = ["inet6:[${host}]:11211"]
    $swift_memcached_servers = ["[${host}]:11211"]
    $tooz_url = "redis://[${host}]:6379"
  } else {
    $host        = '127.0.0.1'
    $rabbit_env  = {}
    $ip_version  = '4'
    $memcached_servers  = ["${host}:11211"]
    $swift_memcached_servers = $memcached_servers
    $tooz_url = "redis://${host}:6379"
  }

  # in URL, brackets are needed
  $ip_for_url = normalize_ip_for_uri($host)

  $base_url           = "${proto}://${ip_for_url}"
  $keystone_auth_uri  = "${base_url}:5000"
  $keystone_admin_uri = "${base_url}:35357"
}
