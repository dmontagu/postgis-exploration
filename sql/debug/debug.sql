-- Metadata
SELECT (t.metadata).*
FROM (SELECT ST_MetaData(rast) AS metadata FROM area_attributes) t;

-- Summary stats
SELECT (t.stats).*
FROM (SELECT ST_SummaryStats(rast) AS stats FROM line_of_sight) t;

-- Values histogram
SELECT band, (stats).*
FROM (
    SELECT rid, band, ST_Histogram(rast, band) As stats
    FROM area_attributes CROSS JOIN generate_series(1,3) As band
) As foo;
