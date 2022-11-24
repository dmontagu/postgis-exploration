#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "${PROJECT_ROOT}"

set -a
source scripts/psql.env

export PGPASSWORD=$(cat $PGPASSFILE)

rm -f services/database/data-transfer/raster-grayscale.hex
rm -f services/database/data-transfer/raster-grayscale.png
sleep 0.1

set -x
psql -U postgres -d app -h $PGHOST <<-EOSQL
    SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';
    COPY (
        SELECT encode(ST_AsPNG(ST_ColorMap(rast)), 'hex') AS png
        FROM $1
    ) TO '/data-transfer/raster-grayscale.hex';
EOSQL

xxd -p -r services/database/data-transfer/raster-grayscale.hex services/database/data-transfer/raster-grayscale.png

# The following line will only work on macos
# open services/database/data-transfer/raster-grayscale.png
