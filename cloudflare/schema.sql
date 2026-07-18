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
