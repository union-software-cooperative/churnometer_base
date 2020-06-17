#!/bin/sh
BKP_NAME=${1:-$(date -I)}

# Set working dir relative to script's location
cd "${0%/*}/../.."
docker-compose exec -T db su postgres -c "pg_dump -d churnometer" > app/backup/$BKP_NAME.sql
gzip app/backup/$BKP_NAME.sql
