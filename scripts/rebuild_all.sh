#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "${PROJECT_ROOT}"

./scripts/psql.sh -f sql/common/01_parameters.sql
./scripts/psql.sh -f sql/common/02_labeled_points.sql
./scripts/psql.sh -f sql/common/11_area_elevation.sql
./scripts/psql.sh -f sql/common/12_area_attributes.sql
./scripts/psql.sh -f sql/common/13_area_points.sql

./scripts/psql.sh -f sql/line_of_sight/line_of_sight.sql
./scripts/export-raster-color.sh line_of_sight
mv services/database/data-transfer/raster-color.png sql/line_of_sight/line_of_sight.png

./scripts/psql.sh -f sql/routing/routing.sql
./scripts/export-raster-color.sh routing
mv services/database/data-transfer/raster-color.png sql/routing/routing.png

# The following lines will only work on macos
open sql/line_of_sight/line_of_sight.png
open sql/routing/routing.png
