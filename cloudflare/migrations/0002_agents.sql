CREATE TABLE IF NOT EXISTS agents (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  glyph TEXT NOT NULL,
  tagline TEXT NOT NULL,
  category TEXT NOT NULL,
  color TEXT NOT NULL,
  people TEXT NOT NULL,
  last_message TEXT NOT NULL,
  opening_message TEXT NOT NULL,
  avatar_url TEXT,
  system_prompt TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);
