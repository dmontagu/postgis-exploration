DROP TABLE IF EXISTS area_points;

WITH elevation_data AS (
    SELECT (ST_PixelAsPoints(rast, 1)).*
    FROM area_attributes
),
aspect_data AS (
    SELECT (ST_PixelAsPoints(rast, 2)).*
    FROM area_attributes
),
slope_data AS (
    SELECT (ST_PixelAsPoints(rast, 3)).*
    FROM area_attributes
)
SELECT
    row_number() OVER (ORDER BY elevation_data.x, elevation_data.y) AS id,
    elevation_data.x,
    elevation_data.y,
    elevation_data.geom AS geom,
    ST_X(elevation_data.geom) AS lon_x,
    ST_Y(elevation_data.geom) AS lat_y,
    elevation_data.val AS elevation,
    aspect_data.val AS aspect,
    slope_data.val AS slope
INTO area_points
FROM elevation_data
    JOIN slope_data ON elevation_data.x = slope_data.x AND elevation_data.y = slope_data.y
    JOIN aspect_data ON elevation_data.x = aspect_data.x AND elevation_data.y = aspect_data.y;
