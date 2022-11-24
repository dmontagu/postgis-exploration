DROP TABLE IF EXISTS area_elevation;

WITH focus_area AS (
    SELECT ST_ConvexHull(ST_Collect(geom)) AS geom
    FROM labeled_points
),
focus_area_raster AS (
    SELECT ST_Union(e.rast) AS rast
    FROM raw_elevation e, focus_area r, parameters p
    WHERE ST_Intersects(e.rast, ST_Buffer(r.geom, p.region_padding))
)
SELECT ST_Clip(ar.rast, ST_Envelope(ST_Buffer(a.geom, p.region_padding)), TRUE) AS rast
INTO area_elevation
FROM focus_area_raster ar,focus_area a, parameters p;
