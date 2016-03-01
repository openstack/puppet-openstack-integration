#
# Copyright 2015 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include ::openstack_integration
include ::openstack_integration::cacert
class { '::openstack_integration::rabbitmq':
  ssl => true,
}
include ::openstack_integration::mysql
include ::openstack_integration::keystone
class { '::openstack_integration::glance':
  backend => 'swift',
  ssl     => true,
}
class { '::openstack_integration::neutron':
  ssl => true,
}
class { '::openstack_integration::nova':
  ssl => true,
}
class { '::openstack_integration::cinder':
  ssl => true,
}
include ::openstack_integration::swift
class { '::openstack_integration::ironic':
  ssl => true,
}
include ::openstack_integration::mongodb
include ::openstack_integration::provision

case $::osfamily {
  'Debian': {
    # ironic-conductor is broken for Ubuntu Trusty
    # https://bugs.launchpad.net/cloud-archive/+bug/1530869
    $ironic_enabled = false
  }
  'RedHat': {
    $ironic_enabled = true
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

class { '::openstack_integration::tempest':
  cinder => true,
  swift  => true,
  ironic => $ironic_enabled,
}
