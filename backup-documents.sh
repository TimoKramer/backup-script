#!/bin/bash

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
set -o xtrace

source ./backup-config.sh

# Init the folder structure
mkdir -p ${SNAPSHOT_DIR} ${ARCHIVES_DIR} &> /dev/null

# retrieve files to create snapshots with RSYNC.
# hard-linking snapshots to have history in each archive
rsync --hard-links --archive --compress --link-dest=${CURRENT_LINK} ${LOCAL_SOURCE} ${SNAPSHOT_DIR}/${NOW} \
  && ln -snf $(ls -1d ${SNAPSHOT_DIR}/* | tail -n1) ${CURRENT_LINK}

# create archive from snapshots
tar -czf ${ARCHIVES_DIR}/${NOW}.tar.gz ${SNAPSHOT_DIR}/*

# encrypt the archive
# key-id with gpg --list-keys --keyid-format SHORT
gpg --encrypt --symmetric --quiet --recipient ${EMAIL} --local-user ${GPG_KEY_ID} ${ARCHIVES_DIR}/${NOW}.tar.gz \
  && rm -rf ${ARCHIVES_DIR}/${NOW}.tar.gz

if [ $(ls -d ${ARCHIVES_DIR}/*.tar.gz 2> /dev/null | wc -l) == "0" ]
then
 rsync --progress -zarv -e "ssh -i ${SSH_KEY}" ${ARCHIVES_DIR} ${REMOTE_DESTINATION}
else
  echo "There are unencrypted files, cannot sync to remote"
  exit 1
fi
