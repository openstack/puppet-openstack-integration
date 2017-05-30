#!/bin/bash

set -ex

if [ -n "${GEM_HOME}" ]; then
    GEM_BIN_DIR=${GEM_HOME}/bin/
    export PATH=${PATH}:${GEM_BIN_DIR}
fi

# NOTE(aschultz): since puppet 3 is now EOL, and beaker-puppet_install_helper
# version 0.6.0 has made the agent version the default, we need to symlink
# puppet to the /opt/puppetlabs version when specifically not version 3.
if [ "${PUPPET_MAJ_VERSION}" = 3 ]; then
  export PUPPET_BASE_PATH=/etc/puppet
else
  export PUPPET_BASE_PATH=/etc/puppetlabs/code
  export PATH=${PATH}:/opt/puppetlabs/bin
  # Workaround to deploy puppet for beaker jobs
  sudo -E ln -sfn /opt/puppetlabs/bin/puppet /usr/sbin/puppet
fi

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
export PUPPETFILE_DIR=${PUPPETFILE_DIR:-${PUPPET_BASE_PATH}/modules}
source $SCRIPT_DIR/functions

print_header 'Start (install_modules.sh)'
print_header 'Install r10k'
# fast_gettext 1.2.0+ requires ruby 2.1.0
gem install fast_gettext -v '< 1.2.0'
gem install r10k --no-ri --no-rdoc

# make sure there is no puppet module pre-installed
rm -rf "${PUPPETFILE_DIR:?}/"*

print_header 'Install Modules'
install_modules

print_header 'Module List'
puppet module list

print_header 'Done (install_modules.sh)'
