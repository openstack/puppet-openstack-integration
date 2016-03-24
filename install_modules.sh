#!/bin/bash

set -ex

if [ -n "${GEM_HOME}" ]; then
    GEM_BIN_DIR=${GEM_HOME}/bin/
fi

if [ "${PUPPET_VERSION}" = 4 ]; then
  export PUPPET_BASE_PATH=/etc/puppetlabs/code
else
  export PUPPET_BASE_PATH=/etc/puppet
fi

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
export PUPPETFILE_DIR=${PUPPETFILE_DIR:-${PUPPET_BASE_PATH}/modules}
source $SCRIPT_DIR/functions

gem install r10k --no-ri --no-rdoc

# make sure there is no puppet module pre-installed
rm -rf "${PUPPETFILE_DIR:?}/"*

install_modules

puppet module list
