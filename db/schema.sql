-- import with `.read db/schema.sql`

CREATE TABLE burr (
   sc_track_id       INT     PRIMARY KEY NOT NULL,
   sc_created_ts     TEXT    NOT NULL,
   sc_title          TEXT    NOT NULL,
   burr_link         TEXT    NOT NULL,
   burr_info         TEXT    NOT NULL,
   reddit_created_ts TEXT,
   reddit_id         TEXT,
   reddit_name       TEXT,
   reddit_link       TEXT
);