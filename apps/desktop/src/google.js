const http = require('http');
const https = require('https');
const fs = require('fs');
const crypto = require('crypto');
const { shell } = require('electron');
const db = require('./db');

const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive';
const SCOPES = ['openid', 'email', 'profile', DRIVE_SCOPE].join(' ');

function b64url(buf) {
  return Buffer.from(buf).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

async function jsonFetch(url, options = {}) {
  const res = await fetch(url, options);
  const text = await res.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  if (!res.ok) {
    const msg = body?.error?.message || body?.error_description || body?.error || text || `${res.status} ${res.statusText}`;
    throw new Error(`Google API ${res.status}: ${msg}`);
  }
  return body;
}

async function startOAuth() {
  const cfg = db.getOAuthConfig();
  if (!cfg.clientId || !cfg.clientSecret) throw new Error('Add your Google OAuth Client ID and Client Secret in Settings first.');

  const verifier = b64url(crypto.randomBytes(48));
  const challenge = b64url(crypto.createHash('sha256').update(verifier).digest());
  const state = b64url(crypto.randomBytes(24));

  return await new Promise((resolve, reject) => {
    const server = http.createServer(async (req, res) => {
      try {
        const url = new URL(req.url, 'http://127.0.0.1');
        if (url.pathname !== '/oauth2/callback') {
          res.writeHead(404).end('Not found');
          return;
        }
        if (url.searchParams.get('state') !== state) throw new Error('OAuth state validation failed.');
        const err = url.searchParams.get('error');
        if (err) throw new Error(`Google authorization failed: ${err}`);
        const code = url.searchParams.get('code');
        if (!code) throw new Error('Google did not return an authorization code.');

        const redirectUri = `http://127.0.0.1:${server.address().port}/oauth2/callback`;
        const tokenBody = new URLSearchParams({
          code, client_id: cfg.clientId, client_secret: cfg.clientSecret,
          redirect_uri: redirectUri, grant_type: 'authorization_code', code_verifier: verifier
        });
        const tokens = await jsonFetch('https://oauth2.googleapis.com/token', {
          method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: tokenBody
        });

        const about = await jsonFetch('https://www.googleapis.com/drive/v3/about?fields=user(displayName,emailAddress,photoLink,permissionId),storageQuota(limit,usage)', {
          headers: { Authorization: `Bearer ${tokens.access_token}` }
        });
        const quota = normalizeQuota(about.storageQuota || {});
        const accountId = db.upsertAccount(about.user || {}, tokens, quota);
        await ensureRootFolder(accountId);

        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end('<!doctype html><meta charset="utf-8"><title>FarooqDrive connected</title><style>body{font:16px Segoe UI,Arial;background:#0b1220;color:#fff;display:grid;place-items:center;height:100vh;margin:0}.c{max-width:520px;padding:32px;background:#111b2e;border-radius:18px}h1{margin-top:0;color:#7dd3fc}</style><div class="c"><h1>FarooqDrive connected</h1><p>Authorization is complete. You can close this browser tab and return to FarooqDrive.</p></div>');
        setTimeout(() => server.close(), 300);
        resolve(accountId);
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end(e.message);
        setTimeout(() => server.close(), 300);
        reject(e);
      }
    });

    server.on('error', reject);
    server.listen(0, '127.0.0.1', async () => {
      const port = server.address().port;
      const redirectUri = `http://127.0.0.1:${port}/oauth2/callback`;
      const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
      authUrl.searchParams.set('client_id', cfg.clientId);
      authUrl.searchParams.set('redirect_uri', redirectUri);
      authUrl.searchParams.set('response_type', 'code');
      authUrl.searchParams.set('scope', SCOPES);
      authUrl.searchParams.set('access_type', 'offline');
      authUrl.searchParams.set('prompt', 'consent select_account');
      authUrl.searchParams.set('state', state);
      authUrl.searchParams.set('code_challenge', challenge);
      authUrl.searchParams.set('code_challenge_method', 'S256');
      try { await shell.openExternal(authUrl.toString()); }
      catch (e) { server.close(); reject(e); }
    });
  });
}

function normalizeQuota(q) {
  const limit = q.limit === undefined ? null : Number(q.limit);
  const usage = Number(q.usage || 0);
  return { limit: Number.isFinite(limit) ? limit : null, usage: Number.isFinite(usage) ? usage : 0 };
}

async function validAccessToken(accountId) {
  let account = db.getAccount(accountId);
  if (account.expires_at && Number(account.expires_at) > Date.now() + 60000 && account.accessToken) return account.accessToken;
  if (!account.refreshToken) throw new Error(`Reconnect ${account.email} because no refresh token is available.`);
  const cfg = db.getOAuthConfig();
  const body = new URLSearchParams({
    client_id: cfg.clientId, client_secret: cfg.clientSecret, refresh_token: account.refreshToken, grant_type: 'refresh_token'
  });
  const tokens = await jsonFetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body
  });
  db.updateAccountTokens(accountId, tokens);
  return tokens.access_token;
}

async function driveJson(accountId, path, options = {}) {
  const token = await validAccessToken(accountId);
  const headers = { ...(options.headers || {}), Authorization: `Bearer ${token}` };
  if (options.body && typeof options.body === 'string' && !headers['Content-Type']) headers['Content-Type'] = 'application/json';
  return jsonFetch(`https://www.googleapis.com${path}`, { ...options, headers });
}

async function refreshQuota(accountId) {
  const about = await driveJson(accountId, '/drive/v3/about?fields=storageQuota(limit,usage)');
  const quota = normalizeQuota(about.storageQuota || {});
  db.updateQuota(accountId, quota);
  return quota;
}

async function ensureRootFolder(accountId) {
  const account = db.getAccount(accountId);
  if (account.root_folder_id) return account.root_folder_id;
  const q = encodeURIComponent("name='Farooqdrive' and mimeType='application/vnd.google-apps.folder' and 'root' in parents and trashed=false");
  const found = await driveJson(accountId, `/drive/v3/files?q=${q}&fields=files(id,name)&spaces=drive&pageSize=10`);
  let rootId = found.files?.[0]?.id;
  if (!rootId) {
    const created = await driveJson(accountId, '/drive/v3/files?fields=id', {
      method: 'POST', body: JSON.stringify({ name: 'Farooqdrive', mimeType: 'application/vnd.google-apps.folder', parents: ['root'] })
    });
    rootId = created.id;
  }
  db.updateRootFolder(accountId, rootId);
  return rootId;
}

async function chooseUploadAccount(size) {
  const accounts = db.listAccountsRaw();
  if (!accounts.length) throw new Error('Connect at least one Google Drive account first.');
  for (const a of accounts) {
    try { await refreshQuota(Number(a.id)); } catch { /* keep last known quota */ }
  }
  const fresh = db.listAccountsRaw().map(a => ({
    id: Number(a.id), email: a.email, limit: a.quota_limit === null ? null : Number(a.quota_limit), usage: Number(a.quota_usage || 0)
  }));
  const candidates = fresh.filter(a => a.limit === null || Math.max(0, a.limit - a.usage) >= size);
  if (!candidates.length) throw new Error('No connected Google Drive account has enough free space for this file.');
  candidates.sort((a, b) => {
    const af = a.limit === null ? Number.MAX_SAFE_INTEGER : a.limit - a.usage;
    const bf = b.limit === null ? Number.MAX_SAFE_INTEGER : b.limit - b.usage;
    return bf - af;
  });
  return candidates[0];
}

async function createResumableSession(accountId, name, mimeType, size, parentId) {
  const token = await validAccessToken(accountId);
  const res = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,name,mimeType,size,modifiedTime,webViewLink,parents', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json; charset=UTF-8',
      'X-Upload-Content-Type': mimeType || 'application/octet-stream',
      'X-Upload-Content-Length': String(size)
    },
    body: JSON.stringify({ name, parents: [parentId] })
  });
  const text = await res.text();
  if (!res.ok) {
    let msg = text; try { msg = JSON.parse(text)?.error?.message || text; } catch {}
    throw new Error(`Google upload session ${res.status}: ${msg}`);
  }
  const location = res.headers.get('location');
  if (!location) throw new Error('Google did not return a resumable upload URL.');
  return location;
}

async function putFileToSession(sessionUrl, filePath, mimeType, size, onProgress) {
  return await new Promise((resolve, reject) => {
    const u = new URL(sessionUrl);
    const req = https.request({
      method: 'PUT', hostname: u.hostname, path: u.pathname + u.search,
      headers: { 'Content-Type': mimeType || 'application/octet-stream', 'Content-Length': String(size) }
    }, res => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', c => data += c);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try { resolve(data ? JSON.parse(data) : {}); } catch { resolve({}); }
        } else reject(new Error(`Google upload ${res.statusCode}: ${data || res.statusMessage}`));
      });
    });
    req.on('error', reject);
    let sent = 0;
    const stream = fs.createReadStream(filePath);
    stream.on('data', chunk => {
      sent += chunk.length;
      if (onProgress) onProgress(Math.min(100, Math.round((sent / size) * 100)));
    });
    stream.on('error', reject);
    stream.pipe(req);
  });
}

async function uploadFile(filePath, virtualFolderId, onProgress) {
  const stat = fs.statSync(filePath);
  if (!stat.isFile()) throw new Error('Selected item is not a file.');
  const name = require('path').basename(filePath);
  const mimeType = guessMime(name);
  const target = await chooseUploadAccount(stat.size);
  const rootId = await ensureRootFolder(target.id);
  const sessionUrl = await createResumableSession(target.id, name, mimeType, stat.size, rootId);
  const meta = await putFileToSession(sessionUrl, filePath, mimeType, stat.size, onProgress);
  db.upsertFile({
    accountId: target.id, driveFileId: meta.id, name: meta.name || name, mimeType: meta.mimeType || mimeType,
    size: Number(meta.size || stat.size), virtualFolderId: virtualFolderId ?? null, driveParentId: rootId,
    modifiedTime: meta.modifiedTime || new Date().toISOString(), webViewLink: meta.webViewLink || '', syncPath: null
  });
  await refreshQuota(target.id);
  return { accountEmail: target.email, name };
}

function guessMime(name) {
  const ext = name.toLowerCase().split('.').pop();
  const map = { pdf:'application/pdf', txt:'text/plain', jpg:'image/jpeg', jpeg:'image/jpeg', png:'image/png', gif:'image/gif', webp:'image/webp', mp3:'audio/mpeg', wav:'audio/wav', mp4:'video/mp4', mov:'video/quicktime', zip:'application/zip', json:'application/json', csv:'text/csv', docx:'application/vnd.openxmlformats-officedocument.wordprocessingml.document', xlsx:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' };
  return map[ext] || 'application/octet-stream';
}

async function listChildren(accountId, parentId) {
  let pageToken = '';
  const all = [];
  do {
    const q = encodeURIComponent(`'${parentId}' in parents and trashed=false`);
    const tokenPart = pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : '';
    const data = await driveJson(accountId, `/drive/v3/files?q=${q}&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink,parents)&spaces=drive&pageSize=1000${tokenPart}`);
    all.push(...(data.files || []));
    pageToken = data.nextPageToken || '';
  } while (pageToken);
  return all;
}

async function browseFolder(accountId, parentId = 'root') {
  const q = encodeURIComponent(`'${parentId}' in parents and trashed=false`);
  const data = await driveJson(accountId, `/drive/v3/files?q=${q}&fields=files(id,name,mimeType,size,modifiedTime,webViewLink,parents,capabilities)&spaces=drive&pageSize=1000&orderBy=folder,name`);
  return (data.files || []).map(f => ({
    id: f.id, name: f.name, mimeType: f.mimeType || '', size: Number(f.size || 0),
    modifiedTime: f.modifiedTime || '', webViewLink: f.webViewLink || '',
    parents: f.parents || [], isFolder: f.mimeType === 'application/vnd.google-apps.folder',
    accountId, capabilities: f.capabilities || {}
  }));
}

async function createDriveFolder(accountId, parentId, name) {
  if (!String(name || '').trim()) throw new Error('Folder name is required.');
  return driveJson(accountId, '/drive/v3/files?fields=id,name,mimeType,parents', {
    method: 'POST', body: JSON.stringify({ name: String(name).trim(), mimeType: 'application/vnd.google-apps.folder', parents: [parentId] })
  });
}

async function moveDriveFile(accountId, fileId, oldParents, newParentId) {
  const remove = encodeURIComponent((oldParents || []).join(','));
  return driveJson(accountId, `/drive/v3/files/${encodeURIComponent(fileId)}?addParents=${encodeURIComponent(newParentId)}&removeParents=${remove}&fields=id,parents`, { method: 'PATCH' });
}

async function copyDriveFile(accountId, fileId, parentId, name) {
  return driveJson(accountId, `/drive/v3/files/${encodeURIComponent(fileId)}/copy?fields=id,name,parents`, {
    method: 'POST', body: JSON.stringify({ parents: [parentId], ...(name ? { name } : {}) })
  });
}

async function trashDriveFile(accountId, fileId) {
  return driveJson(accountId, `/drive/v3/files/${encodeURIComponent(fileId)}?fields=id,trashed`, {
    method: 'PATCH', body: JSON.stringify({ trashed: true })
  });
}

async function syncAccount(accountId) {
  const rootId = await ensureRootFolder(accountId);
  const queue = [{ id: rootId, path: [] }];
  let count = 0;
  while (queue.length) {
    const current = queue.shift();
    const children = await listChildren(accountId, current.id);
    for (const item of children) {
      if (item.mimeType === 'application/vnd.google-apps.folder') {
        queue.push({ id: item.id, path: [...current.path, item.name] });
        continue;
      }
      const folderId = db.ensureVirtualPath(current.path);
      db.upsertFile({
        accountId, driveFileId: item.id, name: item.name, mimeType: item.mimeType || '', size: Number(item.size || 0),
        virtualFolderId: folderId, driveParentId: item.parents?.[0] || current.id, modifiedTime: item.modifiedTime || '',
        webViewLink: item.webViewLink || '', isDriveFolder: false, syncPath: current.path.join('/') || '/'
      });
      count++;
    }
  }
  await refreshQuota(accountId);
  return count;
}

async function syncAll() {
  let total = 0;
  for (const a of db.listAccountsRaw()) total += await syncAccount(Number(a.id));
  return total;
}

async function renameFile(fileId, newName) {
  const file = db.getFile(fileId);
  const clean = String(newName || '').trim();
  if (!clean) throw new Error('File name is required.');
  await driveJson(file.account_id, `/drive/v3/files/${encodeURIComponent(file.drive_file_id)}?fields=id,name`, {
    method: 'PATCH', body: JSON.stringify({ name: clean })
  });
  db.renameLocalFile(fileId, clean);
}

async function deleteFile(fileId) {
  const file = db.getFile(fileId);
  await driveJson(file.account_id, `/drive/v3/files/${encodeURIComponent(file.drive_file_id)}?fields=id,trashed`, {
    method: 'PATCH', body: JSON.stringify({ trashed: true })
  });
  db.removeFile(fileId);
  await refreshQuota(file.account_id);
}

function exportInfo(mimeType) {
  const map = {
    'application/vnd.google-apps.document': { mime: 'application/pdf', ext: '.pdf' },
    'application/vnd.google-apps.spreadsheet': { mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', ext: '.xlsx' },
    'application/vnd.google-apps.presentation': { mime: 'application/vnd.openxmlformats-officedocument.presentationml.presentation', ext: '.pptx' },
    'application/vnd.google-apps.drawing': { mime: 'application/pdf', ext: '.pdf' }
  };
  return map[mimeType] || null;
}

function suggestedDownloadName(file) {
  const info = exportInfo(file.mime_type);
  if (!info) return file.name;
  return file.name.toLowerCase().endsWith(info.ext) ? file.name : file.name + info.ext;
}

async function downloadFile(fileId, destination) {
  const file = db.getFile(fileId);
  const token = await validAccessToken(file.account_id);
  const info = exportInfo(file.mime_type);
  const url = info
    ? `https://www.googleapis.com/drive/v3/files/${encodeURIComponent(file.drive_file_id)}/export?mimeType=${encodeURIComponent(info.mime)}`
    : `https://www.googleapis.com/drive/v3/files/${encodeURIComponent(file.drive_file_id)}?alt=media`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`Download failed: Google API ${res.status} ${await res.text()}`);
  const out = fs.createWriteStream(destination);
  await new Promise((resolve, reject) => {
    const { Readable } = require('stream');
    Readable.fromWeb(res.body).pipe(out).on('finish', resolve).on('error', reject);
  });
  return destination;
}

module.exports = { startOAuth, refreshQuota, syncAll, uploadFile, renameFile, deleteFile, downloadFile, suggestedDownloadName,
  browseFolder, createDriveFolder, moveDriveFile, copyDriveFile, trashDriveFile };
