#!/bin/bash

GT_HOST=${1:-$GT_PRODUCTION_HOST}
GT_PATH=${2:-$GT_PRODUCTION_PATH}
BKP_NAME=${3:-$(date -I)}

# Set working dir relative to script's location
cd "${0%/*}/../.."
ssh $GT_HOST $GT_PATH/scripts/db/all_tables_to_csv.sh $BKP_NAME
/usr/bin/rsync -Phav "${GT_HOST}:${GT_PATH}/app/backup/${BKP_NAME}_*.csv.gz" ./app/backup/
