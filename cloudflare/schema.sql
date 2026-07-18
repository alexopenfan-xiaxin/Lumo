CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  is_member INTEGER NOT NULL DEFAULT 0,
  role TEXT NOT NULL DEFAULT 'user',
  invitation_code TEXT UNIQUE,
  created_at INTEGER NOT NULL
);

CREATE TABLE invites (
  code TEXT PRIMARY KEY,
  created_by TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  used_by TEXT,
  used_at INTEGER
);

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE INDEX sessions_account ON sessions(account_id);

CREATE TABLE usage (
  subject TEXT NOT NULL,
  period TEXT NOT NULL,
  count INTEGER NOT NULL,
  PRIMARY KEY (subject, period)
);

CREATE TABLE agents (
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

CREATE TABLE agent_images (
  agent_id TEXT PRIMARY KEY,
  content_type TEXT NOT NULL,
  data BLOB NOT NULL,
  updated_at INTEGER NOT NULL
);
