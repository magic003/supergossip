-- This is the SQL script for creating database schema for user data.
-- 
-- Author: Minjie Zha
-- Date: 12/05/2009

DROP TABLE IF EXISTS user;
CREATE TABLE user (
    guid            TEXT PRIMARY KEY NOT NULL,
    name            TEXT,
    password        TEXT,
    register_date   TEXT DEFAULT (date('now'))
);
