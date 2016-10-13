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

OpenStack Infrastructure is deploying three jobs per supported Operating System
(Ubuntu and CentOS): scenario001, scenario002 and scenario003.

OpenStack services are balanced between three scenarios because OpenStack
Infastructure Jenkins slaves can not afford the load of running everything on
the same node.
One manifest (scenario-aio) is used for people who want to [run a simple All-In-One
scenario](#all-in-one).

|     -      | scenario001 | scenario002 | scenario003 | scenario-aio |
|:----------:|:-----------:|:-----------:|:-----------:|:-------------:
| ssl        |     yes     |      yes    |      yes    |      no      |
| ipv6       |   centos7   |    centos7  |    centos7  |      no      |
| keystone   |      X      |       X     |       X     |       X      |
| tokens     |    uuid     |     uuid    |    fernet   |     uuid     |
| glance     |     rbd     |     swift   |     file    |     file     |
| nova       |     rbd     |       X     |       X     |       X      |
| neutron    |     ovs     |      ovs    | linuxbridge |      ovs     |
| lbaas      |     v2      |      v2     |     v2      |      v2      |
| cinder     |     rbd     |     iscsi   |             |    iscsi     |
| ceilometer |      X      |             |             |              |
| aodh       |      X      |             |             |              |
| designate  |             |             |     bind    |              |
| backup     |             |    swift    |             |              |
| gnocchi    |     rbd     |             |             |              |
| heat       |             |             |       X     |              |
| swift      |             |       X     |             |              |
| sahara     |             |             |       X     |              |
| trove      |             |             |       X     |              |
| horizon    |             |             |       X     |       X      |
| ironic     |             |       X     |             |              |
| zaqar      |             |       X     |             |              |
| barbican   |             |       X     |             |              |
| ceph       |      X      |             |             |              |
| mongodb    |             |       X     |             |              |

When the Jenkins slave is created, the *run_tests.sh* script will executed.
This script will execute *install_modules.sh* that prepare /etc/puppet/modules
with all Puppet modules dependencies.

Then, it will execute Puppet a first time by applying a scenario manifest.
If the first run executes without error, a second Puppet run will be executed to
verify there is no change in the catalog and make sure the Puppet run is
idempotent.

If Puppet runs are successful, the script will run
[Tempest](http://docs.openstack.org/developer/tempest/overview.html) Smoke
tests, that will execute some scenarios & API tests. It covers what we want to
validate, and does not take too much time.


Development
-----------

Developer documentation for the entire Puppet OpenStack project:

* http://docs.openstack.org/developer/puppet-openstack-guide/

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
git clone git://git.openstack.org/openstack/puppet-openstack-integration
cd puppet-openstack-integration
./all-in-one.sh
```
or

```bash
curl -sL http://git.openstack.org/cgit/openstack/puppet-openstack-integration/plain/all-in-one.sh | bash
```

Look at [Description](#description) to see which services it will install
(scenario-aio).


Contributors
------------

* https://github.com/openstack/puppet-openstack-integration/graphs/contributors
