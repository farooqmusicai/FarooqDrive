const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('farooqDrive', {
  getState: () => ipcRenderer.invoke('state:get'),
  saveOAuth: (clientId, clientSecret) => ipcRenderer.invoke('oauth:save', { clientId, clientSecret }),
  addAccount: () => ipcRenderer.invoke('account:add'),
  disconnectAccount: id => ipcRenderer.invoke('account:disconnect', id),
  sync: () => ipcRenderer.invoke('drive:sync'),
  browse: (accountId, folderId) => ipcRenderer.invoke('drive:browse', { accountId, folderId }),
  createDriveFolder: (accountId, parentId, name) => ipcRenderer.invoke('drive:create-folder', { accountId, parentId, name }),
  moveDriveFile: (accountId, fileId, oldParents, newParentId) => ipcRenderer.invoke('drive:move-file', { accountId, fileId, oldParents, newParentId }),
  copyDriveFile: (accountId, fileId, parentId, name) => ipcRenderer.invoke('drive:copy-file', { accountId, fileId, parentId, name }),
  trashDriveFile: (accountId, fileId) => ipcRenderer.invoke('drive:trash-file', { accountId, fileId }),
  chooseAndUpload: folderId => ipcRenderer.invoke('file:choose-upload', folderId),
  createFolder: (name, parentId) => ipcRenderer.invoke('folder:create', { name, parentId }),
  renameFile: (id, name) => ipcRenderer.invoke('file:rename', { id, name }),
  moveFile: (id, folderId) => ipcRenderer.invoke('file:move', { id, folderId }),
  deleteFile: id => ipcRenderer.invoke('file:delete', id),
  downloadFile: id => ipcRenderer.invoke('file:download', id),
  previewFile: id => ipcRenderer.invoke('file:preview', id),
  onUploadProgress: cb => ipcRenderer.on('upload:progress', (_e, payload) => cb(payload))
});
