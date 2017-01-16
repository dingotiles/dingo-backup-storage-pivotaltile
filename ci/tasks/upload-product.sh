#!/bin/bash

set -x # print commands
set -e # fail fast

if [[ "${opsmgr_url}X" == "X" ]]; then
  echo "upload-product.sh requires \$opsmgr_url, \$opsmgr_username, \$opsmgr_password"
  exit 1
fi

tile_path=$(ls generated-tile/dingo-backup-storage*.pivotal)
ls -al ${tile_path}

insecure=
skip_ssl=
if [[ "${opsmgr_skip_ssl_verification}X" != "X" ]]; then
  insecure="-k"
  skip_ssl="--skip-ssl-validation"
fi

uaac target ${opsmgr_url}/uaa ${skip_ssl}
uaac token owner get opsman ${opsmgr_username} -s '' -p ${opsmgr_password}

access_token=$(uaac context admin | grep access_token | awk '{print $2}')

function info() {
  echo "$@ " >&2
}

function curl_auth() {
  info curl $@
  curl -f ${insecure} -H "Authorization: Bearer ${access_token}" $@
}

function curl_auth_quiet() {
  curl -sf ${insecure} -H "Authorization: Bearer ${access_token}" $@
}

set +x
curl_auth "${opsmgr_url}/api/v0/available_products"; echo
curl_auth "${opsmgr_url}/api/v0/staged/products"; echo
curl_auth "${opsmgr_url}/api/v0/deployed/products"; echo

echo "POST /api/v0/available_products -F 'product[file]=@${tile_path}'"
curl -f ${insecure} -H "Authorization: Bearer ${access_token}" \
  "${opsmgr_url}/api/v0/available_products" -X POST -F "product[file]=@${tile_path}"; echo

echo Getting $product_version from inside .pivotal zip file
zip_tile_path=generated-tile/dingo-backup-storage.zip
mv ${tile_path} ${zip_tile_path}
  unzip -u ${zip_tile_path} metadata/dingo-backup-storage.yml
  product_version=$(cat metadata/dingo-backup-storage.yml| yaml2json | jq -r .product_version)
  echo Installing product version $product_version
mv ${zip_tile_path} ${tile_path}

prev_version=$(curl_auth -s "${opsmgr_url}/api/v0/deployed/products" | jq -r ".[] | select(.type == \"dingo-backup-storage\")")

if [[ "${prev_version}X" == "X" ]]; then
  echo Adding product ${product_version} to the installation
  curl -f ${insecure} -H "Authorization: Bearer ${access_token}" \
    "${opsmgr_url}/api/v0/staged/products" -X POST \
      -d "name=dingo-backup-storage&product_version=${product_version}"
else
  echo Upgrading product to ${product_version}

  product_install_uuid=$(curl_auth -s "${opsmgr_url}/api/v0/staged/products" | jq -r ".[] | select(.type == \"dingo-backup-storage\") | .guid")
  curl_auth "${opsmgr_url}/api/v0/staged/products/${product_install_uuid}" -X PUT \
      -d "to_version=${product_version}"
fi
echo
product_install_uuid=$(curl_auth -s "${opsmgr_url}/api/v0/staged/products" | jq -r ".[] | select(.type == \"dingo-backup-storage\") | .guid")

echo "Installing product (guid ${product_install_uuid})"

echo "Running installation process"
response=$(curl -f ${insecure} -H "Authorization: Bearer ${access_token}" \
  "${opsmgr_url}/api/v0/installations" -d "ignore_warnings=1" -X POST)
installation_id=$(echo $response | jq -r .install.id)

set +x # silence print commands
status=running
prevlogslength=0
until [[ "${status}" != "running" ]]; do
  sleep 1
  status_json=$(curl_auth_quiet "${opsmgr_url}/api/v0/installations/${installation_id}")
  status=$(echo $status_json | jq -r .status)
  if [[ "${status}X" == "X" || "${status}" == "failed" ]]; then
    installation_exit=1
  fi

  logs=$(curl_auth_quiet ${opsmgr_url}/api/v0/installations/${installation_id}/logs | jq -r .logs)
  if [[ "${logs:${prevlogslength}}" != "" ]]; then
    echo "${logs:${prevlogslength}}"
    prevlogslength=${#logs}
  fi
done
echo $status_json

if [[ "${installation_exit}X" != "X" ]]; then
  exit ${installation_exit}
fi
