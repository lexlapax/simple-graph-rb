## -- timestamp 2022-09-15 21:18:51 -0700
## -- generated by running file sql/create_sql.rb
## -- combining sql files from simple-graph/sql
DELETE_EDGE="""
DELETE FROM edges WHERE source = ? OR target = ?
""".strip!

DELETE_NODE="""
DELETE FROM nodes WHERE id = ?
""".strip!

INSERT_EDGE="""
INSERT INTO edges VALUES(?, ?, json(?))
""".strip!

INSERT_NODE="""
INSERT INTO nodes VALUES(json(?))
""".strip!

SCHEMA="""
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
""".strip!

SEARCH_EDGES_INBOUND="""
SELECT * FROM edges WHERE source = ?
""".strip!

SEARCH_EDGES_OUTBOUND="""
SELECT * FROM edges WHERE target = ?
""".strip!

SEARCH_EDGES="""
SELECT * FROM edges WHERE source = ? 
UNION
SELECT * FROM edges WHERE target = ?
""".strip!

SEARCH_NODE_BY_ID="""
SELECT body FROM nodes WHERE id = ?
""".strip!

SEARCH_NODE="""
SELECT body FROM nodes WHERE 
""".strip!

TRAVERSE_INBOUND="""
WITH RECURSIVE traverse(id) AS (
  SELECT :source
  UNION
  SELECT source FROM edges JOIN traverse ON target = id
) SELECT id FROM traverse;
""".strip!

TRAVERSE_OUTBOUND="""
WITH RECURSIVE traverse(id) AS (
  SELECT :source
  UNION
  SELECT target FROM edges JOIN traverse ON source = id
) SELECT id FROM traverse;
""".strip!

TRAVERSE_WITH_BODIES_INBOUND="""
WITH RECURSIVE traverse(x, y, obj) AS (
  SELECT :source, '()', '{}'
  UNION
  SELECT id, '()', body FROM nodes JOIN traverse ON id = x
  UNION
  SELECT source, '<-', properties FROM edges JOIN traverse ON target = x
) SELECT x, y, obj FROM traverse;
""".strip!

TRAVERSE_WITH_BODIES_OUTBOUND="""
WITH RECURSIVE traverse(x, y, obj) AS (
  SELECT :source, '()', '{}'
  UNION
  SELECT id, '()', body FROM nodes JOIN traverse ON id = x
  UNION
  SELECT target, '->', properties FROM edges JOIN traverse ON source = x
) SELECT x, y, obj FROM traverse;
""".strip!

TRAVERSE_WITH_BODIES="""
WITH RECURSIVE traverse(x, y, obj) AS (
  SELECT :source, '()', '{}'
  UNION
  SELECT id, '()', body FROM nodes JOIN traverse ON id = x
  UNION
  SELECT source, '<-', properties FROM edges JOIN traverse ON target = x
  UNION
  SELECT target, '->', properties FROM edges JOIN traverse ON source = x
) SELECT x, y, obj FROM traverse;
""".strip!

TRAVERSE="""
WITH RECURSIVE traverse(id) AS (
  SELECT :source
  UNION
  SELECT source FROM edges JOIN traverse ON target = id
  UNION
  SELECT target FROM edges JOIN traverse ON source = id
) SELECT id FROM traverse;
""".strip!

UPDATE_NODE="""
UPDATE nodes SET body = json(?) WHERE id = ?
""".strip!

