#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.
# This script takes bits from devstack-gate/functions/cleanup_host in a
# more generic approach, so we don't need to actually run devstack on the node
# to cleanup an host.

set -o xtrace
set -o errexit

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
source $SCRIPT_DIR/functions

print_header 'Copy logs into workspace'

LOG_DIR=$WORKSPACE/logs
[[ ! -d "${WORKSPACE}/logs" ]] && mkdir -p ${WORKSPACE}/logs

# PROJECTS
#  - for each entry, we will probe /etc/${project} and /var/log/${project}
#    and copy out files
#
# For right now, we populate our projects with a guess from those that
# have puppet modules installed.  revisit this if needs change
if [ -d "${WORKSPACE}/spec/fixtures/modules" ]; then
    # Litmus job
    PUPPET_MODULES_PATH="${WORKSPACE}/spec/fixtures/modules"
elif [ -d "/etc/puppetlabs/code/modules" ]; then
    # Integration job
    PUPPET_MODULES_PATH='/etc/puppetlabs/code/modules'
else
    # Integration tests with RDO puppet package
    PUPPET_MODULES_PATH='/etc/puppet/modules'
fi

for project in $PUPPET_MODULES_PATH/*; do
    # find Puppet OpenStack modules
    if [ -f $project/metadata.json ]; then
        if egrep -q "(github.com|opendev.org)/(stackforge|openstack)/puppet" $project/metadata.json; then
            PROJECTS+="$(basename $project) "
            # if we've added ironic we want to try for ironic-inspector also
            if [ "$(basename $project)" == 'ironic' ] ; then
                PROJECTS+="ironic-inspector "
            fi
        fi
    fi
done

# start of log capture
# some commands could fail if service failed to be installed during Puppet runs
set +e

# Copy puppet log
cp ${WORKSPACE}/puppet*.log $LOG_DIR

# Archive the project config & logs
mkdir $LOG_DIR/etc/
for p in $PROJECTS; do
    if [ -d /etc/$p ]; then
        sudo cp -r /etc/$p $LOG_DIR/etc/
    fi
    if [ -d /var/log/$p ]; then
        sudo cp -r /var/log/$p $LOG_DIR
    fi
done

#
# Extra bits and pieces follow
#

# system logs
if uses_debs; then
    sudo cp /var/log/kern.log $LOG_DIR/kern_log.txt
fi
if which journalctl &> /dev/null; then
    sudo journalctl --no-pager > $LOG_DIR/syslog.txt
fi

# network interfaces
if [ -d /etc/sysconfig/network-scripts ]; then
    mkdir -p $LOG_DIR/etc/sysconfig
    sudo cp -r /etc/sysconfig/network-scripts $LOG_DIR/etc/sysconfig/
fi

# rabbitmq
if [ -d /etc/rabbitmq ]; then
    sudo cp -r /etc/rabbitmq $LOG_DIR/etc/
fi
if [ -d /var/log/rabbitmq ]; then
    sudo cp -r /var/log/rabbitmq $LOG_DIR
fi

# db logs
# postgresql
if [ -d /var/log/postgresql ] ; then
    # Rename log so it doesn't have an additional '.' so it won't get
    # deleted
    sudo cp /var/log/postgresql/*log $LOG_DIR/postgres.log
fi
# mysql/mariadb
if uses_debs; then
    if [ -d /etc/mysql ] ; then
        sudo cp -r /etc/mysql $LOG_DIR/etc/
    fi
    if [ -d /var/log/mysql ] ; then
        sudo cp -r /var/log/mysql $LOG_DIR/
    fi
else
    if [ -f /etc/my.cnf ] ; then
        sudo cp /etc/my.cnf $LOG_DIR/etc/
    fi
    if [ -d /etc/my.cnf.d ] ; then
        sudo cp -r /etc/my.cnf.d $LOG_DIR/etc/
    fi
    if [ -d /var/log/mariadb ] ; then
        sudo cp -r /var/log/mariadb $LOG_DIR/
    fi
fi

# iscsi
if [ -d /etc/iscsi ]; then
    sudo cp -r /etc/iscsi $LOG_DIR/etc/
fi

# tgt
if uses_debs; then
    if [ -d /etc/tgt ]; then
        sudo cp -r /etc/tgt $LOG_DIR/etc/
    fi
fi

# tempest logs
if [ -f /tmp/openstack/tempest/tempest.log ] ; then
    sudo cp /tmp/openstack/tempest/tempest.log $LOG_DIR/
fi

# Tempest subunit results
if [ -f /tmp/openstack/tempest/testrepository.subunit ] ; then
    for f in testrepository.subunit testr_results.html;
    do
        sudo cp /tmp/openstack/tempest/$f $LOG_DIR/$f
    done
fi

# dstat logs
if [ -f /var/log/dstat.log ] ; then
    sudo cp /var/log/dstat.log $LOG_DIR/
fi

# iostat logs
if [ -f /var/log/iostat.log ] ; then
    sudo cp /var/log/iostat.log $LOG_DIR/
fi

# iotop logs
if [ -f /var/log/iotop.log ] ; then
    sudo cp /var/log/iotop.log $LOG_DIR/
fi

# libvirt
if [ -d /var/log/libvirt ] ; then
    sudo cp -r /var/log/libvirt $LOG_DIR/
    sudo virsh net-list --all > $LOG_DIR/virsh-net-list.txt
fi
if [ -d /etc/libvirt ]; then
    sudo cp -r /etc/libvirt $LOG_DIR/etc/
fi
if uses_debs; then
    if [ -f /etc/default/libvirtd ]; then
        mkdir $LOG_DIR/etc/default
        sudo cp /etc/default/libvirtd $LOG_DIR/etc/default/
    fi
elif is_fedora; then
    if [ -f /etc/sysconfig/libvirtd ]; then
        mkdir $LOG_DIR/etc/sysconfig
        sudo cp /etc/sysconfig/libvirtd $LOG_DIR/etc/sysconfig/
    fi
fi

# openvswitch
if [ -d /var/log/openvswitch ] ; then
    sudo cp -r /var/log/openvswitch $LOG_DIR/
fi

# ovn
if [ -d /var/log/ovn ] ; then
    sudo ovn-nbctl show > $LOG_DIR/ovn-nbctl_show.txt
    sudo ovn-sbctl show > $LOG_DIR/ovn-sbctl_show.txt
fi

# sudo config
sudo cp -r /etc/sudoers.d $LOG_DIR/
sudo cp /etc/sudoers $LOG_DIR/sudoers.txt

# apache logs; including wsgi stuff like horizon, keystone, etc.
if uses_debs; then
    apache_logs=/var/log/apache2
    redis_logs=/var/log/redis/redis-server.log
    if [ -d /etc/apache2/sites-enabled ]; then
        mkdir $LOG_DIR/apache_config
        sudo cp /etc/apache2/sites-enabled/* $LOG_DIR/apache_config
        for f in `ls $LOG_DIR/apache_config`; do
            mv $LOG_DIR/apache_config/${f} $LOG_DIR/apache_config/${f}.txt
        done
    fi
elif is_fedora; then
    apache_logs=/var/log/httpd
    redis_logs=/var/log/redis/redis.log
    if [ -d /etc/httpd/conf.d ]; then
        mkdir $LOG_DIR/apache_config
        sudo cp /etc/httpd/conf.d/* $LOG_DIR/apache_config
        for f in `ls $LOG_DIR/apache_config`; do
            mv $LOG_DIR/apache_config/${f} $LOG_DIR/apache_config/${f}.txt
        done
    fi
fi
if [ -d ${apache_logs} ]; then
    sudo cp -r ${apache_logs} $LOG_DIR/apache
fi

if [ -f ${redis_logs} ]; then
    sudo cp ${redis_logs} $LOG_DIR/redis.log.txt
fi

if [ -d /etc/redis ]; then
    sudo cp -r /etc/redis $LOG_DIR/etc/redis
elif [ -f /etc/redis.conf ]; then
    sudo cp /etc/redis.conf $LOG_DIR/etc/
fi

if [ -f /var/log/qdrouterd/qdrouterd.log ]; then
    sudo cp /var/log/qdrouterd/qdrouterd.log $LOG_DIR/qdrouterd.log.txt
    if [ -f /etc/qpid-dispatch/qdrouterd.conf ]; then
        mkdir $LOG_DIR/qdrouterd_config
        sudo cp /etc/qpid-dispatch/qdrouterd.conf $LOG_DIR/qdrouterd_config/qdrouterd.conf.txt
    fi
fi

if [ -d /var/log/audit/ ]; then
    sudo cp /var/log/audit/audit.log $LOG_DIR/audit.log.txt || true
fi

if [ -d /var/spool/cron/ ]; then
    sudo cp -r /var/spool/cron $LOG_DIR/
fi

if [ -d /tmp/openstack/tempest ]; then
    sudo cp /tmp/openstack/tempest/etc/tempest.conf $LOG_DIR/tempest.conf.txt
fi

if [ -d /etc/openstack-dashboard ]; then
    sudo cp -r /etc/openstack-dashboard $LOG_DIR/etc/openstack-dashboard
    for f in `ls $LOG_DIR/etc/openstack-dashboard`; do
        sudo mv $LOG_DIR/etc/openstack-dashboard/${f} $LOG_DIR/etc/openstack-dashboard/${f}.txt
    done
fi

# package status and repository list
if [ `command -v dpkg` ]; then
    dpkg -l> $LOG_DIR/dpkg-l.txt
fi
if [ `command -v apt` ]; then
    apt-cache policy > $LOG_DIR/apt-cache-policy.txt
    sudo cp -r /etc/apt $LOG_DIR/etc/apt
fi
if [ `command -v rpm` ]; then
    rpm -qa |sort > $LOG_DIR/rpm-qa.txt
    sudo $YUM repolist -v > $LOG_DIR/repolist.txt
    sudo cp -r /etc/yum.repos.d $LOG_DIR/etc/yum.repos.d
fi
if [ `command -v dnf` ]; then
    sudo dnf module list > $LOG_DIR/modulelist.txt
    mkdir $LOG_DIR/dnf
    sudo cp /var/log/dnf.log $LOG_DIR/dnf
    sudo cp /var/log/dnf.rpm.log $LOG_DIR/dnf
fi

if [ `command -v gem` ]; then
    gem list |sort > $LOG_DIR/gem-list.txt
fi

# system status & informations
sudo cp /etc/passwd $LOG_DIR/etc
sudo cp /etc/group $LOG_DIR/etc
sudo cp /root/openrc $LOG_DIR/openrc.txt
sudo chmod 777 $LOG_DIR/openrc.txt
sudo cp -r /etc/openstack $LOG_DIR/etc
sudo chmod 777 $LOG_DIR/etc/openstack/puppet/admin-clouds.yaml
df -h > $LOG_DIR/df.txt
free -m > $LOG_DIR/free.txt
lsmod > $LOG_DIR/lsmod.txt
cat /proc/cpuinfo > $LOG_DIR/cpuinfo.txt
sudo ps -eo user,pid,ppid,lwp,%cpu,%mem,size,rss,cmd > $LOG_DIR/ps.txt
sudo ip -d address > $LOG_DIR/ip_-d_address.txt
sudo brctl show > $LOG_DIR/brctl_show.txt
if [ `command -v ovs-vsctl` ]; then
    sudo ovs-vsctl show > $LOG_DIR/ovs-vsctl_show.txt
    sudo ovs-vsctl list open_vswitch > $LOG_DIR/ovs-vsctl_list_open_vswitch.txt
fi
sudo netstat -tulpn > $LOG_DIR/netstat.txt
sudo LC_CTYPE=C SYSTEMD_COLORS=false systemctl status --all --no-pager 2>/dev/null > $LOG_DIR/systemctl.txt

for table in raw filter nat mangle ; do
    echo $table
    sudo iptables -t $table -vnxL
    echo ""
done > $LOG_DIR/iptables.txt

sudo cp /etc/fstab $LOG_DIR/etc/
sudo mount > $LOG_DIR/mount.txt
sudo losetup -al > $LOG_DIR/losetup_-al.txt
echo "== pvs ==" >> $LOG_DIR/lvm.txt
sudo pvs >> $LOG_DIR/lvm.txt
echo "== vgs ==" >> $LOG_DIR/lvm.txt
sudo vgs >> $LOG_DIR/lvm.txt
echo "== lvs ==" >> $LOG_DIR/lvm.txt
sudo lvs >> $LOG_DIR/lvm.txt

mkdir -p $LOG_DIR/openstack_resources

export OS_CLOUD=project
export OS_CLIENT_CONFIG_FILE=$LOG_DIR/etc/openstack/puppet/admin-clouds.yaml
# keystone resources
if [ -d $LOG_DIR/keystone ]; then
    openstack >> $LOG_DIR/openstack_resources/keystone.txt <<-EOC
extension list --identity
endpoint list
service list --long
project list --long
user list --long
role list
role assignment list
EOC
fi

# nova resources
if [ -d $LOG_DIR/nova ]; then
    openstack >> $LOG_DIR/openstack_resources/nova.txt <<-EOC
extension list --compute
compute service list
flavor list --all --long
server list --all --long
EOC
fi

# cinder resources
if [ -d $LOG_DIR/cinder ]; then
    openstack >> $LOG_DIR/openstack_resources/cinder.txt <<-EOC
extension list --volume
volume service list
volume type list --long
volume list --all --long
EOC
fi

# glance resources
if [ -d $LOG_DIR/glance ]; then
    openstack >> $LOG_DIR/openstack_resources/glance.txt <<-EOC
image list --long
EOC
fi

# neutron resources
if [ -d $LOG_DIR/neutron ]; then
    openstack >> $LOG_DIR/openstack_resources/neutron.txt <<-EOC
extension list --network
network agent list
network list --long
subnet list --long
port list --long
router list --long
floating ip list --long
network show public
subnet show public-subnet
EOC
fi

unset OS_CLOUD
unset OS_CLIENT_CONFIG_FILE

# swift rings
if [ -d $LOG_DIR/swift ]; then
    sudo swift-ring-builder /etc/swift/account.builder >> $LOG_DIR/swift-rings.txt
    sudo swift-ring-builder /etc/swift/container.builder >> $LOG_DIR/swift-rings.txt
    sudo swift-ring-builder /etc/swift/object.builder >> $LOG_DIR/swift-rings.txt
fi

# end of log capture
set -e

# Set permissions to let jenkins compress and archive logs.
# Also make sure zuul can rsync all the logs and configs
sudo find $LOG_DIR -type d -execdir sudo chmod 755 '{}' \;
sudo find $LOG_DIR -type f -execdir sudo chmod 644 '{}' \;
sudo chown -R "$(id -u):$(id -g)" $LOG_DIR

# do not try to save symlinks because source files might not have
# the right permissions to let jenkins user to upload them on log servers.
sudo find $LOG_DIR -type l -execdir sudo rm -f '{}' \;

# rename files to .txt; this is so that when displayed via
# logs.openstack.org clicking results in the browser shows the
# files, rather than trying to send it to another app or make you
# download it, etc.

# firstly, rename all .log files to .txt files
for f in $(find $LOG_DIR -name "*.log"); do
    sudo mv $f ${f/.log/.txt}
done

# append .txt to all config files
# (there are some /etc/swift .builder and .ring files that get
# caught up which aren't really text, don't worry about that)
find $LOG_DIR/sudoers.d $LOG_DIR/etc -type f -exec sudo mv '{}' '{}'.txt \;

# rabbitmq
if [ -f $LOG_DIR/rabbitmq ]; then
    find $LOG_DIR/rabbitmq -type f -exec sudo mv '{}' '{}'.txt \;
    for X in `find $LOG_DIR/rabbitmq -type f` ; do
        sudo mv "$X" "${X/@/_at_}"
    done
fi

# hiera config
if [ -f $SCRIPT_DIR/hiera.yaml ]; then
    mv $SCRIPT_DIR/hiera.yaml $LOG_DIR
fi

# hiera data
if [ -d $SCRIPT_DIR/hiera ]; then
    mv $SCRIPT_DIR/hiera $LOG_DIR
fi
