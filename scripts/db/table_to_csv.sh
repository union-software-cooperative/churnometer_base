#!/bin/sh
TBL_NAME=${1:-memberfact}
BKP_NAME=${2:-$(date -I)}

# Set working dir relative to script's location
cd "${0%/*}/../.."
docker-compose exec -T db su postgres -c "psql -U churnometer -c \"COPY ${TBL_NAME} TO STDOUT DELIMITER ',' CSV HEADER;\"" > app/backup/${BKP_NAME}_${TBL_NAME}.csv

gzip app/backup/${BKP_NAME}_${TBL_NAME}.csv
