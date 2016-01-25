class openstack_integration::ceph {

  class { '::ceph':
    fsid                      => '7200aea0-2ddd-4a32-aa2a-d49f66ab554c',
    mon_host                  => '127.0.0.1',
    authentication_type       => 'none',
    osd_pool_default_size     => '1',
    osd_pool_default_min_size => '1',
  }
  ceph::mon { 'mon1':
    public_addr         => '127.0.0.1',
    authentication_type => 'none',
  }
  ceph::osd { '/srv/data': }

}
