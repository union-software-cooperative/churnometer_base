#!/bin/sh
BKP_NAME=${1:-$(date +%Y%m%d%H%M%S)}

# Set working dir relative to script's location
cd "${0%/*}/../.."
mkdir -p ./app/backup/cache
tar -zcvf "app/backup/cache/$BKP_NAME.tar.gz" ./app/tmp/*.Marshal
