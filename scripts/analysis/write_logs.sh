#!/bin/bash
BKP_NAME=${1:-$(date -I)_logs}

# Move to root directory
cd "${0%/*}/../.."
# Initial write out of user access logs
docker-compose logs -t www | grep ".*Finished GET .* for user .*" | tee -a $BKP_NAME.txt

# Formatting, and removal of superfluous queries:
# Remove first 18 characters
sed -i 's/.\{18\}//' $BKP_NAME.txt
# Substitute unneeded text for separating commas
# Columns of data are: timestamp, request, requesting user
sed -i 's/ I.* Finished GET /,/' $BKP_NAME.txt
sed -i 's/ for user /,/' $BKP_NAME.txt
# Delete autocomplete API requests
sed -i '/autocomplete/d' $BKP_NAME.txt
# Delete oauth callbacks
sed -i '/oauth2-callback/d' $BKP_NAME.txt
# Delete homepage requests
sed -i '/\/,/d' $BKP_NAME.txt

# Change filetype to CSV and move to backups dir
mv $BKP_NAME.txt app/backup/$BKP_NAME.csv

gzip app/backup/$BKP_NAME.csv
