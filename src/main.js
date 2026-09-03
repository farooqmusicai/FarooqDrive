const { app, BrowserWindow, ipcMain, dialog, shell, safeStorage } = require('electron');
const { DatabaseSync } = require('node:sqlite');
const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { pathToFileURL } = require('url');

let db;
let win;
const SCOPE = 'openid email profile https://www.googleapis.com/auth/drive';
const GOOGLE_FOLDER = 'application/vnd.google-apps.folder';

const enc = s => s ? safeStorage.encryptString(String(s)).toString('base64') : null;
const dec = s => s ? safeStorage.decryptString(Buffer.from(s, 'base64')) : '';

function init() {
  db = new DatabaseSync(path.join(app.getPath('userData'), 'farooqdrive.sqlite'));
  db.exec(`
    PRAGMA foreign_keys=ON;
    CREATE TABLE IF NOT EXISTS settings(k TEXT PRIMARY KEY,v TEXT);
    CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY,email TEXT UNIQUE,name TEXT,access TEXT NOT NULL,refresh TEXT,expires INTEGER,root TEXT,quota INTEGER,used INTEGER DEFAULT 0);
    CREATE TABLE IF NOT EXISTS folders(id INTEGER PRIMARY KEY,name TEXT NOT NULL,parent INTEGER);
    CREATE TABLE IF NOT EXISTS files(id INTEGER PRIMARY KEY,account INTEGER NOT NULL,driveid TEXT NOT NULL,name TEXT NOT NULL,mime TEXT,size INTEGER DEFAULT 0,folder INTEGER,parent TEXT,modified TEXT,view TEXT,UNIQUE(account,driveid),FOREIGN KEY(account) REFERENCES accounts(id) ON DELETE CASCADE);
  `);
}

function secret(k){const r=db.prepare('SELECT v FROM settings WHERE k=?').get(k);return r?dec(r.v):''}
function setSecret(k,v){db.prepare('INSERT INTO settings(k,v) VALUES(?,?) ON CONFLICT(k) DO UPDATE SET v=excluded.v').run(k,enc(v))}
function cfg(){return{clientId:secret('clientId'),clientSecret:secret('clientSecret')}}
function rawAccounts(){return db.prepare('SELECT * FROM accounts ORDER BY id').all()}
function pubAccounts(){return rawAccounts().map(a=>({id:Number(a.id),email:a.email,name:a.name,quota:a.quota===null?null:Number(a.quota),used:Number(a.used||0)}))}
function state(){const c=cfg();return{oauthConfigured:!!(c.clientId&&c.clientSecret),accounts:pubAccounts(),folders:db.prepare('SELECT id,name,parent FROM folders ORDER BY name').all().map(x=>({id:Number(x.id),name:x.name,parent:x.parent===null?null:Number(x.parent)})),files:db.prepare('SELECT f.*,a.email FROM files f JOIN accounts a ON a.id=f.account ORDER BY f.name').all().map(x=>({id:Number(x.id),account:Number(x.account),driveid:x.driveid,name:x.name,mime:x.mime,size:Number(x.size||0),folder:x.folder===null?null:Number(x.folder),modified:x.modified||'',view:x.view||'',email:x.email}))}}

async function jf(url,opt={}){const r=await fetch(url,opt);const t=await r.text();let b;try{b=t?JSON.parse(t):null}catch{b=t}if(!r.ok)throw Error(`Google API ${r.status}: ${b?.error?.message||b?.error_description||t||r.statusText}`);return b}
function account(id){const a=db.prepare('SELECT * FROM accounts WHERE id=?').get(id);if(!a)throw Error('Drive account not found.');return a}
async function token(id){const a=account(id);if(a.expires>Date.now()+60000)return dec(a.access);const c=cfg(),refresh=dec(a.refresh);if(!refresh)throw Error(`Reconnect ${a.email}; refresh token is missing.`);const body=new URLSearchParams({client_id:c.clientId,client_secret:c.clientSecret,refresh_token:refresh,grant_type:'refresh_token'});const t=await jf('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body});db.prepare('UPDATE accounts SET access=?,expires=? WHERE id=?').run(enc(t.access_token),Date.now()+Number(t.expires_in||3600)*1000,id);return t.access_token}
async function drive(id,url,opt={}){const headers={...(opt.headers||{}),Authorization:`Bearer ${await token(id)}`};if(opt.body&&!headers['Content-Type'])headers['Content-Type']='application/json';return jf('https://www.googleapis.com'+url,{...opt,headers})}
async function quota(id){const a=await drive(id,'/drive/v3/about?fields=storageQuota(limit,usage)');const q=a.storageQuota||{};db.prepare('UPDATE accounts SET quota=?,used=? WHERE id=?').run(q.limit===undefined?null:Number(q.limit),Number(q.usage||0),id)}

async function root(id){const a=account(id);if(a.root)return a.root;const q=encodeURIComponent("name='Farooqdrive' and mimeType='application/vnd.google-apps.folder' and 'root' in parents and trashed=false");const r=await drive(id,`/drive/v3/files?q=${q}&fields=files(id)&spaces=drive&pageSize=10`);let rid=r.files?.[0]?.id;if(!rid)rid=(await drive(id,'/drive/v3/files?fields=id',{method:'POST',body:JSON.stringify({name:'Farooqdrive',mimeType:GOOGLE_FOLDER,parents:['root']})})).id;db.prepare('UPDATE accounts SET root=? WHERE id=?').run(rid,id);return rid}

function b64(b){return Buffer.from(b).toString('base64').replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_')}
async function oauth(){const c=cfg();if(!c.clientId||!c.clientSecret)throw Error('Save Google OAuth Client ID and Client Secret first.');const verifier=b64(crypto.randomBytes(48)),challenge=b64(crypto.createHash('sha256').update(verifier).digest()),st=b64(crypto.randomBytes(24));return new Promise((resolve,reject)=>{const server=http.createServer(async(req,res)=>{try{const u=new URL(req.url,'http://127.0.0.1');if(u.pathname!='/oauth2/callback')return res.writeHead(404).end();if(u.searchParams.get('state')!==st)throw Error('OAuth state validation failed.');if(u.searchParams.get('error'))throw Error('Google authorization: '+u.searchParams.get('error'));const code=u.searchParams.get('code'),redirect=`http://127.0.0.1:${server.address().port}/oauth2/callback`,body=new URLSearchParams({code,client_id:c.clientId,client_secret:c.clientSecret,redirect_uri:redirect,grant_type:'authorization_code',code_verifier:verifier}),t=await jf('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body}),about=await jf('https://www.googleapis.com/drive/v3/about?fields=user(displayName,emailAddress),storageQuota(limit,usage)',{headers:{Authorization:`Bearer ${t.access_token}`}}),old=db.prepare('SELECT * FROM accounts WHERE email=?').get(about.user.emailAddress),refresh=t.refresh_token||(old?dec(old.refresh):'');db.prepare(`INSERT INTO accounts(email,name,access,refresh,expires,root,quota,used) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(email) DO UPDATE SET name=excluded.name,access=excluded.access,refresh=excluded.refresh,expires=excluded.expires,quota=excluded.quota,used=excluded.used`).run(about.user.emailAddress,about.user.displayName||about.user.emailAddress,enc(t.access_token),enc(refresh),Date.now()+Number(t.expires_in||3600)*1000,old?.root||null,about.storageQuota?.limit===undefined?null:Number(about.storageQuota.limit),Number(about.storageQuota?.usage||0));const id=Number(db.prepare('SELECT id FROM accounts WHERE email=?').get(about.user.emailAddress).id);await root(id);res.writeHead(200,{'Content-Type':'text/html'}).end('<h1>FarooqDrive connected</h1><p>Authorization is complete. Close this tab and return to FarooqDrive.</p>');setTimeout(()=>server.close(),200);resolve()}catch(e){res.writeHead(500).end(e.message);server.close();reject(e)}});server.listen(0,'127.0.0.1',async()=>{const redirect=`http://127.0.0.1:${server.address().port}/oauth2/callback`;const u=new URL('https://accounts.google.com/o/oauth2/v2/auth');Object.entries({client_id:c.clientId,redirect_uri:redirect,response_type:'code',scope:SCOPE,access_type:'offline',prompt:'consent select_account',state:st,code_challenge:challenge,code_challenge_method:'S256'}).forEach(([k,v])=>u.searchParams.set(k,v));await shell.openExternal(u.toString())})})}

function mime(n){const e=n.toLowerCase().split('.').pop();const m={pdf:'application/pdf',txt:'text/plain',jpg:'image/jpeg',jpeg:'image/jpeg',png:'image/png',gif:'image/gif',webp:'image/webp',mp3:'audio/mpeg',wav:'audio/wav',mp4:'video/mp4',webm:'video/webm',zip:'application/zip',json:'application/json',csv:'text/csv'};return m[e]||'application/octet-stream'}
async function choose(size){for(const a of rawAccounts())try{await quota(Number(a.id))}catch{}const a=rawAccounts().filter(x=>x.quota===null||Number(x.quota)-Number(x.used||0)>=size).sort((x,y)=>(y.quota===null?1e30:Number(y.quota)-Number(y.used||0))-(x.quota===null?1e30:Number(x.quota)-Number(x.used||0)))[0];if(!a)throw Error('No connected Drive has enough free space.');return a}
async function uploadFile(p,folder){const st=fs.statSync(p),a=await choose(st.size),id=Number(a.id),rid=await root(id),tok=await token(id),name=path.basename(p),mt=mime(name);const r=await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,name,mimeType,size,modifiedTime,webViewLink,parents',{method:'POST',headers:{Authorization:`Bearer ${tok}`,'Content-Type':'application/json','X-Upload-Content-Type':mt,'X-Upload-Content-Length':String(st.size)},body:JSON.stringify({name,parents:[rid]})});if(!r.ok)throw Error(`Upload session ${r.status}: ${await r.text()}`);const loc=r.headers.get('location');if(!loc)throw Error('Google did not return upload URL.');const meta=await new Promise((resolve,reject)=>{const u=new URL(loc),req=https.request({method:'PUT',hostname:u.hostname,path:u.pathname+u.search,headers:{'Content-Type':mt,'Content-Length':String(st.size)}},res=>{let d='';res.on('data',c=>d+=c);res.on('end',()=>res.statusCode>=200&&res.statusCode<300?resolve(JSON.parse(d||'{}')):reject(Error(`Google upload ${res.statusCode}: ${d}`)))});req.on('error',reject);let sent=0;const s=fs.createReadStream(p);s.on('data',c=>{sent+=c.length;win.webContents.send('progress',{file:name,percent:Math.round(sent/st.size*100)})});s.on('error',reject);s.pipe(req)});db.prepare('INSERT INTO files(account,driveid,name,mime,size,folder,parent,modified,view) VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(account,driveid) DO UPDATE SET name=excluded.name,size=excluded.size,modified=excluded.modified,view=excluded.view').run(id,meta.id,meta.name||name,meta.mimeType||mt,Number(meta.size||st.size),folder??null,rid,meta.modifiedTime||new Date().toISOString(),meta.webViewLink||'');await quota(id)}

function ensurePath(parts){let parent=null;for(const name of parts.filter(Boolean)){let r=parent===null?db.prepare('SELECT id FROM folders WHERE name=? AND parent IS NULL').get(name):db.prepare('SELECT id FROM folders WHERE name=? AND parent=?').get(name,parent);if(!r){const x=db.prepare('INSERT INTO folders(name,parent) VALUES(?,?)').run(name,parent);parent=Number(x.lastInsertRowid)}else parent=Number(r.id)}return parent}

async function listDrive(id){let all=[],page='';do{const q=encodeURIComponent('trashed=false');const x=await drive(id,`/drive/v3/files?q=${q}&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink,parents)&spaces=drive&pageSize=1000${page?'&pageToken='+encodeURIComponent(page):''}`);all.push(...(x.files||[]));page=x.nextPageToken||''}while(page);return all}

function folderParts(parentId,folderMap,rootId){const parts=[];const seen=new Set();let cur=parentId;while(cur&&cur!==rootId&&cur!=='root'&&!seen.has(cur)){seen.add(cur);const f=folderMap.get(cur);if(!f)break;parts.unshift(f.name);cur=f.parents?.[0]}return parts}

async function sync(){let count=0;for(const a of rawAccounts()){const id=Number(a.id);const all=await listDrive(id);let rootId='root';try{rootId=(await drive(id,'/drive/v3/files/root?fields=id')).id||'root'}catch{}const folderMap=new Map(all.filter(f=>f.mimeType===GOOGLE_FOLDER).map(f=>[f.id,f]));for(const f of all){if(f.mimeType===GOOGLE_FOLDER)continue;const parentId=f.parents?.[0]||rootId;const parts=folderParts(parentId,folderMap,rootId);const folderId=ensurePath(parts);db.prepare('INSERT INTO files(account,driveid,name,mime,size,folder,parent,modified,view) VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(account,driveid) DO UPDATE SET name=excluded.name,mime=excluded.mime,size=excluded.size,parent=excluded.parent,modified=excluded.modified,view=excluded.view').run(id,f.id,f.name,f.mimeType||'',Number(f.size||0),folderId,parentId,f.modifiedTime||'',f.webViewLink||'');count++}await quota(id)}return count}

function exportMime(mimeType){if(mimeType==='application/vnd.google-apps.document')return'application/pdf';if(mimeType==='application/vnd.google-apps.spreadsheet')return'application/pdf';if(mimeType==='application/vnd.google-apps.presentation')return'application/pdf';if(mimeType==='application/vnd.google-apps.drawing')return'application/pdf';return null}
async function fetchFileResponse(f){const tok=await token(Number(f.account));const em=exportMime(f.mime);let url;if(em)url=`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(f.driveid)}/export?mimeType=${encodeURIComponent(em)}`;else url=`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(f.driveid)}?alt=media`;const r=await fetch(url,{headers:{Authorization:`Bearer ${tok}`}});if(!r.ok)throw Error(`Google file ${r.status}: ${await r.text()}`);return{r,mime:em||f.mime||'application/octet-stream'}}
function previewExt(mimeType,name){const byMime={'application/pdf':'.pdf','image/jpeg':'.jpg','image/png':'.png','image/gif':'.gif','image/webp':'.webp','text/plain':'.txt','text/csv':'.csv','application/json':'.json','audio/mpeg':'.mp3','audio/wav':'.wav','video/mp4':'.mp4','video/webm':'.webm'};return byMime[mimeType]||path.extname(name)||'.bin'}
async function previewFile(id){const f=db.prepare('SELECT * FROM files WHERE id=?').get(Number(id));if(!f)throw Error('File not found.');const {r,mime:mt}=await fetchFileResponse(f);const dir=path.join(app.getPath('temp'),'FarooqDrivePreview');fs.mkdirSync(dir,{recursive:true});const p=path.join(dir,`${f.driveid}${previewExt(mt,f.name)}`);const buf=Buffer.from(await r.arrayBuffer());fs.writeFileSync(p,buf);const preview=new BrowserWindow({width:1000,height:760,parent:win,autoHideMenuBar:true,title:`Preview - ${f.name}`,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true}});preview.loadURL(pathToFileURL(p).href);return true}
async function downloadFile(id){const f=db.prepare('SELECT * FROM files WHERE id=?').get(Number(id));if(!f)throw Error('File not found.');const em=exportMime(f.mime);let defaultName=f.name;if(em==='application/pdf'&&!defaultName.toLowerCase().endsWith('.pdf'))defaultName+='.pdf';const s=await dialog.showSaveDialog(win,{defaultPath:defaultName});if(s.canceled)return{canceled:true};const {r}=await fetchFileResponse(f);const {Readable}=require('stream');await new Promise((ok,no)=>Readable.fromWeb(r.body).pipe(fs.createWriteStream(s.filePath)).on('finish',ok).on('error',no));return{canceled:false,path:s.filePath}}

function h(ch,fn){ipcMain.handle(ch,async(_e,...a)=>{try{return{ok:true,data:await fn(...a)}}catch(e){return{ok:false,error:e.message||String(e)}}})}

app.whenReady().then(()=>{
  init();
  win=new BrowserWindow({width:1260,height:820,minWidth:980,minHeight:650,title:'FarooqDrive',webPreferences:{preload:path.join(__dirname,'preload.js'),contextIsolation:true,nodeIntegration:false,sandbox:false}});
  win.removeMenu();
  win.loadFile(path.join(__dirname,'renderer','index.html'));

  h('state',()=>state());
  h('oauth',x=>{if(!x.clientId?.trim()||!x.clientSecret?.trim())throw Error('Client ID and Secret are required.');setSecret('clientId',x.clientId.trim());setSecret('clientSecret',x.clientSecret.trim());return state()});
  h('add',async()=>{await oauth();return state()});
  h('disconnect',id=>{db.prepare('DELETE FROM accounts WHERE id=?').run(Number(id));return state()});
  h('folder',x=>{if(!x.name?.trim())throw Error('Folder name required.');db.prepare('INSERT INTO folders(name,parent) VALUES(?,?)').run(x.name.trim(),x.parent??null);return state()});
  h('move',x=>{db.prepare('UPDATE files SET folder=? WHERE id=?').run(x.folder??null,Number(x.id));return state()});
  h('sync',async()=>({count:await sync(),state:state()}));
  h('upload',async folder=>{const s=await dialog.showOpenDialog(win,{properties:['openFile','multiSelections']});if(s.canceled)return{canceled:true};for(const p of s.filePaths)await uploadFile(p,folder);win.webContents.send('progress',{done:true});return{canceled:false,state:state()}});
  h('rename',async x=>{const f=db.prepare('SELECT * FROM files WHERE id=?').get(Number(x.id));await drive(Number(f.account),`/drive/v3/files/${encodeURIComponent(f.driveid)}?fields=id,name`,{method:'PATCH',body:JSON.stringify({name:x.name})});db.prepare('UPDATE files SET name=? WHERE id=?').run(x.name,Number(x.id));return state()});
  h('trash',async id=>{const f=db.prepare('SELECT * FROM files WHERE id=?').get(Number(id));await drive(Number(f.account),`/drive/v3/files/${encodeURIComponent(f.driveid)}?fields=id,trashed`,{method:'PATCH',body:JSON.stringify({trashed:true})});db.prepare('DELETE FROM files WHERE id=?').run(Number(id));return state()});
  h('preview',previewFile);
  h('download',downloadFile);
});

app.on('window-all-closed',()=>{if(process.platform!=='darwin')app.quit()});
