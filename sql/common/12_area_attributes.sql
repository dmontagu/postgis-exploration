DROP TABLE IF EXISTS area_attributes;

SELECT
    ST_AddBand(
    ST_AddBand(
        rast,
        ST_Aspect(rast)
    ),  ST_Slope(rast, 1, '32BF', 'DEGREES', 111120)
    ) AS rast
INTO area_attributes
FROM area_elevation;
