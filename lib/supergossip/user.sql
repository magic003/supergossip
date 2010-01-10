-- This is the SQL script for creating database schema for user data.
-- 
-- Author: Minjie Zha
-- Date: 12/05/2009

-- user profile
DROP TABLE IF EXISTS user;
CREATE TABLE user (
    guid            TEXT PRIMARY KEY NOT NULL,
    name            TEXT,
    password        TEXT,
    register_date   TEXT DEFAULT (date('now'))
);

-- followings and followers
DROP TABLE IF EXISTS buddy;
CREATE TABLE buddy (
    guid            TEXT PRIMARY KEY NOT NULL,
    relationship    INTEGER     -- 1 is following, 2 is follower, 3 is both
);

-- direct messages
DROP TABLE IF EXISTS message;
CREATE TABLE message (
    id              INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    guid            TEXT NOT NULL,
    content         TEXT NOT NULL,
    direction       INTEGER,     -- 1 is from, 2 is to
    time            TEXT DEFAULT (datetime('now'))
);
