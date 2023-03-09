#!/bin/sh

BKP_NAME=${1:-$(date -I)}

# Set working dir relative to script's location
cd "${0%/*}/../.."

./scripts/db/table_to_csv.sh memberfact $BKP_NAME
./scripts/db/table_to_csv.sh transactionfact $BKP_NAME
./scripts/db/table_to_csv.sh displaytext $BKP_NAME
./scripts/db/table_to_csv.sh memberfacthelper $BKP_NAME
