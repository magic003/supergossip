-- This is the SQL script for creating database schema for routing data.
--
-- Author: Minjie Zha
-- Date: 12/22/2009

DROP TABLE IF EXISTS routing;
CREATE TABLE routing (
    authority       REAL,
    hub             REAL,
    authority_sum   REAL,
    hub_sum         REAL,
    is_supernode    INTEGER     -- 0 is false, 1 is true
);
-- insert the default row
INSERT INTO routing VALUES(1.0,1.0,1.0,1.0,0);

DROP TABLE IF EXISTS supernode_cache;
CREATE TABLE supernode_cache (
    guid        TEXT PRIMARY KEY NOT NULL,
    authority   REAL,
    hub         REAL,
    score_a     REAL,
    score_h     REAL,
    latency     INTEGER,
    last_update TEXT DEFAULT (datetime('now'))
);

DROP TABLE IF EXISTS neighbors;
CREATE TABLE neighbors (
    guid            TEXT PRIMARY KEY NOT NULL,
    authority       REAL,
    hub             REAL,
    authority_sum   REAL,
    hub_sum         REAL,
    direction       INTEGER,        -- -1 for in, 0 for in-out, 1 for out
    last_update     TEXT DEFAULT (datetime('now'))
);
