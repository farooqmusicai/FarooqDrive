const path = require('path');
const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const db = require('./db');
const google = require('./google');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1260, height: 820, minWidth: 980, minHeight: 650,
    title: 'FarooqDrive',
    icon: path.join(__dirname, '..', 'build', 'icon.ico'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: false
    }
  });
  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  mainWindow.removeMenu();
}

function state() {
  const cfg = db.getOAuthConfig();
  return {
    oauthConfigured: Boolean(cfg.clientId && cfg.clientSecret),
    accounts: db.listAccountsPublic(),
    folders: db.listVirtualFolders(),
    files: db.listAllFiles()
  };
}

function safeHandler(channel, fn) {
  ipcMain.handle(channel, async (_event, ...args) => {
    try { return { ok: true, data: await fn(_event, ...args) }; }
    catch (e) { return { ok: false, error: e?.message || String(e) }; }
  });
}

app.whenReady().then(() => {
  db.initDb();
  createWindow();

  safeHandler('state:get', async () => state());
  safeHandler('oauth:save', async (_e, payload) => {
    if (!payload?.clientId?.trim() || !payload?.clientSecret?.trim()) throw new Error('Client ID and Client Secret are required.');
    db.saveOAuthConfig(payload.clientId, payload.clientSecret);
    return state();
  });
  safeHandler('account:add', async () => { await google.startOAuth(); return state(); });
  safeHandler('account:disconnect', async (_e, id) => { db.disconnectAccount(Number(id)); return state(); });
  safeHandler('drive:sync', async () => { const count = await google.syncAll(); return { count, state: state() }; });
  safeHandler('drive:browse', async (_e, p) => google.browseFolder(Number(p.accountId), p.folderId || 'root'));
  safeHandler('drive:create-folder', async (_e, p) => google.createDriveFolder(Number(p.accountId), p.parentId || 'root', p.name));
  safeHandler('drive:move-file', async (_e, p) => google.moveDriveFile(Number(p.accountId), p.fileId, p.oldParents || [], p.newParentId || 'root'));
  safeHandler('drive:copy-file', async (_e, p) => google.copyDriveFile(Number(p.accountId), p.fileId, p.parentId || 'root', p.name));
  safeHandler('drive:trash-file', async (_e, p) => google.trashDriveFile(Number(p.accountId), p.fileId));
  safeHandler('drive:restore-file', async (_e, p) => google.restoreDriveFile(Number(p.accountId), p.fileId));
  safeHandler('drive:rename-file', async (_e, p) => google.renameDriveFile(Number(p.accountId), p.fileId, p.name));
  safeHandler('drive:download-file', async (_e, p) => {
    const suggested = google.suggestedDriveDownloadName(p.file);
    const save = await dialog.showSaveDialog(mainWindow, { defaultPath: suggested });
    if (save.canceled || !save.filePath) return { canceled: true };
    await google.downloadDriveFile(Number(p.accountId), p.file, save.filePath);
    return { canceled: false, path: save.filePath };
  });
  safeHandler('folder:create', async (_e, payload) => { db.createVirtualFolder(payload.name, payload.parentId ?? null); return state(); });
  safeHandler('file:move', async (_e, payload) => { db.moveLocalFile(Number(payload.id), payload.folderId ?? null); return state(); });
  safeHandler('file:rename', async (_e, payload) => { await google.renameFile(Number(payload.id), payload.name); return state(); });
  safeHandler('file:delete', async (_e, id) => { await google.deleteFile(Number(id)); return state(); });
  safeHandler('file:preview', async (_e, id) => {
    const f = db.getFile(Number(id));
    if (!f.web_view_link) throw new Error('Google did not provide a browser preview link for this file.');
    await shell.openExternal(f.web_view_link); return true;
  });
  safeHandler('file:download', async (_e, id) => {
    const f = db.getFile(Number(id));
    const save = await dialog.showSaveDialog(mainWindow, { defaultPath: google.suggestedDownloadName(f) });
    if (save.canceled || !save.filePath) return { canceled: true };
    await google.downloadFile(Number(id), save.filePath); return { canceled: false, path: save.filePath };
  });
  safeHandler('file:choose-upload', async (_e, folderId) => {
    const selected = await dialog.showOpenDialog(mainWindow, { properties: ['openFile', 'multiSelections'] });
    if (selected.canceled || !selected.filePaths.length) return { canceled: true };
    const uploaded = [];
    for (let i = 0; i < selected.filePaths.length; i++) {
      const p = selected.filePaths[i];
      const result = await google.uploadFile(p, folderId ?? null, percent => {
        mainWindow?.webContents.send('upload:progress', { file: path.basename(p), percent, index: i + 1, total: selected.filePaths.length });
      });
      uploaded.push(result);
    }
    mainWindow?.webContents.send('upload:progress', { done: true });
    return { canceled: false, uploaded, state: state() };
  });
});

app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
