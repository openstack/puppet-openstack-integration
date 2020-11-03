#!/bin/bash -ex
# Copyright 2017 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# Write out facts to the facter folder when we generate them.
export WRITE_FACTS=${WRITE_FACTS:-true}
export DLRN_BASE=${DLRN_BASE:-centos7-stein/puppet-passed-ci}
export DLRN_DEPS_BASE=${DLRN_DEPS_BASE:-centos7-stein/deps/latest/}
export CEPH_VERSION=${CEPH_VERSION:-nautilus}

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
source $SCRIPT_DIR/functions

if [ -f /etc/fedora-release ]; then
    DLRN_BASE="fedora28-stein/consistent"
    DLRN_DEPS_BASE="fedora/stable-base/latest/"
fi

if [ -f /etc/ci/mirror_info.sh ]; then
    source /etc/ci/mirror_info.sh
    CENTOS_MIRROR_HOST="http://${NODEPOOL_MIRROR_HOST}"
    DEPS_MIRROR_HOST="${NODEPOOL_RDO_PROXY}/${DLRN_DEPS_BASE}/"
    if uses_debs; then
        if [ "$CEPH_VERSION" == "mimic" ]; then
            CEPH_MIRROR_HOST="http://download.ceph.com/debian-${CEPH_VERSION}"
        else
            CEPH_MIRROR_HOST="${CENTOS_MIRROR_HOST}/ceph-deb-${CEPH_VERSION}"
        fi
        NODEPOOL_PUPPETLABS_MIRROR="http://${NODEPOOL_MIRROR_HOST}/apt-puppetlabs"
    else
        # NOTE(tobias-urdin): Mimic was never released by Storage SIG to official mirros.
        if [ "$CEPH_VERSION" == "mimic" ]; then
            CEPH_MIRROR_HOST='https://trunk.rdoproject.org/centos7/deps/storage/storage7-ceph-mimic/x86_64/'
        else
            CEPH_MIRROR_HOST="${CENTOS_MIRROR_HOST}/centos/7/storage/x86_64/ceph-${CEPH_VERSION}/"
        fi
        NODEPOOL_PUPPETLABS_MIRROR="http://${NODEPOOL_MIRROR_HOST}/yum-puppetlabs"
    fi
else
    CENTOS_MIRROR_HOST='http://mirror.centos.org'
    DEPS_MIRROR_HOST="https://trunk.rdoproject.org/${DLRN_DEPS_BASE}/"
    NODEPOOL_RDO_PROXY='https://trunk.rdoproject.org'
    NODEPOOL_UCA_MIRROR='http://ubuntu-cloud.archive.canonical.com/ubuntu'
    if uses_debs; then
        CEPH_MIRROR_HOST="https://download.ceph.com/debian-${CEPH_VERSION}"
        NODEPOOL_PUPPETLABS_MIRROR='https://apt.puppetlabs.com'
    else
        # NOTE(tobias-urdin): Mimic was never released by Storage SIG to official mirros.
        if [ "$CEPH_VERSION" == "mimic" ]; then
            CEPH_MIRROR_HOST='https://trunk.rdoproject.org/centos7/deps/storage/storage7-ceph-mimic/x86_64/'
        else
            CEPH_MIRROR_HOST="${CENTOS_MIRROR_HOST}/centos/7/storage/x86_64/ceph-${CEPH_VERSION}/"
        fi
        NODEPOOL_PUPPETLABS_MIRROR="https://yum.puppetlabs.com"
    fi
fi

rdo_dlrn=`curl --silent ${NODEPOOL_RDO_PROXY}/${DLRN_BASE}/delorean.repo | grep baseurl | cut -d= -f2`
if [[ -z "$rdo_dlrn" ]]; then
    echo "Failed to parse dlrn hash"
    exit 1
fi
RDO_MIRROR_HOST=${rdo_dlrn/https:\/\/trunk.rdoproject.org/$NODEPOOL_RDO_PROXY}

export FACTER_nodepool_mirror_host=$NODEPOOL_MIRROR_HOST
export FACTER_centos_mirror_host=$CENTOS_MIRROR_HOST
export FACTER_uca_mirror_host=$NODEPOOL_UCA_MIRROR
export FACTER_deps_mirror_host=$DEPS_MIRROR_HOST
export FACTER_ceph_mirror_host=$CEPH_MIRROR_HOST
export FACTER_rdo_mirror_host=$RDO_MIRROR_HOST
export FACTER_ceph_version=$CEPH_VERSION

MIRROR_FACTS="\
nodepool_mirror_host=${FACTER_nodepool_mirror_host}
centos_mirror_host=${FACTER_centos_mirror_host}
uca_mirror_host=${FACTER_uca_mirror_host}
deps_mirror_host=${FACTER_deps_mirror_host}
ceph_mirror_host=${FACTER_ceph_mirror_host}
rdo_mirror_host=${FACTER_rdo_mirror_host}
ceph_version=${FACTER_ceph_version}"

if [ "${WRITE_FACTS}" = true ]; then
    $SUDO mkdir -p /etc/facter/facts.d/
    echo "$MIRROR_FACTS" | $SUDO tee /etc/facter/facts.d/mirrors.txt
fi
