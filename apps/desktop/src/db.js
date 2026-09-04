const path = require('path');
const fs = require('fs');
const { app } = require('electron');
const { DatabaseSync } = require('node:sqlite');
const { encrypt, decrypt } = require('./crypto');

let db;

const REQUIRED_SCHEMA = {
  settings: ['key', 'value'],
  accounts: ['id', 'email', 'display_name', 'photo_url', 'permission_id', 'access_token_enc', 'refresh_token_enc', 'expires_at', 'root_folder_id', 'quota_limit', 'quota_usage', 'connected_at'],
  virtual_folders: ['id', 'name', 'parent_id'],
  files: ['id', 'account_id', 'drive_file_id', 'name', 'mime_type', 'size', 'virtual_folder_id', 'drive_parent_id', 'modified_time', 'web_view_link', 'is_drive_folder', 'sync_path']
};

function initDb() {
  const dbPath = path.join(app.getPath('userData'), 'farooqdrive.sqlite');
  db = new DatabaseSync(dbPath);
  if (hasIncompatibleExistingSchema()) {
    db.close();
    const backupPath = path.join(app.getPath('userData'), `farooqdrive-legacy-${Date.now()}.sqlite`);
    fs.renameSync(dbPath, backupPath);
    db = new DatabaseSync(dbPath);
  }
  db.exec(`
    PRAGMA journal_mode=WAL;
    PRAGMA foreign_keys=ON;

    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT
    );

    CREATE TABLE IF NOT EXISTS accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL UNIQUE,
      display_name TEXT,
      photo_url TEXT,
      permission_id TEXT,
      access_token_enc TEXT NOT NULL,
      refresh_token_enc TEXT,
      expires_at INTEGER NOT NULL DEFAULT 0,
      root_folder_id TEXT,
      quota_limit INTEGER,
      quota_usage INTEGER NOT NULL DEFAULT 0,
      connected_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS virtual_folders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      parent_id INTEGER,
      UNIQUE(name, parent_id),
      FOREIGN KEY(parent_id) REFERENCES virtual_folders(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS files (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      drive_file_id TEXT NOT NULL,
      name TEXT NOT NULL,
      mime_type TEXT,
      size INTEGER NOT NULL DEFAULT 0,
      virtual_folder_id INTEGER,
      drive_parent_id TEXT,
      modified_time TEXT,
      web_view_link TEXT,
      is_drive_folder INTEGER NOT NULL DEFAULT 0,
      sync_path TEXT,
      UNIQUE(account_id, drive_file_id),
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE,
      FOREIGN KEY(virtual_folder_id) REFERENCES virtual_folders(id) ON DELETE SET NULL
    );
  `);
  migrateSettingsSchema();
  return db;
}

function hasIncompatibleExistingSchema() {
  const existing = new Set(db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(row => String(row.name)));
  return Object.entries(REQUIRED_SCHEMA).some(([table, required]) => {
    if (!existing.has(table)) return false;
    const info = db.prepare(`PRAGMA table_info("${table}")`).all();
    const columns = new Set(info.map(row => String(row.name)));
    if (required.some(column => !columns.has(column))) return true;
    return table === 'settings' && !info.some(row => row.name === 'key' && Number(row.pk) === 1);
  });
}

function migrateSettingsSchema() {
  const info = db.prepare('PRAGMA table_info(settings)').all();
  const columns = info.map(row => String(row.name));
  const canonical = columns.includes('key') && columns.includes('value') && info.some(row => row.name === 'key' && Number(row.pk) === 1);
  if (canonical) return;

  const keyColumn = ['key', 'setting_key', 'name', 'id'].find(name => columns.includes(name));
  const valueColumn = ['value', 'encrypted_value', 'setting_value', 'data', 'val'].find(name => columns.includes(name));
  const copySql = keyColumn && valueColumn
    ? `INSERT OR REPLACE INTO settings(key,value) SELECT CAST("${keyColumn}" AS TEXT), CAST("${valueColumn}" AS TEXT) FROM settings_legacy WHERE "${keyColumn}" IS NOT NULL`
    : '';

  db.exec('BEGIN IMMEDIATE');
  try {
    db.exec('DROP TABLE IF EXISTS settings_legacy');
    db.exec('ALTER TABLE settings RENAME TO settings_legacy');
    db.exec('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
    if (copySql) db.exec(copySql);
    db.exec('DROP TABLE settings_legacy');
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

function getDb() {
  if (!db) throw new Error('Database is not initialized.');
  return db;
}

function setSecret(key, value) {
  const enc = encrypt(value);
  getDb().prepare('INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value').run(key, enc);
}

function getSecret(key) {
  const row = getDb().prepare('SELECT value FROM settings WHERE key=?').get(key);
  return row?.value ? decrypt(row.value) : '';
}

function getOAuthConfig() {
  return {
    clientId: getSecret('google_client_id'),
    clientSecret: getSecret('google_client_secret')
  };
}

function saveOAuthConfig(clientId, clientSecret) {
  setSecret('google_client_id', clientId.trim());
  setSecret('google_client_secret', clientSecret.trim());
}

function listAccountsRaw() {
  return getDb().prepare('SELECT * FROM accounts ORDER BY connected_at ASC').all();
}

function listAccountsPublic() {
  return listAccountsRaw().map(a => ({
    id: Number(a.id),
    email: a.email,
    displayName: a.display_name || a.email,
    photoUrl: a.photo_url || '',
    quotaLimit: a.quota_limit === null ? null : Number(a.quota_limit),
    quotaUsage: Number(a.quota_usage || 0),
    free: a.quota_limit === null ? null : Math.max(0, Number(a.quota_limit) - Number(a.quota_usage || 0))
  }));
}

function getAccount(id) {
  const a = getDb().prepare('SELECT * FROM accounts WHERE id=?').get(id);
  if (!a) throw new Error('Google Drive account was not found.');
  return {
    ...a,
    id: Number(a.id),
    accessToken: decrypt(a.access_token_enc),
    refreshToken: decrypt(a.refresh_token_enc)
  };
}

function upsertAccount(profile, tokens, quota) {
  const now = Date.now();
  const existing = getDb().prepare('SELECT * FROM accounts WHERE email=?').get(profile.emailAddress);
  const refresh = tokens.refresh_token || (existing?.refresh_token_enc ? decrypt(existing.refresh_token_enc) : '');
  const root = existing?.root_folder_id || null;
  getDb().prepare(`
    INSERT INTO accounts(email,display_name,photo_url,permission_id,access_token_enc,refresh_token_enc,expires_at,root_folder_id,quota_limit,quota_usage,connected_at)
    VALUES(?,?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(email) DO UPDATE SET
      display_name=excluded.display_name,
      photo_url=excluded.photo_url,
      permission_id=excluded.permission_id,
      access_token_enc=excluded.access_token_enc,
      refresh_token_enc=excluded.refresh_token_enc,
      expires_at=excluded.expires_at,
      quota_limit=excluded.quota_limit,
      quota_usage=excluded.quota_usage
  `).run(
    profile.emailAddress,
    profile.displayName || profile.emailAddress,
    profile.photoLink || '',
    profile.permissionId || '',
    encrypt(tokens.access_token),
    encrypt(refresh),
    now + Number(tokens.expires_in || 3600) * 1000,
    root,
    quota.limit ?? null,
    quota.usage || 0,
    existing?.connected_at || now
  );
  return Number(getDb().prepare('SELECT id FROM accounts WHERE email=?').get(profile.emailAddress).id);
}

function updateAccountTokens(id, tokens) {
  const old = getAccount(id);
  const refresh = tokens.refresh_token || old.refreshToken || '';
  getDb().prepare('UPDATE accounts SET access_token_enc=?, refresh_token_enc=?, expires_at=? WHERE id=?').run(
    encrypt(tokens.access_token), encrypt(refresh), Date.now() + Number(tokens.expires_in || 3600) * 1000, id
  );
}

function updateQuota(id, quota) {
  getDb().prepare('UPDATE accounts SET quota_limit=?, quota_usage=? WHERE id=?').run(quota.limit ?? null, quota.usage || 0, id);
}

function updateRootFolder(id, rootId) {
  getDb().prepare('UPDATE accounts SET root_folder_id=? WHERE id=?').run(rootId, id);
}

function disconnectAccount(id) {
  getDb().prepare('DELETE FROM accounts WHERE id=?').run(id);
}

function listVirtualFolders() {
  return getDb().prepare('SELECT id,name,parent_id FROM virtual_folders ORDER BY name COLLATE NOCASE').all().map(r => ({
    id: Number(r.id), name: r.name, parentId: r.parent_id === null ? null : Number(r.parent_id)
  }));
}

function createVirtualFolder(name, parentId = null) {
  const clean = String(name || '').trim();
  if (!clean) throw new Error('Folder name is required.');
  const result = getDb().prepare('INSERT INTO virtual_folders(name,parent_id) VALUES(?,?)').run(clean, parentId || null);
  return Number(result.lastInsertRowid);
}

function ensureVirtualPath(parts) {
  let parentId = null;
  for (const raw of parts) {
    const name = String(raw || '').trim();
    if (!name) continue;
    let row;
    if (parentId === null) row = getDb().prepare('SELECT id FROM virtual_folders WHERE name=? AND parent_id IS NULL').get(name);
    else row = getDb().prepare('SELECT id FROM virtual_folders WHERE name=? AND parent_id=?').get(name, parentId);
    if (!row) {
      const result = getDb().prepare('INSERT INTO virtual_folders(name,parent_id) VALUES(?,?)').run(name, parentId);
      parentId = Number(result.lastInsertRowid);
    } else parentId = Number(row.id);
  }
  return parentId;
}

function listAllFiles() {
  return getDb().prepare(`SELECT f.*, a.email account_email FROM files f JOIN accounts a ON a.id=f.account_id WHERE f.is_drive_folder=0 ORDER BY f.name COLLATE NOCASE`).all().map(fileRowPublic);
}

function listFiles(folderId = null) {
  let rows;
  if (folderId === null || folderId === undefined) {
    rows = getDb().prepare(`SELECT f.*, a.email account_email FROM files f JOIN accounts a ON a.id=f.account_id WHERE f.virtual_folder_id IS NULL AND f.is_drive_folder=0 ORDER BY f.name COLLATE NOCASE`).all();
  } else {
    rows = getDb().prepare(`SELECT f.*, a.email account_email FROM files f JOIN accounts a ON a.id=f.account_id WHERE f.virtual_folder_id=? AND f.is_drive_folder=0 ORDER BY f.name COLLATE NOCASE`).all(folderId);
  }
  return rows.map(fileRowPublic);
}

function fileRowPublic(r) {
  return {
    id: Number(r.id), accountId: Number(r.account_id), driveFileId: r.drive_file_id, name: r.name,
    mimeType: r.mime_type || '', size: Number(r.size || 0), virtualFolderId: r.virtual_folder_id === null ? null : Number(r.virtual_folder_id),
    modifiedTime: r.modified_time || '', webViewLink: r.web_view_link || '', accountEmail: r.account_email || ''
  };
}

function getFile(id) {
  const r = getDb().prepare('SELECT * FROM files WHERE id=?').get(id);
  if (!r) throw new Error('File was not found.');
  return { ...r, id: Number(r.id), account_id: Number(r.account_id), size: Number(r.size || 0) };
}

function upsertFile(meta) {
  getDb().prepare(`
    INSERT INTO files(account_id,drive_file_id,name,mime_type,size,virtual_folder_id,drive_parent_id,modified_time,web_view_link,is_drive_folder,sync_path)
    VALUES(?,?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(account_id,drive_file_id) DO UPDATE SET
      name=excluded.name,mime_type=excluded.mime_type,size=excluded.size,drive_parent_id=excluded.drive_parent_id,
      modified_time=excluded.modified_time,web_view_link=excluded.web_view_link,is_drive_folder=excluded.is_drive_folder,
      sync_path=excluded.sync_path,
      virtual_folder_id=CASE WHEN files.virtual_folder_id IS NULL THEN excluded.virtual_folder_id ELSE files.virtual_folder_id END
  `).run(
    meta.accountId, meta.driveFileId, meta.name, meta.mimeType || '', meta.size || 0, meta.virtualFolderId ?? null,
    meta.driveParentId || null, meta.modifiedTime || null, meta.webViewLink || null, meta.isDriveFolder ? 1 : 0, meta.syncPath || null
  );
}

function removeFile(id) {
  getDb().prepare('DELETE FROM files WHERE id=?').run(id);
}

function renameLocalFile(id, name) {
  getDb().prepare('UPDATE files SET name=? WHERE id=?').run(name, id);
}

function moveLocalFile(id, folderId) {
  getDb().prepare('UPDATE files SET virtual_folder_id=? WHERE id=?').run(folderId ?? null, id);
}

function clearSyncedForAccount(accountId) {
  getDb().prepare('DELETE FROM files WHERE account_id=? AND sync_path IS NOT NULL').run(accountId);
}

module.exports = {
  initDb, getOAuthConfig, saveOAuthConfig, listAccountsRaw, listAccountsPublic, getAccount, upsertAccount,
  updateAccountTokens, updateQuota, updateRootFolder, disconnectAccount, listVirtualFolders, createVirtualFolder,
  ensureVirtualPath, listAllFiles, listFiles, getFile, upsertFile, removeFile, renameLocalFile, moveLocalFile, clearSyncedForAccount
};
