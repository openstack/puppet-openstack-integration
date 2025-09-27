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
export DLRN_TAG=${DLRN_TAG:-current}
export DLRN_ROOT=${DLRN_ROOT:-${OS_NAME_VERS}-${OPENSTACK_VERSION}}
export DLRN_BASE=${DLRN_BASE:-${DLRN_ROOT}/${DLRN_TAG}}
export DLRN_BASE_URL=${DLRN_BASE_URL:-${DLRN_BASE}/delorean.repo}
export DLRN_DEPS_URL=${DLRN_DEPS_URL:-${DLRN_ROOT}/delorean-deps.repo}

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
source $SCRIPT_DIR/functions

if [ -f /etc/ci/mirror_info.sh ]; then
    source /etc/ci/mirror_info.sh

    CENTOS_MIRROR_HOST="http://${NODEPOOL_MIRROR_HOST}/centos-stream"
    if uses_debs; then
        NODEPOOL_PUPPETLABS_MIRROR="http://${NODEPOOL_MIRROR_HOST}/apt-puppetlabs"
    else
        NODEPOOL_PUPPETLABS_MIRROR="http://${NODEPOOL_MIRROR_HOST}/yum-puppetlabs"
    fi
else
    CENTOS_MIRROR_HOST='http://mirror.stream.centos.org'
    NODEPOOL_RDO_PROXY='https://trunk.rdoproject.org'
    NODEPOOL_UCA_MIRROR='http://ubuntu-cloud.archive.canonical.com/ubuntu'
    if uses_debs; then
        NODEPOOL_PUPPETLABS_MIRROR='https://apt.puppetlabs.com'
    else
        NODEPOOL_PUPPETLABS_MIRROR="https://yum.puppetlabs.com"
    fi
fi

export FACTER_openstack_version=${OPENSTACK_VERSION}

COMMON_MIRROR_FACTS="openstack_version=${FACTER_openstack_version}"

if uses_debs; then
    export FACTER_uca_mirror_host=${NODEPOOL_UCA_MIRROR}

    MIRROR_FACTS="\
uca_mirror_host=${FACTER_uca_mirror_host}"
else
    curl -o /tmp/delorean.repo "${NODEPOOL_RDO_PROXY}/${DLRN_BASE_URL}"
    sed -i -e "s|https://trunk.rdoproject.org|${NODEPOOL_RDO_PROXY}|g" /tmp/delorean.repo

    curl -o /tmp/delorean-deps.repo "${NODEPOOL_RDO_PROXY}/${DLRN_DEPS_URL}"
    sed -i -e "s|https://trunk.rdoproject.org|${NODEPOOL_RDO_PROXY}|g" /tmp/delorean-deps.repo
    sed -i -e "s|http://mirror.stream.centos.org|${CENTOS_MIRROR_HOST}|g" /tmp/delorean-deps.repo

    export FACTER_centos_mirror_host=${CENTOS_MIRROR_HOST}
    export FACTER_delorean_repo_path=/tmp/delorean.repo
    export FACTER_delorean_deps_repo_path=/tmp/delorean-deps.repo

    MIRROR_FACTS="\
centos_mirror_host=${FACTER_centos_mirror_host}
delorean_repo_path=${FACTER_delorean_repo_path}
delorean_deps_repo_path=${FACTER_delorean_deps_repo_path}"
fi

if [ "${WRITE_FACTS}" = true ]; then
    $SUDO mkdir -p /etc/facter/facts.d/
    echo "$COMMON_MIRROR_FACTS" | $SUDO tee /etc/facter/facts.d/mirrors.txt
    echo "$MIRROR_FACTS" | $SUDO tee -a /etc/facter/facts.d/mirrors.txt
fi
