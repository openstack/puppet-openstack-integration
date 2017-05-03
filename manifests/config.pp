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
class openstack_integration::config (
  $ssl  = false,
  $ipv6 = false,
) {

  if $ssl {
    $rabbit_port = '5671'
    $proto       = 'https'
  } else {
    $rabbit_port = '5672'
    $proto       = 'http'
  }

  if $ipv6 {
    $host       = '::1'
    $rabbit_env = {
      'RABBITMQ_NODE_IP_ADDRESS'   => $host,
      'RABBITMQ_SERVER_START_ARGS' => '"-proto_dist inet6_tcp"',
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
