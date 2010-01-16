-- This is the SQL script for creating database schema for routing data.
--
-- Author: Minjie Zha
-- Date: 12/22/2009

DROP TABLE IF EXISTS routing;
CREATE TABLE routing (
    authority           REAL,
    hub                 REAL,
    authority_prime     REAL,
    hub_prime           REAL,
    is_supernode        INTEGER     -- 0 is false, 1 is true
);
-- insert the default row
INSERT INTO routing VALUES(1.0,1.0,1.0,1.0,0);

DROP TABLE IF EXISTS supernode_cache;
CREATE TABLE supernode_cache (
    guid            TEXT PRIMARY KEY NOT NULL,
    name            TEXT,
    authority       REAL,
    hub             REAL,
    score_a         REAL,
    score_h         REAL,
    latency         REAL,
    last_update     TEXT DEFAULT (datetime('now')),
    public_ip       TEXT,
    public_port     INTEGER,
    private_ip      TEXT,
    private_port    INTEGER
);

DROP TABLE IF EXISTS neighbor;
CREATE TABLE neighbor (
    guid                TEXT PRIMARY KEY NOT NULL,
    name                TEXT,
    authority           REAL,
    hub                 REAL,
    authority_prime     REAL,
    hub_prime           REAL,
    direction           INTEGER,        -- -1 for in, 0 for in-out, 1 for out
    last_update         TEXT DEFAULT (datetime('now'))
);
