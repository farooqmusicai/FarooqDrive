PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT,
  display_name TEXT,
  avatar_url TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS app_secrets (
  name TEXT PRIMARY KEY,
  encrypted_value TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS drive_accounts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  google_sub TEXT NOT NULL,
  email TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  encrypted_refresh_token TEXT NOT NULL,
  root_folder_id TEXT,
  quota_limit TEXT,
  quota_usage TEXT NOT NULL DEFAULT '0',
  quota_usage_drive TEXT NOT NULL DEFAULT '0',
  last_synced_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, google_sub),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS virtual_folders (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  parent_id TEXT,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(parent_id) REFERENCES virtual_folders(id) ON DELETE CASCADE,
  UNIQUE(user_id, parent_id, name)
);
CREATE TABLE IF NOT EXISTS files (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  drive_account_id TEXT NOT NULL,
  google_file_id TEXT NOT NULL,
  virtual_folder_id TEXT,
  name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size_bytes TEXT NOT NULL DEFAULT '0',
  modified_time TEXT,
  web_view_link TEXT,
  icon_link TEXT,
  trashed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(drive_account_id, google_file_id),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(drive_account_id) REFERENCES drive_accounts(id) ON DELETE CASCADE,
  FOREIGN KEY(virtual_folder_id) REFERENCES virtual_folders(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_files_user_folder ON files(user_id, virtual_folder_id);
CREATE TABLE IF NOT EXISTS oauth_states (
  state TEXT PRIMARY KEY,
  purpose TEXT NOT NULL,
  user_id TEXT,
  completed_user_id TEXT,
  created_at INTEGER NOT NULL,
  completed_at INTEGER
);
