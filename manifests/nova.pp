# Configure the Nova service
#
# [*libvirt_rbd*]
#   (optional) Boolean to configure or not Nova
#   to use Libvirt RBD backend.
#   Defaults to false.
#
# [*libvirt_virt_type*]
#   (optional) Libvirt domain type. Options are: kvm, lxc, qemu, uml, xen
#   Defaults to 'qemu'
#
# [*libvirt_cpu_mode*]
#   (optional) The libvirt CPU mode to configure.
#   Possible values include custom, host-model, none, host-passthrough.
#   Defaults to 'none'
#
# [*modular_libvirt*]
#   (optional) Use modular libvirt daemons instead of the monolithic libvirtd
#   deamon
#   Defaults to false
#
# [*volume_encryption*]
#   (optional) Boolean to configure or not volume encryption
#   Defaults to false.
#
# [*notification_topics*]
#   (optional) AMQP topic used for OpenStack notifications
#   Defaults to $facts['os_service_default'].
#
# [*cinder_enabled*]
#   (optional) Boolean to configure or not cinder options.
#   Defaults to false.
#
class openstack_integration::nova (
  $libvirt_rbd         = false,
  $libvirt_virt_type   = 'qemu',
  $libvirt_cpu_mode    = 'none',
  $modular_libvirt     = false,
  $volume_encryption   = false,
  $notification_topics = $facts['os_service_default'],
  $cinder_enabled      = false,
) {

  include openstack_integration::config
  include openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'nova':
      notify  => Service['httpd'],
      require => Package['nova-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  $default_transport_url = os_transport_url({
    'transport' => $::openstack_integration::config::messaging_default_proto,
    'host'      => $::openstack_integration::config::host,
    'port'      => $::openstack_integration::config::messaging_default_port,
    'username'  => 'nova',
    'password'  => 'an_even_bigger_secret',
  })

  $notification_transport_url = os_transport_url({
    'transport' => $::openstack_integration::config::messaging_notify_proto,
    'host'      => $::openstack_integration::config::host,
    'port'      => $::openstack_integration::config::messaging_notify_port,
    'username'  => 'nova',
    'password'  => 'an_even_bigger_secret',
  })

  openstack_integration::mq_user { 'nova':
    password => 'an_even_bigger_secret',
    before   => Anchor['nova::service::begin'],
  }

  class { 'nova::db::mysql':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'nova',
    host     => $::openstack_integration::config::host,
  }
  class { 'nova::db::mysql_api':
    charset  => $::openstack_integration::params::mysql_charset,
    collate  => $::openstack_integration::params::mysql_collate,
    password => 'nova',
    host     => $::openstack_integration::config::host,
  }
  include nova::cell_v2::simple_setup

  # NOTE(aschultz): workaround for race condition for discover_hosts being run
  # prior to the compute being registered
  exec { 'wait-for-compute-registration':
    path        => ['/bin', '/usr/bin'],
    command     => 'sleep 30',
    refreshonly => true,
    notify      => Class['nova::cell_v2::discover_hosts'],
    subscribe   => Anchor['nova::service::end'],
  }

  class { 'nova::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8774/v2.1",
    internal_url => "${::openstack_integration::config::base_url}:8774/v2.1",
    admin_url    => "${::openstack_integration::config::base_url}:8774/v2.1",
    roles        => ['admin', 'service'],
    password     => 'a_big_secret',
  }
  class { 'nova::keystone::authtoken':
    password                     => 'a_big_secret',
    user_domain_name             => 'Default',
    project_domain_name          => 'Default',
    auth_url                     => $::openstack_integration::config::keystone_admin_uri,
    www_authenticate_uri         => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers            => $::openstack_integration::config::memcached_servers,
    service_token_roles_required => true,
  }
  class { 'nova::keystone::service_user':
    send_service_user_token => true,
    password                => 'a_big_secret',
    user_domain_name        => 'Default',
    project_domain_name     => 'Default',
    auth_url                => $::openstack_integration::config::keystone_admin_uri,
  }
  class { 'nova::logging':
    debug => true,
  }
  class { 'nova::db':
    database_connection     => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'nova',
      'password' => 'nova',
      'database' => 'nova',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
    api_database_connection => os_database_connection({
      'dialect'  => 'mysql+pymysql',
      'host'     => $::openstack_integration::config::ip_for_url,
      'username' => 'nova_api',
      'password' => 'nova',
      'database' => 'nova_api',
      'charset'  => 'utf8',
      'extra'    => $::openstack_integration::config::db_extra,
    }),
  }
  class { 'nova':
    default_transport_url      => $default_transport_url,
    notification_transport_url => $notification_transport_url,
    rabbit_use_ssl             => $::openstack_integration::config::ssl,
    amqp_sasl_mechanisms       => 'PLAIN',
    notification_driver        => 'messagingv2',
    notify_on_state_change     => 'vm_and_task_state',
    notification_topics        => $notification_topics,
  }
  class { 'nova::api':
    api_bind_address           => $::openstack_integration::config::host,
    sync_db                    => false,
    sync_db_api                => false,
    service_name               => 'httpd',
    nova_metadata_wsgi_enabled => true,
  }
  class { 'nova::db::sync':
    extra_params    => '--debug',
    db_sync_timeout => 600,
  }
  class { 'nova::db::sync_api':
    extra_params    => '--debug',
    db_sync_timeout => 600,
  }
  class { 'nova::metadata':
    neutron_metadata_proxy_shared_secret => 'a_big_secret',
  }
  include apache
  class { 'nova::wsgi::apache_api':
    bind_host => $::openstack_integration::config::host,
    ssl_key   => "/etc/nova/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    ssl       => $::openstack_integration::config::ssl,
    workers   => 2,
  }
  class { 'nova::wsgi::apache_metadata':
    bind_host => $::openstack_integration::config::host,
    ssl_key   => "/etc/nova/ssl/private/${facts['networking']['fqdn']}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    ssl       => $::openstack_integration::config::ssl,
    workers   => 2,
  }
  class { 'nova::placement':
    auth_url => $::openstack_integration::config::keystone_admin_uri,
    password => 'a_big_secret',
  }
  class { 'nova::client': }
  class { 'nova::conductor':
    workers => 2,
  }
  class { 'nova::cron::archive_deleted_rows': }
  if $volume_encryption {
    class { 'nova::key_manager':
      backend => 'castellan.key_manager.barbican_key_manager.BarbicanKeyManager'
    }
    class { 'nova::key_manager::barbican':
      auth_endpoint     => "${::openstack_integration::config::keystone_auth_uri}/v3",
      barbican_endpoint => "${::openstack_integration::config::base_url}:9311"
    }
    class { 'nova::key_manager::barbican::service_user':
      password            => 'a_big_secret',
      user_domain_name    => 'Default',
      project_domain_name => 'Default',
      auth_url            => $::openstack_integration::config::keystone_admin_uri,
    }
  }
  class { 'nova::compute':
    vnc_enabled                 => true,
    instance_usage_audit        => true,
    instance_usage_audit_period => 'hour',
  }

  # NOTE(tkajinam): In Ubuntu, libvirtd-tcp.socket fails to start because of
  #                 libvirtd.service running, though we stop the service in
  #                 puppet-nova. Until we fix the failure, use ssh transport
  #                 which does not require socket services.
  $migration_transport = $facts['os']['family'] ? {
    'Debian' => 'ssh',
    default  => 'tcp'
  }
  class { 'nova::migration::libvirt':
    transport       => $migration_transport,
    listen_address  => $::openstack_integration::config::host,
    modular_libvirt => $modular_libvirt,
  }

  $images_type = $libvirt_rbd ? {
    true  => 'rbd',
    false => $facts['os_service_default']
  }
  class { 'nova::compute::libvirt':
    virt_type               => $libvirt_virt_type,
    cpu_mode                => $libvirt_cpu_mode,
    images_type             => $images_type,
    manage_libvirt_services => false,
  }
  class { 'nova::compute::libvirt::services':
    modular_libvirt => $modular_libvirt,
  }
  class { 'nova::compute::libvirt::networks': }
  if $libvirt_rbd {
    class { 'nova::compute::rbd':
      libvirt_rbd_user        => 'openstack',
      libvirt_rbd_secret_uuid => '7200aea0-2ddd-4a32-aa2a-d49f66ab554c',
      libvirt_rbd_secret_key  => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
      libvirt_images_rbd_pool => 'nova',
      rbd_keyring             => 'client.openstack',
      # ceph packaging is already managed by puppet-ceph
      manage_ceph_client      => false,
    }
    # make sure ceph pool exists before running nova-compute
    Exec['create-nova'] -> Service['nova-compute']
  } else {
    include openstacklib::iscsid
    Service['iscsid'] -> Service['nova-compute']
  }
  class { 'nova::scheduler':
    workers => 2,
  }
  class { 'nova::scheduler::filter': }
  class { 'nova::vncproxy':
    host => $::openstack_integration::config::host
  }

  class { 'nova::network::neutron':
    auth_url              => "${::openstack_integration::config::keystone_admin_uri}/v3",
    password              => 'a_big_secret',
    default_floating_pool => 'public',
  }
  if $cinder_enabled {
    class { 'nova::cinder':
      auth_url  => $::openstack_integration::config::keystone_admin_uri,
      password  => 'a_big_secret',
      auth_type => 'password',
    }
  }

  Keystone_endpoint <||> -> Service['nova-compute']
  Keystone_service <||> -> Service['nova-compute']

  Keystone_endpoint <||> -> Service['nova-conductor']
  Keystone_service <||> -> Service['nova-conductor']
  Keystone_endpoint <||> -> Service['nova-scheduler']
  Keystone_service <||> -> Service['nova-scheduler']
}
