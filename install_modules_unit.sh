#!/bin/bash
#
# This script is used by Puppet OpenStack modules to prepare
# modules before running dependencies.
#

set -ex

if [ ! -z ${GEM_HOME} ]; then
    GEM_BIN_DIR=${GEM_HOME}/bin/
fi

export SCRIPT_DIR=$(readlink -f "$(dirname $0)")
export PUPPETFILE_DIR=${PUPPETFILE_DIR:-/etc/puppet/modules}
source $SCRIPT_DIR/functions

install_modules
