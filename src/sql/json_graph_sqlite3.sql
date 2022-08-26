-- timestamp 2022-08-24 19:35:27 -0700
-- combining sql files from /Users/spuri/projects/per/simple-graph-rb/simple-graph/sql
-- schema.sql
CREATE TABLE IF NOT EXISTS nodes (
    body TEXT,
    id   TEXT GENERATED ALWAYS AS (json_extract(body, '$.id')) VIRTUAL NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS id_idx ON nodes(id);

CREATE TABLE IF NOT EXISTS edges (
    source     TEXT,
    target     TEXT,
    properties TEXT,
    UNIQUE(source, target, properties) ON CONFLICT REPLACE,
    FOREIGN KEY(source) REFERENCES nodes(id),
    FOREIGN KEY(target) REFERENCES nodes(id)
);

CREATE INDEX IF NOT EXISTS source_idx ON edges(source);
CREATE INDEX IF NOT EXISTS target_idx ON edges(target);


-- delete-edge.sql
DELETE FROM edges WHERE source = ? OR target = ?

-- delete-node.sql
DELETE FROM nodes WHERE id = ?

-- insert-edge.sql
INSERT INTO edges VALUES(?, ?, json(?))

-- insert-node.sql
INSERT INTO nodes VALUES(json(?))


-- search-edges-inbound.sql
SELECT * FROM edges WHERE source = ?

-- search-edges-outbound.sql
SELECT * FROM edges WHERE target = ?

-- search-edges.sql
SELECT * FROM edges WHERE source = ? 
UNION
SELECT * FROM edges WHERE target = ?

-- search-node-by-id.sql
SELECT body FROM nodes WHERE id = ?

-- search-node.sql
SELECT body FROM nodes WHERE 

-- traverse-inbound.sql
WITH RECURSIVE traverse(id) AS (
  SELECT :source
  UNION
  SELECT source FROM edges JOIN traverse ON target = id
) SELECT id FROM traverse;


-- traverse-outbound.sql
WITH RECURSIVE traverse(id) AS (
  SELECT :source
  UNION
  SELECT target FROM edges JOIN traverse ON source = id
) SELECT id FROM traverse;


-- traverse-with-bodies-inbound.sql
WITH RECURSIVE traverse(x, y, obj) AS (
  SELECT :source, '()', '{}'
  UNION
  SELECT id, '()', body FROM nodes JOIN traverse ON id = x
  UNION
  SELECT source, '<-', properties FROM edges JOIN traverse ON target = x
) SELECT x, y, obj FROM traverse;


-- traverse-with-bodies-outbound.sql
WITH RECURSIVE traverse(x, y, obj) AS (
  SELECT :source, '()', '{}'
  UNION
  SELECT id, '()', body FROM nodes JOIN traverse ON id = x
  UNION
  SELECT target, '->', properties FROM edges JOIN traverse ON source = x
) SELECT x, y, obj FROM traverse;


-- traverse-with-bodies.sql
WITH RECURSIVE traverse(x, y, obj) AS (
  SELECT :source, '()', '{}'
  UNION
  SELECT id, '()', body FROM nodes JOIN traverse ON id = x
  UNION
  SELECT source, '<-', properties FROM edges JOIN traverse ON target = x
  UNION
  SELECT target, '->', properties FROM edges JOIN traverse ON source = x
) SELECT x, y, obj FROM traverse;


-- traverse.sql
WITH RECURSIVE traverse(id) AS (
  SELECT :source
  UNION
  SELECT source FROM edges JOIN traverse ON target = id
  UNION
  SELECT target FROM edges JOIN traverse ON source = id
) SELECT id FROM traverse;


-- update-node.sql
UPDATE nodes SET body = json(?) WHERE id = ?

