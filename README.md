Team and repository tags
========================

[![Team and repository tags](https://governance.openstack.org/tc/badges/puppet-openstack-integration.svg)](https://governance.openstack.org/tc/reference/tags/index.html)

<!-- Change things from this point on -->

puppet-openstack-integration
============================

#### Table of Contents

1. [Overview - What is Puppet OpenStack Integration?](#overview)
2. [Description - What does the project do?](#description)
3. [Development - Guide for contributing](#development)
4. [All-in-one - How to deploy a cloud with Puppet](#all-in-one)
5. [Contributors - Those with commits](#contributors)


Overview
--------

Puppet OpenStack Integration makes sure we can continuously test and validate
OpenStack setups deployed with Puppet modules. The repository itself contains
some scripts and Puppet manifests that help to deploy OpenStack in OpenStack
Infrastructure environment.


Description
-----------

OpenStack Infrastructure is deploying four jobs per supported Operating System
(Ubuntu and CentOS): scenario001, scenario002, scenario003, scenario004, and
scenario005.

The manifest files under the fixtures directory is used to compose the required
services for each senario. The manifest files under the manifests directory
is used to set up basic set of a single component (like nova, cinder and so on).

OpenStack services are balanced between four scenarios because OpenStack
Infastructure Jenkins slaves can not afford the load of running everything on
the same node.
One manifest (scenario-aio) is used for people who want to [run a simple All-In-One
scenario](#all-in-one).

|     -      | scenario001 | scenario002 | scenario003 | scenario004 | scenario005 | scenario-aio |
|:----------:|:-----------:|:-----------:|:-----------:|:-----------:|:-----------:|:------------:|
| ssl        |     yes     |      yes    |      yes    |     yes     |     yes     |     no       |
| ipv6       |   centos9   |    centos9  |    centos9  |   centos9   |   centos9   |     no       |
| keystone   |      X      |       X     |       X     |      X      |      X      |      X       |
| glance     |     rbd     |     swift   |     file    |     rbd     |   cinder    |    file      |
| nova       |     rbd     |       X     |       X     |     rbd     |      X      |      X       |
| placement  |      X      |       X     |       X     |      X      |      X      |      X       |
| neutron    |     ovs     |      ovs    |      ovn    |     ovs     |     ovn     |     ovs      |
| cinder     |     rbd     |     iscsi   |             |             |    iscsi    |    iscsi     |
| manila     |             |             |             |   cephfs    |     lvm     |              |
| ceilometer |      X      |       X     |             |             |             |              |
| aodh       |      X      |       X     |             |             |             |              |
| designate  |             |             |     bind    |             |             |              |
| backup     |    ceph     |    swift    |             |             |             |              |
| gnocchi    |     rbd     |    swift    |             |             |             |              |
| heat       |      X      |             |       X     |             |             |              |
| swift      |             |       X     |             |             |             |              |
| trove      |             |             |       X     |             |             |              |
| horizon    |             |       X     |       X     |      X      |      X      |      X       |
| ironic     |             |       X     |             |             |             |              |
| zaqar      |             |       X     |             |             |             |              |
| magnum     |             |             |       X     |             |             |              |
| mistral    |             |             |       X     |             |             |              |
| barbican   |             |       X     |       X     |             |             |              |
| ceph       |      X      |             |             |      X      |             |              |
| ceph mds   |             |             |             |      X      |             |              |
| ceph rgw   |             |             |             |      X      |             |              |
| vitrage    |      X      |             |             |             |             |              |
| watcher    |             |             |             |      X      |             |              |
| vpnaas     |             |             |             |      X      |             |              |
| taas       |             |             |             |      X      |             |              |
| bgpvpn-api |             |             |             |      X      |             |              |
| bgp-dr     |             |             |             |      X      |             |              |
| memcached  |      X      |       X     |       X     |      X      |      X      |      X       |
| redis      |      X      |       X     |       X     |      X      |      X      |              |
| l2gw       |             |             |             |      X      |             |              |
| octavia    |             |             |             |      X      |      X      |              |
| om rpc     |    rabbit   |    rabbit   |    rabbit   |    rabbit   |    rabbit   |    rabbit    |
| om notify  |    rabbit   |    rabbit   |    rabbit   |    rabbit   |    rabbit   |    rabbit    |
| oslo.cache |    redis    |   sentinel  |   memcache  |   memcache  |   memcache  |   memcache   |
| tooz       |    redis    |   sentinel  |    redis    |    redis    |    redis    |              |
| jobboard   |             |             |             |    redis    |   sentinel  |              |

When the Jenkins slave is created, the *run_tests.sh* script will be executed.
This script will execute *install_modules.sh* that prepare /etc/puppet/modules
with all Puppet modules dependencies.

Then, it will execute Puppet a first time by applying a scenario manifest.
If the first run executes without error, a second Puppet run will be executed to
verify there is no change in the catalog and make sure the Puppet run is
idempotent.

If Puppet runs are successful, the script will run
[Tempest](https://docs.openstack.org/tempest/latest/overview.html) Smoke
tests, that will execute some scenarios & API tests. It covers what we want to
validate, and does not take too much time.


Development
-----------

Developer documentation for the entire Puppet OpenStack project:

* https://docs.openstack.org/puppet-openstack-guide/latest

Note: SSL Certificates
----------------------

puppet-openstack-integration ships it's own SSL keys and certificates in order
to be able to test implementations secured over SSL/TLS.

It doesn't re-generate new ones every time for the sake of simplicity: we're
not testing that we can generate certificates properly, we're testing services.

The configuration as well as the commands used to generate these keys and
certificates are stored in the contrib directory.

All-In-One
----------

If you're new in Puppet OpenStack and you want to deploy an All-In-One setup of
an OpenStack Cloud with the Puppet modules, please follow the steps:

```bash
git clone https://opendev.org/openstack/puppet-openstack-integration
cd puppet-openstack-integration
./all-in-one.sh
```

Look at [Description](#description) to see which services it will install
(scenario-aio).


Contributors
------------

* https://github.com/openstack/puppet-openstack-integration/graphs/contributors
