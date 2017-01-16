#!/bin/bash

set -e # fail fast
set -x # print commands

mkdir -p tile/tmp/metadata
mkdir -p workspace/metadata
mkdir -p workspace/releases
mkdir -p workspace/content_migrations # opsmgr v1.6
cp -r tile/migrations workspace/ # opsmgr v1.7

TILE_VERSION=$(cat tile-version/number)

cat pivnet-stemcell/metadata.json
STEMCELL_VERSION=$(cat pivnet-stemcell/metadata.json | jq -r ".Release.Version")

cat >tile/tmp/metadata/version.yml <<EOF
---
product_version: "${TILE_VERSION}"
stemcell_criteria:
  version: "${STEMCELL_VERSION}"
EOF

cat >tile/tmp/metadata/releases.yml <<YAML
---
releases:
YAML

# versions available via inputs
boshreleases=("vault" "broker-registrar")
for boshrelease in "${boshreleases[@]}"
do
  release_version=$(cat ${boshrelease}/version)
  cat >>tile/tmp/metadata/releases.yml <<YAML
  - name: ${boshrelease}
    file: ${boshrelease}-${release_version}.tgz
    version: "${release_version}"
YAML
  if [[ -f ${boshrelease}/release.tgz ]]; then
    cp ${boshrelease}/release.tgz workspace/releases/${boshrelease}-${release_version}.tgz
  fi
  if [[ -f ${boshrelease}/${boshrelease}-${release_version}.tgz ]]; then
    cp ${boshrelease}/${boshrelease}-${release_version}.tgz workspace/releases/
  fi
done

spruce merge --prune meta \
  tile/templates/metadata/base.yml \
  tile/templates/metadata/stemcell_criteria.yml \
  tile/tmp/metadata/version.yml \
  tile/tmp/metadata/releases.yml \
  tile/templates/metadata/form_types.yml \
  tile/templates/metadata/property_blueprints.yml \
  tile/templates/metadata/job_storage.yml \
    > workspace/metadata/dingo-backup-storage.yml


sed -i "s/RELEASE_VERSION_MARKER/${TILE_VERSION}/" workspace/metadata/dingo-backup-storage.yml

cat workspace/metadata/dingo-backup-storage.yml

cd workspace
ls -laR .

echo "creating dingo-backup-storage-${TILE_VERSION}.pivotal file"
zip -r dingo-backup-storage-${TILE_VERSION}.pivotal content_migrations migrations metadata releases

mv dingo-backup-storage-${TILE_VERSION}.pivotal ../product
ls ../product
