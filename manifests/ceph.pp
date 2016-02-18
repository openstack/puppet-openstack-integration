class openstack_integration::ceph {

  class { '::ceph::profile::params':
    fsid                      => '7200aea0-2ddd-4a32-aa2a-d49f66ab554c',
    authentication_type       => 'cephx',
    mon_host                  => '127.0.0.1',
    mon_initial_members       => $::hostname,
    osd_pool_default_size     => '1',
    osd_pool_default_min_size => '1',
    mon_key                   => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
    client_keys               => {
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
        'cap_osd' => 'allow class-read object_prefix rbd_children, allow rwx pool=cinder, allow rwx pool=nova, allow rwx pool=glance',
      },
    },
    osds                      => {
      '/srv/data' => {},
    },
  }

  $ceph_pools = ['glance', 'nova', 'cinder']
  ceph::pool { $ceph_pools: }

  class { '::ceph::profile::mon': }
  class { '::ceph::profile::osd': }

  # Extra Ceph configuration to increase performances
  $ceph_extra_config = {
    'client/rbd_default_features' => { value => '15' },
  }
  class { '::ceph::conf':
    args => $ceph_extra_config,
  }
}
