class openstack_integration::ceph {

  include ::openstack_integration::config

  if $::openstack_integration::config::ipv6 {
    $ms_bind_ipv6 = true
  } else {
    $ms_bind_ipv6 = undef
  }

  class { '::ceph::profile::params':
    fsid                         => '7200aea0-2ddd-4a32-aa2a-d49f66ab554c',
    manage_repo                  => false, # repo already managed in openstack_integration::repo
    ms_bind_ipv6                 => $ms_bind_ipv6,
    authentication_type          => 'cephx',
    mon_host                     => $::openstack_integration::config::ip_for_url,
    mon_initial_members          => $::hostname,
    osd_pool_default_size        => '1',
    osd_pool_default_min_size    => '1',
    mon_key                      => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
    osd_max_object_name_len      => 256,
    osd_max_object_namespace_len => 64,
    client_keys                  => {
      'client.admin'         => {
        'secret'  => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
        'mode'    => '0600',
        'cap_mon' => 'allow *',
        'cap_osd' => 'allow *',
        'cap_mds' => 'allow *',
      },
      'client.bootstrap-osd' => {
        'secret'       => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
        'keyring_path' => '/var/lib/ceph/bootstrap-osd/ceph.keyring',
        'cap_mon'      => 'allow profile bootstrap-osd',
      },
      'client.openstack'     => {
        'secret'  => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
        'mode'    => '0644',
        'cap_mon' => 'allow r',
        'cap_osd' => 'allow class-read object_prefix rbd_children, allow rwx pool=cinder, allow rwx pool=nova, allow rwx pool=glance, allow rwx pool=gnocchi',
      },
    },
    osds                         => {
      '/var/lib/ceph/data' => {},
    },
  }

  $ceph_pools = ['glance', 'nova', 'cinder', 'gnocchi']
  ceph::pool { $ceph_pools: }

  class { '::ceph::profile::mon': }
  class { '::ceph::profile::osd': }

  # Needed until https://review.openstack.org/#/c/283359 lands
  $ceph_migration_config = {
    'client/rbd_default_features'         => { value => '15' },
  }
  ensure_resources(ceph_config, $ceph_migration_config)

  # Extra Ceph configuration to increase performances
  $ceph_extra_config = {
    'global/osd_journal_size'             => { value => '100' },

  }

  class { '::ceph::conf':
    args => $ceph_extra_config,
  }
}
