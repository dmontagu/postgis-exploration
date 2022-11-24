#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "${PROJECT_ROOT}"

set -a
source scripts/psql.env

export PGPASSWORD=$(cat $PGPASSFILE)

rm -f services/database/data-transfer/raster-color.hex
rm -f services/database/data-transfer/raster-color.png
sleep 0.1

set -x
psql -U postgres -d app -h $PGHOST <<-EOSQL
    SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';
    COPY (
        SELECT encode(
            ST_AsPNG(
                ST_AddBand(
                ST_AddBand(
                    ST_ColorMap(rast, 1),
                    ST_ColorMap(rast, 2)
                ),  ST_ColorMap(rast, 3)
                ),
                ARRAY[1, 2, 3]
            ),
            'hex'
        ) AS png
        FROM $1
    ) TO '/data-transfer/raster-color.hex';
EOSQL

xxd -p -r services/database/data-transfer/raster-color.hex services/database/data-transfer/raster-color.png

# The following line will only work on macos
# open services/database/data-transfer/raster-color.png
