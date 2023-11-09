#!/bin/bash

set -ex

GEM_INSTALL_CMD="gem install --no-user-install --minimal-deps --verbose --no-document"

if [ -n "${GEM_HOME}" ]; then
    GEM_BIN_DIR=${GEM_HOME}/bin/
    export PATH=${PATH}:${GEM_BIN_DIR}
    GEM_INSTALL_CMD="${GEM_INSTALL_CMD} --install-dir=$GEM_HOME --bindir=${GEM_BIN_DIR}"
fi

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
source $SCRIPT_DIR/functions

print_header 'Start (install_modules.sh)'
print_header 'Install r10k'
$GEM_INSTALL_CMD r10k

# make sure there is no puppet module pre-installed
rm -rf "${PUPPETFILE_DIR:?}/"*

print_header 'Install Modules'
install_modules

print_header 'Module List'
puppet module list

print_header 'Done (install_modules.sh)'
