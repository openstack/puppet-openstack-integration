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
    $rabbit_host = '[::1]'
    $rabbit_env  = {
      'RABBITMQ_NODE_IP_ADDRESS'   => '::1',
      'RABBITMQ_SERVER_START_ARGS' => '"-proto_dist inet6_tcp"',
    }
    $ip_version  = '6'
  } else {
    $rabbit_host = '127.0.0.1'
    $rabbit_env  = {}
    $ip_version  = '4'
  }

  $keystone_auth_uri  = "${proto}://127.0.0.1:5000"
  $keystone_admin_uri = "${proto}://127.0.0.1:35357"

}
