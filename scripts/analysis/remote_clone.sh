#!/bin/bash
GT_HOST=${1:-$GT_PRODUCTION_HOST}
GT_PATH=${2:=$GT_PRODUCTION_PATH}
BKP_NAME=${3:-$(date -I)_logs}

cd "${0%/*}/../.."
ssh $GT_HOST $GT_PATH/scripts/analysis/write_logs.sh $BKP_NAME
rsync -Phav "${GT_HOST}:${GT_PATH}/app/backup/${BKP_NAME}.txt" ./app/backup/
