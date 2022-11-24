DROP TABLE IF EXISTS parameters;

SELECT *
INTO parameters
FROM (
    VALUES (0.015, 50.0, 1.0)
) AS t (region_padding, dz_cost_scale, slope_cost_scale);
