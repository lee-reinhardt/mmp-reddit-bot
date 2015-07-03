-- import with `.read db/schema.sql`

CREATE TABLE burr (
    link              TEXT    PRIMARY KEY NOT NULL,
    title             TEXT    NOT NULL,
    info              TEXT    NOT NULL,
    created_ts        TEXT    NOT NULL,
    reddit_created_ts TEXT,
    reddit_id         TEXT,
    reddit_name       TEXT,
    reddit_link       TEXT
);