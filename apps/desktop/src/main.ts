import { app,BrowserWindow,safeStorage,shell } from 'electron';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { startServer } from '../../api/src/server.js';

function masterKey(userData:string){const file=path.join(userData,'master-key.bin');if(fs.existsSync(file)){const encrypted=fs.readFileSync(file);if(safeStorage.isEncryptionAvailable())return safeStorage.decryptString(encrypted);return encrypted.toString('utf8');}const key=crypto.randomBytes(32).toString('base64');const out=safeStorage.isEncryptionAvailable()?safeStorage.encryptString(key):Buffer.from(key,'utf8');fs.writeFileSync(file,out,{mode:0o600});return key;}
app.setAppUserModelId('com.farooqdrive.desktop');
app.whenReady().then(async()=>{const dataDir=app.getPath('userData');process.env.NODE_ENV='production';process.env.FAROOQDRIVE_DATA_DIR=dataDir;process.env.FAROOQDRIVE_VERSION=app.getVersion();const key=masterKey(dataDir);process.env.APP_ENCRYPTION_KEY=key;process.env.JWT_SECRET=crypto.createHash('sha256').update(`session:${key}`).digest('base64url');
 const packaged=app.isPackaged;const staticDir=packaged?path.join(process.resourcesPath,'web'):path.resolve(app.getAppPath(),'apps/web/dist');const migrationDir=packaged?path.join(process.resourcesPath,'migrations'):path.resolve(app.getAppPath(),'apps/api/migrations');const service=await startServer({staticDir,migrationDir,host:'127.0.0.1',port:0});
 const windowIcon=packaged?path.join(process.resourcesPath,'build','FarooqDrive.png'):path.resolve(app.getAppPath(),'build','FarooqDrive.png'); const win=new BrowserWindow({width:1360,height:860,minWidth:1040,minHeight:700,show:false,backgroundColor:'#f5f7fb',icon:windowIcon,webPreferences:{nodeIntegration:false,contextIsolation:true,sandbox:true}});win.setMenuBarVisibility(false);win.webContents.setWindowOpenHandler(({url})=>{if(url.startsWith(service.url))return{action:'allow',overrideBrowserWindowOptions:{width:1100,height:760,autoHideMenuBar:true,webPreferences:{nodeIntegration:false,contextIsolation:true,sandbox:true}}};if(/^https:\/\//i.test(url)){shell.openExternal(url);return{action:'deny'}}return{action:'deny'}});win.webContents.on('will-navigate',(event,url)=>{if(!url.startsWith(service.url)){event.preventDefault();shell.openExternal(url)}});await win.loadURL(service.url);win.once('ready-to-show',()=>win.show());
 app.on('before-quit',()=>service.server.close());});
app.on('window-all-closed',()=>{if(process.platform!=='darwin')app.quit()});
