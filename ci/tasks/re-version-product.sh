#!/bin/bash

set -e # fail fast
set -x # show commands

next_tile_version=$(cat tile-version/number)

tile_path=$(pwd)/$(ls generated-tile/dingo-backup-storage*.pivotal)
next_tile_path=$(pwd)/reversioned-product/dingo-backup-storage-${next_tile_version}.pivotal

zip_tile_path=$(pwd)/generated-tile/dingo-backup-storage.zip
mv ${tile_path} ${zip_tile_path}
unzip -u ${zip_tile_path} -d unpack
TILE_VERSION=$(cat unpack/metadata/dingo-backup-storage.yml| yaml2json | jq -r .product_version)
echo "Previous version $TILE_VERSION; re-versioning to $next_tile_version"

echo Updating metadata/dingo-backup-storage.yml
sed -i -e "s/^product_version:.*$/product_version: \"${next_tile_version}\"/" unpack/metadata/dingo-backup-storage.yml
cat unpack/metadata/dingo-backup-storage.yml

cd unpack
zip -r -f ${zip_tile_path} *

unzip -l ${zip_tile_path}

mv ${zip_tile_path} ${next_tile_path}

ls -al ${next_tile_path}
