#!/bin/bash
GT_HOST=${1:-$GT_PRODUCTION_HOST}
GT_PATH=${2:-$GT_PRODUCTION_PATH}
BKP_NAME=$(date -I)

# Set working dir relative to script's location
cd "${0%/*}/../.."
ssh $GT_HOST $GT_PATH/scripts/db/backup.sh $BKP_NAME
scp "${GT_HOST}:${GT_PATH}/app/backup/${BKP_NAME}.sql.gz" ./app/backup/
