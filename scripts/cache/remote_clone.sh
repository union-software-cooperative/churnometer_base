#!/bin/bash
GT_HOST=${1:-$GT_PRODUCTION_HOST}
GT_PATH=${2:-$GT_PRODUCTION_PATH}
BKP_NAME=${3:-$(date +%Y%m%d%H%M%S)}

# Set working dir relative to script's location
cd "${0%/*}/../.."
mkdir -p ./app/backup/cache
ssh $GT_HOST $GT_PATH/scripts/cache/backup.sh $BKP_NAME
scp "${GT_HOST}:${GT_PATH}/app/backup/cache/${BKP_NAME}.tar.gz" ./app/backup/cache
