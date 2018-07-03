# Configure the Ceph services
#
# [*deploy_rgw*]
#   (optional) Setting flag to enable the deployment
#   of Ceph RadosGW and configure various services
#   to use Swift provided by RGW as a backend.
#   Defaults to false
#
# [*swift_dropin*]
#   (optional) Flag if Ceph RGW will provide swift
#   services for openstack
#
class openstack_integration::ceph (
  $deploy_rgw = false,
  $swift_dropin = false,
) {

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
    mgr_key                      => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
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
        'cap_mon' => 'profile rbd',
        'cap_osd' => 'profile rbd pool=cinder, profile rbd pool=nova, profile rbd pool=glance, profile rbd pool=gnocchi',
      },
    },
    osds                         => {
      '/var/lib/ceph/data' => {},
    },
    # Configure Ceph RadosGW
    # These could be always set in the above call to ceph::profile::params
    frontend_type                => 'civetweb',
    rgw_frontends                => "civetweb port=${::openstack_integration::config::ip_for_url}:8080",
    rgw_user                     => 'ceph',
    rbd_default_features         => '15',
  }

  $ceph_pools = ['glance', 'nova', 'cinder', 'gnocchi']
  ceph::pool { $ceph_pools: }

  class { '::ceph::profile::mgr': }
  class { '::ceph::profile::mon': }
  class { '::ceph::profile::osd': }

  # Extra Ceph configuration to increase performances
  $ceph_extra_config = {
    'global/osd_journal_size'             => { value => '100' },

  }

  class { '::ceph::conf':
    args => $ceph_extra_config,
  }

  if $deploy_rgw {

    ceph::key { 'client.radosgw.gateway':
      user    => 'ceph',
      secret  => 'AQD7kyJQQGoOBhAAqrPAqSopSwPrrfMMomzVdw==',
      cap_mon => 'allow rwx',
      cap_osd => 'allow rwx',
      inject  => true,
    }

    # FIXME(Xarses) switch to param when supported in puppet-ceph
    class { '::ceph::profile::rgw':
      # swift_dropin = $swift_dropin
    }


    $password    = 'secret'
    $auth_name   = 'rgwuser'
    $project     = 'services'
    $user_domain = 'default'

    #configure rgw to use keystone
    ceph::rgw::keystone { 'radosgw.gateway':
      rgw_keystone_url            => $::openstack_integration::config::keystone_admin_uri,
      rgw_keystone_version        => 'v3',
      user                        => 'ceph',
      use_pki                     => false,
      rgw_keystone_accepted_roles => ['admin', 'member'],
      rgw_keystone_admin_domain   => $user_domain,
      rgw_keystone_admin_project  => $project,
      rgw_keystone_admin_user     => $auth_name,
      rgw_keystone_admin_password => $password,
    }

    if $swift_dropin {
      class { '::ceph::rgw::keystone::auth':
        password     => $password,
        user         => $auth_name,
        tenant       => $project,
        roles        => ['admin', 'member'],
        public_url   => "http://${::openstack_integration::config::ip_for_url}:8080/swift/v1",
        admin_url    => "http://${::openstack_integration::config::ip_for_url}:8080/swift/v1",
        internal_url => "http://${::openstack_integration::config::ip_for_url}:8080/swift/v1",
      }
      # FIXME(Xarses) remove when supported in puppet-ceph
      Service<| tag == 'ceph-radosgw' |> -> Service <| tag == 'glance-service' |>
    }
  }
}
