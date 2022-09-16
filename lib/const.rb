GRAPH_SCHEMA="""
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
"""

INSERT_NODE="INSERT INTO nodes VALUES(json(?))"
UPDATE_NODE="UPDATE nodes SET body = json(?) WHERE id = ?"
DELETE_NODE="DELETE FROM nodes WHERE id = ?"

INSERT_EDGE="INSERT INTO edges VALUES(?, ?, json(?))"
DELETE_EDGE_SQL="DELETE FROM edges WHERE source = ? OR target = ?"

SEARCH_NODE_ID="SELECT body FROM nodes WHERE id = ?"
SEARCH_NODE="SELECT body FROM nodes WHERE "

SEARCH_EDGE_IB="SELECT * FROM edges WHERE source = ?"
SEARCH_EDGE_OB="SELECT * FROM edges WHERE target = ?"
SEARCH_EDGES="""
SELECT * FROM edges WHERE source = ? 
UNION
SELECT * FROM edges WHERE target = ?
"""

TRAVERSE_IB="""
WITH RECURSIVE traverse(id) AS (
  SELECT :source
  UNION
  SELECT source FROM edges JOIN traverse ON target = id
) SELECT id FROM traverse;
"""

TRAVERSE_OB="""
WITH RECURSIVE traverse(id) AS (
  SELECT :source
  UNION
  SELECT target FROM edges JOIN traverse ON source = id
) SELECT id FROM traverse;
"""

TRAVERSE_BODIES_IB="""
WITH RECURSIVE traverse(x, y, obj) AS (
  SELECT :source, '()', '{}'
  UNION
  SELECT id, '()', body FROM nodes JOIN traverse ON id = x
  UNION
  SELECT source, '<-', properties FROM edges JOIN traverse ON target = x
) SELECT x, y, obj FROM traverse;
"""

TRAVERSE_BODIES_OB="""
WITH RECURSIVE traverse(x, y, obj) AS (
  SELECT :source, '()', '{}'
  UNION
  SELECT id, '()', body FROM nodes JOIN traverse ON id = x
  UNION
  SELECT target, '->', properties FROM edges JOIN traverse ON source = x
) SELECT x, y, obj FROM traverse;
"""

TRAVERSE_BODIES="""
WITH RECURSIVE traverse(x, y, obj) AS (
  SELECT :source, '()', '{}'
  UNION
  SELECT id, '()', body FROM nodes JOIN traverse ON id = x
  UNION
  SELECT source, '<-', properties FROM edges JOIN traverse ON target = x
  UNION
  SELECT target, '->', properties FROM edges JOIN traverse ON source = x
) SELECT x, y, obj FROM traverse;
"""

TRAVERSE="""
WITH RECURSIVE traverse(id) AS (
  SELECT :source
  UNION
  SELECT source FROM edges JOIN traverse ON target = id
  UNION
  SELECT target FROM edges JOIN traverse ON source = id
) SELECT id FROM traverse;
"""
