CREATE TABLE IF NOT EXISTS agent_images (
  agent_id TEXT PRIMARY KEY,
  content_type TEXT NOT NULL,
  data BLOB NOT NULL,
  updated_at INTEGER NOT NULL
);
