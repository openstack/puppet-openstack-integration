#!/bin/bash -ex

export SCRIPT_DIR=$(pwd)
export PUPPETFILE_DIR=${SCRIPT_DIR}/.modules

install_external() {
  PUPPETFILE=${SCRIPT_DIR}/Puppetfile1 ${GEM_HOME}/bin/r10k puppetfile install -v
}

install_openstack() {
  cat > clonemap.yaml <<EOF
clonemap:
  - name: '(.*?)/puppet-(.*)'
    dest: '$PUPPETFILE_DIR/\2'
EOF

  local project_names=$(awk '{ if ($1 == ":git") print $3 }' \
    ${SCRIPT_DIR}/Puppetfile0 | tr -d "'," | cut -d '/' -f 4- | xargs
  )
  /usr/zuul-env/bin/zuul-cloner -m clonemap.yaml \
    --cache-dir /opt/git \
    --zuul-ref $ZUUL_REF \
    --zuul-branch $ZUUL_BRANCH \
    --zuul-url $ZUUL_URL \
    git://git.openstack.org $project_names
}

install_all() {
  PUPPETFILE=${SCRIPT_DIR}/Puppetfile ${GEM_HOME}/bin/r10k puppetfile install -v
}

# If zuul-cloner is there, have it install modules using zuul refs
if [ -e /usr/zuul-env/bin/zuul-cloner ] ; then
  csplit ${SCRIPT_DIR}/Puppetfile /'External modules'/ \
    --prefix ${SCRIPT_DIR}/Puppetfile \
    --suffix '%d'
  install_external
  install_openstack
else
  install_all
fi

puppet module list --color=false
