DROP TABLE IF EXISTS raycast_hit_multi_polygon;

WITH raycast_source AS (
    SELECT
        p.lon AS source_lon,
        p.lat AS source_lat,
        p.geom AS source_geom,
        ST_Value(rast, 1, geom) + 1 AS source_elevation -- +1 for height in seated position
    FROM labeled_points p, area_attributes
    WHERE p.label = 'glass'
),
target_region_params AS (
    SELECT
        distance,
        bearing
    FROM generate_series(31, 1031, 31) AS distance CROSS JOIN generate_series(1, 360, 2) AS bearing
),
target_region_geoms AS (
    SELECT
        target_region_params.*,
        ST_Project(raycast_source.source_geom, distance, radians(bearing))::geometry AS geom
    FROM target_region_params, raycast_source
),
target_regions AS (
    SELECT
        row_number() OVER (ORDER BY distance, bearing) AS id,
        target_region_geoms.distance,
        target_region_geoms.bearing,
        target_region_geoms.geom,
        ST_X(target_region_geoms.geom) AS lon_x,
        ST_Y(target_region_geoms.geom) AS lat_y,
        ST_Value(rast, 1, target_region_geoms.geom) AS elevation
    FROM target_region_geoms, area_attributes
),
target_region_voronois AS (
    SELECT (geom_dump).geom FROM (
        SELECT ST_Dump(
            ST_VoronoiPolygons(ST_Collect(ARRAY(SELECT geom FROM target_regions ORDER BY id)))
        ) AS geom_dump
    ) t
),

raycasts AS (
    SELECT
        id,
        geom,
        lon_x,
        lat_y,
        bearing,
        distance,
        degrees(atan((elevation - source_elevation) / distance)) AS pitch
    FROM target_regions, raycast_source
),
raycasts_augmented AS (
    SELECT *, max(pitch) OVER (PARTITION BY bearing ORDER BY distance) AS max_prior_pitch
    FROM raycasts
),
raycast_hit_points AS (
    SELECT ST_Collect(geom) as geom
    FROM raycasts_augmented
    WHERE
        pitch = max_prior_pitch
        AND distance < 1000 -- use this filter to exclude outer ring of voronois
)
SELECT ST_Collect(a.geom) AS geom
INTO raycast_hit_multi_polygon
FROM target_region_voronois a, raycast_hit_points b
WHERE ST_Intersects(a.geom, b.geom);

-----

DROP TABLE IF EXISTS line_of_sight;

WITH red_geom AS (
    -- This geometry is used to produce annotations in the final image
    SELECT ST_Collect(geom) AS geom
    FROM (
        -- Labeled points
        SELECT ST_Buffer(ST_Collect(geom), 0.0002) AS geom
        FROM labeled_points
        UNION
        -- 1km circle around the line-of-sight center
        SELECT ST_Buffer(ST_Transform(ST_Boundary(ST_Buffer(geom::geography, 1000)::geometry), 4269), 0.0001) AS geom
        FROM labeled_points
        WHERE label = 'glass'
     ) t
)
SELECT
    ST_AddBand(
        ST_AddBand(
            -- red is the red_geom's intersection with the raster
            ST_SetValues(
                ST_AddBand(
                    ST_MakeEmptyRaster(rast), 1, '8BUI', 1, 255
                ),
                1, ARRAY[(red_geom.geom, 0)]::geomval[]
            ),
            -- green is the original elevation data
            ST_Band(rast, 1)
        ),
        ST_SetValues(
            -- blue is the line-of-sight multi polygon
            ST_AddBand(
                ST_MakeEmptyRaster(rast), 1, '8BUI', 1, 255
            ),
            1, ARRAY[(raycast_hit_multi_polygon.geom, 0)]::geomval[]
        )
    ) AS rast
INTO line_of_sight
FROM area_attributes, raycast_hit_multi_polygon, red_geom;
