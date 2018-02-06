#!/bin/bash
#
# This script is used by Puppet OpenStack modules to prepare
# modules before running dependencies.
#

set -ex

if [ -n "${GEM_HOME}" ]; then
    GEM_BIN_DIR=${GEM_HOME}/bin/
    export PATH=${PATH}:${GEM_BIN_DIR}
fi

export PUPPET_BASE_PATH=/etc/puppetlabs/code
export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
export PUPPETFILE_DIR=${PUPPETFILE_DIR:-${PUPPET_BASE_PATH}/modules}
source $SCRIPT_DIR/functions

print_header 'Start (install_modules_unit.sh)'

print_header 'Install Modules'
install_modules

print_header 'Module List'
puppet module list --modulepath ./spec/fixtures/modules

print_header 'Done (install_modules_unit.sh)'
