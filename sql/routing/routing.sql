-- Build the search graph
DROP TABLE IF EXISTS graph_edges;

WITH bounds AS (
    SELECT
        MIN(x) AS min_x,
        MIN(y) AS min_y,
        MAX(x) AS max_x,
        MAX(y) AS max_y
    FROM area_points
),
x_values AS (SELECT generate_series(min_x, max_x) AS x FROM bounds),
y_values AS (SELECT generate_series(min_y, max_y) AS y FROM bounds),
nodes AS (SELECT x, y FROM x_values CROSS JOIN y_values),
node_pairs AS (
    SELECT x AS x1, x - 1 AS x2, y AS y1, y - 1 AS y2 FROM nodes, bounds WHERE x > min_x AND y > min_y
    UNION ALL
    SELECT x AS x1, x - 1 AS x2, y AS y1, y     AS y2 FROM nodes, bounds WHERE x > min_x
    UNION ALL
    SELECT x AS x1, x - 1 AS x2, y AS y1, y + 1 AS y2 FROM nodes, bounds WHERE x > min_x AND y < max_y
    UNION ALL
    SELECT x AS x1, x     AS x2, y AS y1, y - 1 AS y2 FROM nodes, bounds WHERE y > min_y
    UNION ALL
    SELECT x AS x1, x     AS x2, y AS y1, y + 1 AS y2 FROM nodes, bounds WHERE y < max_y
    UNION ALL
    SELECT x AS x1, x + 1 AS x2, y AS y1, y - 1 AS y2 FROM nodes, bounds WHERE x < max_x AND y > min_y
    UNION ALL
    SELECT x AS x1, x + 1 AS x2, y AS y1, y     AS y2 FROM nodes, bounds WHERE x < max_x
    UNION ALL
    SELECT x AS x1, x + 1 AS x2, y AS y1, y + 1 AS y2 FROM nodes, bounds WHERE x < max_x AND y < max_y
),
edges AS (
    SELECT
        id,
        source,
        target,
        (
            distance +
            params.dz_cost_scale * abs(dz) +
            params.slope_cost_scale * distance * tan(radians((slope1 + slope2) / 2))
        ) AS cost
    FROM (
        SELECT
            row_number() OVER (ORDER BY x1, y1, x2, y2) AS id,
            p1.id                                       AS source,
            p2.id                                       AS target,
            p2.elevation - p1.elevation                 AS dz,
            p1.slope                                    AS slope1,
            p2.slope                                    AS slope2,
            ST_DistanceSphere(p1.geom, p2.geom)         AS distance
        FROM
            node_pairs np
                JOIN area_points p1 ON np.x1 = p1.x AND np.y1 = p1.y
                JOIN area_points p2 ON np.x2 = p2.x AND np.y2 = p2.y

        ) t, parameters params
)
SELECT *, cost AS reverse_cost
into graph_edges
FROM edges;

-- Perform the search
DROP TABLE IF EXISTS routing;

WITH path_endpoint_raster_coords as(
    SELECT label, (t.coord).columnx, (t.coord).rowy FROM (
        SELECT label, ST_WorldToRasterCoord(rast, lon, lat) AS coord
        FROM labeled_points, area_attributes
        WHERE label in ('deer recovered', 'car')
    ) t
),
path_endpoint_node_ids AS (
    SELECT a.id, b.label
    FROM area_points a
        JOIN path_endpoint_raster_coords b
            ON a.x = b.columnx AND a.y = b.rowy
),
path AS (
    SELECT *
    FROM pgr_bdDijkstra(
        'SELECT id, source, target, cost, reverse_cost FROM graph_edges',
        (SELECT id FROM path_endpoint_node_ids WHERE label = 'deer recovered'),
        (SELECT id FROM path_endpoint_node_ids WHERE label = 'car'),
        TRUE
    )
),
path_geom AS (
    SELECT
        ST_Collect(ST_MakeLine(c.geom, d.geom)) AS geom
    FROM
        path a
            JOIN graph_edges b ON a.edge = b.id
            JOIN area_points c ON b.source = c.id
            JOIN area_points d ON b.target = d.id
),
red_geom AS (
SELECT ST_Collect(geom) AS geom
FROM (
    -- Labeled points
    SELECT ST_Buffer(ST_Collect(geom), 0.0002) AS geom
    FROM labeled_points
    UNION
    -- 1km circle around the line-of-sight center
    SELECT ST_Buffer(geom, 0.0001) AS geom
    FROM path_geom
 ) t
)
SELECT
    ST_AddBand(
        ST_AddBand(
            ST_SetValues(
                ST_AddBand(
                    ST_MakeEmptyRaster(rast), 1, '8BUI', 1, 255
                ),
                1, ARRAY[(red_geom.geom, 0)]::geomval[]
            ),
            ST_Band(rast, 1)
        ),
            ST_Band(rast, 1)
    ) AS rast
INTO routing
FROM area_attributes, red_geom;
