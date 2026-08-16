PRAGMA foreign_keys = OFF;

CREATE TABLE boards (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at INTEGER NULL
);

CREATE TABLE board_columns (
  id TEXT NOT NULL PRIMARY KEY,
  board_id TEXT NOT NULL REFERENCES boards(id),
  title TEXT NOT NULL,
  rank REAL NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at INTEGER NULL
);

CREATE TABLE cards (
  id TEXT NOT NULL PRIMARY KEY,
  board_id TEXT NOT NULL REFERENCES boards(id),
  column_id TEXT NOT NULL REFERENCES board_columns(id),
  title TEXT NOT NULL,
  description TEXT NULL,
  rank REAL NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at INTEGER NULL
);

CREATE TABLE notes (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL DEFAULT '',
  content_json TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at INTEGER NULL
);

CREATE TABLE attachments (
  id TEXT NOT NULL PRIMARY KEY,
  parent_type TEXT NOT NULL,
  parent_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  local_path TEXT NOT NULL,
  remote_path TEXT NULL,
  mime_type TEXT NULL,
  size_bytes INTEGER NOT NULL,
  checksum TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at INTEGER NULL
);

CREATE TABLE reminders (
  id TEXT NOT NULL PRIMARY KEY,
  parent_type TEXT NOT NULL,
  parent_id TEXT NOT NULL,
  title TEXT NOT NULL,
  scheduled_at_utc INTEGER NOT NULL,
  time_zone_id TEXT NOT NULL,
  notification_id INTEGER NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at INTEGER NULL
);

CREATE TABLE sync_queue (
  operation_id TEXT NOT NULL PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  base_version INTEGER NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at INTEGER NOT NULL,
  next_attempt_at INTEGER NULL,
  last_error TEXT NULL
);

PRAGMA user_version = 1;
PRAGMA foreign_keys = ON;
