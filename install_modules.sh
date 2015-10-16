#!/bin/bash

set -ex

if [ ! -z ${GEM_HOME} ]; then
    GEM_BIN_DIR=${GEM_HOME}/bin/
fi

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
export PUPPETFILE_DIR=${PUPPETFILE_DIR:-/etc/puppet/modules}
source $SCRIPT_DIR/functions

gem install r10k --no-ri --no-rdoc

# make sure there is no puppet module pre-installed
rm -rf "${PUPPETFILE_DIR:?}/"*

install_modules

puppet module list
