#!/bin/bash

set -ex

GEM_INSTALL_CMD="gem install --no-user-install --minimal-deps --verbose --no-document"

if [ -n "${GEM_HOME}" ]; then
    GEM_BIN_DIR=${GEM_HOME}/bin/
    export PATH=${PATH}:${GEM_BIN_DIR}
    GEM_INSTALL_CMD="${GEM_INSTALL_CMD} --install-dir=$GEM_HOME --bindir=${GEM_BIN_DIR}"
fi

# NOTE(aschultz): since puppet 3 is now EOL, and beaker-puppet_install_helper
# version 0.6.0 has made the agent version the default, we need to symlink
# puppet to the /opt/puppetlabs version when specifically not version 3.
if [ -e /opt/puppetlabs/bin/puppet ]; then
    export PUPPET_BASE_PATH=/etc/puppetlabs/code
    export PATH=${PATH}:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin
    sudo -E ln -sfn /opt/puppetlabs/bin/puppet /usr/sbin/puppet
fi

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
export PUPPETFILE_DIR=${PUPPETFILE_DIR:-${PUPPET_BASE_PATH}/modules}
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
