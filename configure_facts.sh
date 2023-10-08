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

source /etc/os-release
export OS_NAME_VERS=${ID}${VERSION_ID}

# Write out facts to the facter folder when we generate them.
export WRITE_FACTS=${WRITE_FACTS:-true}
export OPENSTACK_VERSION=${OPENSTACK_VERSION:-master}
export DLRN_TAG=${DLRN_TAG:-puppet-passed-ci}
export DLRN_ROOT=${DLRN_ROOT:-${OS_NAME_VERS}-${OPENSTACK_VERSION}}
export DLRN_BASE=${DLRN_BASE:-${DLRN_ROOT}/${DLRN_TAG}}
export DLRN_BASE_URL=${DLRN_BASE_URL:-${DLRN_BASE}/delorean.repo}
export DLRN_DEPS_URL=${DLRN_DEPS_URL:-${DLRN_ROOT}/delorean-deps.repo}
export CEPH_VERSION=${CEPH_VERSION:-reef}

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
source $SCRIPT_DIR/functions

if [ -f /etc/ci/mirror_info.sh ]; then
    source /etc/ci/mirror_info.sh

    CENTOS_MIRROR_HOST="http://${NODEPOOL_MIRROR_HOST}/centos-stream"
    if uses_debs; then
        CEPH_MIRROR_HOST="http://${NODEPOOL_MIRROR_HOST}/ceph-deb-${CEPH_VERSION}"
        NODEPOOL_PUPPETLABS_MIRROR="http://${NODEPOOL_MIRROR_HOST}/apt-puppetlabs"
    else
        CEPH_MIRROR_HOST="${CENTOS_MIRROR_HOST}/SIGs/${VERSION_ID}-stream/storage/x86_64/ceph-${CEPH_VERSION}/"
        NODEPOOL_PUPPETLABS_MIRROR="http://${NODEPOOL_MIRROR_HOST}/yum-puppetlabs"
    fi
else
    CENTOS_MIRROR_HOST='http://mirror.stream.centos.org'
    NODEPOOL_RDO_PROXY='https://trunk.rdoproject.org'
    NODEPOOL_UCA_MIRROR='http://ubuntu-cloud.archive.canonical.com/ubuntu'
    if uses_debs; then
        CEPH_MIRROR_HOST="https://download.ceph.com/debian-${CEPH_VERSION}"
        NODEPOOL_PUPPETLABS_MIRROR='https://apt.puppetlabs.com'
    else
        CEPH_MIRROR_HOST="${CENTOS_MIRROR_HOST}/SIGs/${VERSION_ID}-stream/storage/x86_64/ceph-${CEPH_VERSION}/"
        NODEPOOL_PUPPETLABS_MIRROR="https://yum.puppetlabs.com"
    fi
fi

if uses_debs; then
    MIRROR_FACTS="\
openstack_version=${OPENSTACK_VERSION}
uca_mirror_host=${UCA_MIRROR_HOST}
ceph_mirror_host=${CEPH_MIRROR_HOST}
ceph_version=${CEPH_VERSION}"
else
    curl -o /tmp/delorean.repo "${NODEPOOL_RDO_PROXY}/${DLRN_BASE_URL}"
    sed -i -e "s|https://trunk.rdoproject.org|${NODEPOOL_RDO_PROXY}|g" /tmp/delorean.repo

    curl -o /tmp/delorean-deps.repo "${NODEPOOL_RDO_PROXY}/${DLRN_DEPS_URL}"
    sed -i -e "s|https://trunk.rdoproject.org|${NODEPOOL_RDO_PROXY}|g" /tmp/delorean-deps.repo
    sed -i -e "s|http://mirror.centos.org|${CENTOS_MIRROR_HOST}|g" /tmp/delorean-deps.repo
    sed -i -e "s|http://mirror.stream.centos.org|${CENTOS_MIRROR_HOST}|g" /tmp/delorean-deps.repo

    MIRROR_FACTS="\
openstack_version=${OPENSTACK_VERSION}
centos_mirror_host=${CENTOS_MIRROR_HOST}
ceph_mirror_host=${CEPH_MIRROR_HOST}
ceph_version=${CEPH_VERSION}
delorean_repo_path=/tmp/delorean.repo
delorean_deps_repo_path=/tmp/delorean-deps.repo"
fi

if [ "${WRITE_FACTS}" = true ]; then
    $SUDO mkdir -p /etc/facter/facts.d/
    echo "$MIRROR_FACTS" | $SUDO tee /etc/facter/facts.d/mirrors.txt
fi
