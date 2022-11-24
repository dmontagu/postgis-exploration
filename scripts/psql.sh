#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "${PROJECT_ROOT}"

set -a
source scripts/psql.env

export PGPASSWORD=$(cat $PGPASSFILE)

set -x
psql -U postgres -d app -h $PGHOST $@
