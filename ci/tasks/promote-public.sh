#!/bin/bash

set -e # fail fast
set -x

TILE_NAME=${TILE_NAME:-dingo-backup-storage}
TILE_VERSION=$(cat tile-version/number)

filename=${TILE_NAME}-${TILE_VERSION}.pivotal

env
aws s3 ls $from_bucket
aws s3 cp s3://$from_bucket/$filename s3://$to_bucket/$filename
