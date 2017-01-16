#!/bin/bash

set -x # print commands
set -e # fail fast

stemcell_path=$(ls pivnet-stemcell/*vsphere*)
ls -al ${stemcell_path}

insecure=
skip_ssl=
if [[ "${opsmgr_skip_ssl_verification}X" != "X" ]]; then
  insecure="-k"
  skip_ssl="--skip-ssl-validation"
fi

uaac target ${opsmgr_url}/uaa ${skip_ssl}
uaac token owner get opsman ${opsmgr_username} -s '' -p ${opsmgr_password}

access_token=$(uaac context admin | grep access_token | awk '{print $2}')

curl -f ${insecure} -H "Authorization: Bearer ${access_token}" \
  "${opsmgr_url}/api/v0/stemcells" -X POST -F "stemcell[file]=@${stemcell_path}"
