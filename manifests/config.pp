# Configure some common parameters
#
# [*ssl*]
#   (optional) Boolean to enable or not SSL.
#   Defaults to false.
#
class openstack_integration::config (
  $ssl = false,
) {

  if $ssl {
    $rabbit_port = '5671'
  } else {
    $rabbit_port = '5672'
  }

}
