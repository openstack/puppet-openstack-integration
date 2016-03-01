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
  } else {
    $rabbit_port = '5672'
  }

  if $ipv6 {
    $rabbit_host = '[::1]'
    $rabbit_env = {
      'RABBITMQ_NODE_IP_ADDRESS'   => '::1',
      'RABBITMQ_SERVER_START_ARGS' => '"-proto_dist inet6_tcp"',
    }
  } else {
    $rabbit_host = '127.0.0.1'
    $rabbit_env = {}
  }

}
