DROP TABLE IF EXISTS labeled_points;

WITH lat_lon AS (
    SELECT *
    FROM (
        VALUES
               (47.71343, -108.62708, 'glass'),
               (47.70829, -108.62513, 'deer spotted'),
               (47.70882, -108.62605, 'deer recovered'),
               (47.73461, -108.62893, 'car')
    ) AS t (lat, lon, label)
),
lat_lon_geom AS (
    SELECT *,
--            ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 4269) AS geom
           ST_SetSRID(ST_MakePoint(lon, lat), 4269) AS geom
    FROM lat_lon
)
SELECT a.*, b.rid, ST_Value(b.rast, a.geom) AS elevation
INTO labeled_points
FROM lat_lon_geom a, raw_elevation b
WHERE ST_Intersects(b.rast, a.geom);
