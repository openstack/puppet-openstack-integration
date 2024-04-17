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
#   Defaults to 'rabbit'.
#
# [*notify_backend*]
#   (optional) The oslo.messaging backend to configure for notify.
#   Defaults to 'rabbit'.
#
# [*cache_backend*]
#   (optional) The oslo.cache backend
#   Defaults to 'memcached'.
#
# [*tooz_backend*]
#   (optional) The tooz backend
#   Defaults to 'redis'
#
class openstack_integration::config (
  $ssl            = false,
  $ipv6           = false,
  $rpc_backend    = 'rabbit',
  $notify_backend = 'rabbit',
  $cache_backend  = 'memcached',
  $tooz_backend   = 'redis',
) {

  include openstack_integration::params

  $messaging_default_proto = $rpc_backend
  $messaging_notify_proto  = $notify_backend

  if $ssl {
    $proto = 'https'
    $messaging_default_port = '5671'
    $messaging_notify_port = '5671'
    $db_extra = {
      'ssl_ca' => $::openstack_integration::params::ca_bundle_cert_path,
    }
    $ovn_proto = 'ssl'
  } else {
    $proto = 'http'
    $messaging_default_port = '5672'
    $messaging_notify_port = '5672'
    $db_extra = {}
    $ovn_proto = 'tcp'
  }

  $rabbit_port = $messaging_notify_port

  if $ipv6 {
    $host = '::1'
    $hostname = 'localhost6'
    $ip_version = '6'
    # Note (dmsimard): ipv6 parsing in Swift and keystone_authtoken are
    # different: https://bugs.launchpad.net/swift/+bug/1610064
    $memcached_servers = ["inet6:[${host}]:11211"]
    $memcache_servers = ["[${host}]:11211"]
    $swift_memcached_servers = ["[${host}]:11211"]
  } else {
    $host = '127.0.0.1'
    $hostname = 'localhost'
    $ip_version = '4'
    $memcached_servers = ["${host}:11211"]
    $memcache_servers = $memcached_servers
    $swift_memcached_servers = $memcached_servers
  }

  # in URL, brackets are needed
  $ip_for_url = normalize_ip_for_uri($host)

  $base_url           = "${proto}://${ip_for_url}"
  $keystone_auth_uri  = "${base_url}:5000"
  $keystone_admin_uri = "${base_url}:5000"

  $redis_server = "${ip_for_url}:6379"
  $redis_sentinel_server = "${ip_for_url}:26379"
  $cache_driver = $cache_backend ? {
    'redis'          => 'dogpile.cache.redis',
    'redis_sentinel' => 'dogpile.cache.redis_sentinel',
    default          => 'dogpile.cache.pymemcache'
  }
  $cache_tls_enabled = $cache_backend ? {
    'redis'          => $ssl,
    'redis_sentinel' => $ssl,
    default          => false,
  }

  $redis_url = os_url({
    'scheme'   => 'redis',
    'password' => 'a_big_secret',
    'host'     => $ip_for_url,
    'port'     => '6379',
    'query'    => {
      'ssl' => $ssl,
    }
  })

  $sentinel_url = os_url({
    'scheme'   => 'redis',
    'password' => 'a_big_secret',
    'host'     => $ip_for_url,
    'port'     => '26379',
    'query'    => {
      'sentinel'          => 'mymaster',
      'sentinel_password' => 'a_big_secret',
      'ssl'               => $ssl,
      'sentinel_ssl'      => $ssl,
    }
  })

  $tooz_url = $tooz_backend ? {
    'redis_sentinel' => $sentinel_url,
    default          => $redis_url,
  }

  $ovn_nb_connection = "${ovn_proto}:${ip_for_url}:6641"
  $ovn_sb_connection = "${ovn_proto}:${ip_for_url}:6642"
}
