-- import with `.read db/schema.sql`

CREATE TABLE burr (
   sc_track_id    INT     PRIMARY KEY NOT NULL,
   title          TEXT    NOT NULL,
   link           TEXT    NOT NULL,
   created_ts     TEXT    NOT NULL,
   posted_ts      TEXT,
   reddit_post_id TEXT
);