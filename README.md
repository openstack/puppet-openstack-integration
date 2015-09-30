puppet-openstack-integration
============================

#### Table of Contents

1. [Overview - What is Puppet OpenStack Integration?](#overview)
2. [Description - What does the project do?](#description)
3. [Development - Guide for contributing](#development)
4. [Contributors - Those with commits](#contributors)


Overview
--------

Puppet OpenStack Integration makes sure we can continuously test and validate
OpenStack setups deployed with Puppet modules. The repository itself contains
some scripts and Puppet manifests that help to deploy OpenStack in OpenStack
Infrastructure environment.


Description
-----------

OpenStack Infrastructure is deploying two jobs per supported Operating System
(Ubuntu and CentOS): scenario001 and scenario002.

OpenStack services are balanced between two scenarios because OpenStack
Infastructure Jenkins slaves can not afford the load of running all on the
same node.

|     -      | scenario001 | scenario002 |
|:----------:|:-----------:|:-----------:|
| keystone   |      X      |       X     |
| glance     |      X      |       X     |
| nova       |      X      |       X     |
| neutron    |      X      |       X     |
| cinder     |      X      |             |
| ceilometer |      X      |             |
| heat       |             |       X     |
| swift      |             |       X     |
| sahara     |             |       X     |
| trove      |      X      |             |

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

* https://wiki.openstack.org/wiki/Puppet


Contributors
------------

* https://github.com/openstack/puppet-openstack-integration/graphs/contributors
