FROM postgis/postgis:15-3.3

COPY ./01-init-db.sql /docker-entrypoint-initdb.d/01-init-db.sql
COPY ./11-init-postgis.sql /docker-entrypoint-initdb.d/11-init-postgis.sql

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    postgresql-$PG_MAJOR-pgrouting \
 && rm -rf /var/lib/apt/lists/* \
