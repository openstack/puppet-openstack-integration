# Configure the Ceph services
#
# [*deploy_rgw*]
#   (optional) Setting flag to enable the deployment of Ceph RadosGW and
#   configure various services to use Swift provided by RGW as a backend.
#   Defaults to false
#
# [*pg_num*]
#   (optional) Number of PGs per pool.
#   Defaults to 16.
#
# [*create_cephfs*]
#   (optional) Flag if CephFS will be created.
#   Defaults to false
#
class openstack_integration::ceph (
  $deploy_rgw    = false,
  $pg_num        = 16,
  $create_cephfs = false,
) {

  include openstack_integration::config

  if $::openstack_integration::config::ipv6 {
    $ms_bind_ipv4 = false
    $ms_bind_ipv6 = true
  } else {
    $ms_bind_ipv4 = true
    $ms_bind_ipv6 = false
  }

  ensure_packages(['lvm2'], {'ensure' => 'present', before  => Exec['lvm_create']})

  exec { 'lvm_create':
    command   => "/bin/true # comment to satisfy puppet syntax requirements
truncate --size=10G /diskimage.img
losetup /dev/loop0 /diskimage.img
pvcreate /dev/loop0
vgcreate ceph_vg /dev/loop0
sleep 5
lvcreate -n lv_data -a y -l 100%FREE ceph_vg
",
    unless    => "/bin/true # comment to satisfy puppet syntax requirements
set -ex
test -b /dev/ceph_vg/lv_data
",
    logoutput => true,
  }

  Exec['lvm_create'] -> Class['Ceph::Osds']

  class { 'ceph::params':
    # Since Quincy, the ceph-volume command is provided by the separate package
    packages => ['ceph', 'ceph-volume']
  }

  class { 'ceph::profile::params':
    fsid                         => '7200aea0-2ddd-4a32-aa2a-d49f66ab554c',
    manage_repo                  => false, # repo already managed in openstack_integration::repo
    ms_bind_ipv4                 => $ms_bind_ipv4,
    ms_bind_ipv6                 => $ms_bind_ipv6,
    authentication_type          => 'cephx',
    mon_host                     => $::openstack_integration::config::ip_for_url,
    mon_initial_members          => $facts['networking']['hostname'],
    osd_pool_default_size        => '1',
    osd_pool_default_min_size    => '1',
    mon_key                      => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
    mgr_key                      => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
    mds_key                      => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
    osd_max_object_name_len      => 256,
    osd_max_object_namespace_len => 64,
    client_keys                  => {
      'client.admin'           => {
        'secret'  => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
        'mode'    => '0600',
        'cap_mon' => 'allow *',
        'cap_osd' => 'allow *',
        'cap_mds' => 'allow *',
      },
      'client.bootstrap-osd'   => {
        'secret'       => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
        'keyring_path' => '/var/lib/ceph/bootstrap-osd/ceph.keyring',
        'cap_mon'      => 'allow profile bootstrap-osd',
      },
      'client.openstack'       => {
        'secret'  => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
        'mode'    => '0644',
        'cap_mon' => 'profile rbd',
        'cap_osd' => 'profile rbd pool=cinder, profile rbd pool=nova, profile rbd pool=glance, profile rbd pool=gnocchi',
      },
      'client.manila'          => {
        'secret'  => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
        'mode'    => '0644',
        'cap_mgr' => 'allow rw',
        'cap_mon' => 'allow r',
      },
      'client.radosgw.gateway' => {
        'user'    => 'ceph',
        'secret'  => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
        'cap_mon' => 'allow rwx',
        'cap_osd' => 'allow rwx',
        'inject'  => true,
      }
    },
    osds                         => {
      'ceph_vg/lv_data' => {},
    },
    # Configure Ceph RadosGW
    # These could be always set in the above call to ceph::profile::params
    frontend_type                => 'beast',
    rgw_frontends                => "beast endpoint=${::openstack_integration::config::ip_for_url}:8080",
    rgw_user                     => 'ceph',
    rgw_keystone_integration     => true,
    rgw_keystone_url             => $::openstack_integration::config::keystone_admin_uri,
    rgw_keystone_admin_domain    => 'Default',
    rgw_keystone_admin_user      => 'rgwuser',
    rgw_keystone_admin_password  => 'secret',
    rgw_keystone_admin_project   => 'services',
    rgw_swift_url                => "http://${::openstack_integration::config::ip_for_url}:8080",
    rgw_swift_public_url         => "http://${::openstack_integration::config::ip_for_url}:8080/swift/v1",
    rgw_swift_admin_url          => "http://${::openstack_integration::config::ip_for_url}:8080/swift/v1",
    rgw_swift_internal_url       => "http://${::openstack_integration::config::ip_for_url}:8080/swift/v1",
    rbd_default_features         => '15',
  }

  $ceph_pools = ['glance', 'nova', 'cinder', 'gnocchi']
  ceph::pool { $ceph_pools:
    pg_num => $pg_num,
  }

  class { 'ceph::profile::mgr': }
  class { 'ceph::profile::mon': }
  class { 'ceph::profile::osd': }

  if $create_cephfs {
    ceph::pool { ['cephfs_data', 'cephfs_metadata']:
      pg_num => $pg_num,
    }
    -> ceph::fs { 'cephfs':
      metadata_pool => 'cephfs_metadata',
      data_pool     => 'cephfs_data',
    }
    ~> exec { 'enable cephfs snapshot':
      command     => 'ceph fs set cephfs allow_new_snaps true',
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
      tag         => 'create-cephfs',
    }
    class { 'ceph::profile::mds': }
  }

  # Extra Ceph configuration to increase performances
  $ceph_extra_config = {
    'global/osd_journal_size' => { value => '100' },
  }

  class { 'ceph::conf':
    args => $ceph_extra_config,
  }

  if $deploy_rgw {
    class { 'ceph::profile::rgw': }
    Service<| tag == 'ceph-radosgw' |> -> Service <| tag == 'glance-service' |>
  }
}
