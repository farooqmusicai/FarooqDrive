const SCOPE='openid email profile https://www.googleapis.com/auth/drive';
const state={accounts:[],selected:'all',folders:{},files:[],selectedFiles:new Set(),sort:'name',query:'',clipboard:null};
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fmt=n=>{if(n==null)return'—';n=Number(n);let i=0;const u=['B','KB','MB','GB','TB'];while(n>=1024&&i<4){n/=1024;i++}return n.toFixed(i?1:0)+' '+u[i]};
function toast(t){const e=$('#toast');e.textContent=t;e.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>e.hidden=true,4500)}
function clientId(){return localStorage.getItem('fd.webClientId')||''}
async function api(a,path,options={}){const r=await fetch('https://www.googleapis.com'+path,{...options,headers:{Authorization:'Bearer '+a.token,...(options.headers||{})}});if(!r.ok){const x=await r.json().catch(()=>({}));throw new Error(x.error?.message||'Google request failed ('+r.status+')')}return r.status===204?null:r.json()}
function authorize(){
  if(!clientId()){openSettings();toast('Add your Google Web Client ID first.');return}
  if(!window.google?.accounts?.oauth2){toast('Google sign-in is still loading.');return}
  google.accounts.oauth2.initTokenClient({client_id:clientId(),scope:SCOPE,prompt:'select_account consent',callback:async r=>{
    if(r.error)return toast(r.error_description||r.error);
    try{
      const profile=await fetch('https://www.googleapis.com/oauth2/v3/userinfo',{headers:{Authorization:'Bearer '+r.access_token}}).then(x=>x.json());
      const about=await api({token:r.access_token},'/drive/v3/about?fields=storageQuota,user');
      const old=state.accounts.find(a=>a.email===profile.email);
      const account={id:profile.sub,email:profile.email,name:profile.name||profile.email,picture:profile.picture,token:r.access_token,quota:about.storageQuota||{}};
      if(old)Object.assign(old,account);else state.accounts.push(account);
      state.selected=account.id;state.folders[account.id]=[{id:'root',name:'My Drive'}];await load();renderAccounts();toast('Google account connected.');
    }catch(e){toast(e.message)}
  }}).requestAccessToken()}
function account(){return state.accounts.find(a=>a.id===state.selected)}
function currentFolder(a){return state.folders[a.id]?.at(-1)||{id:'root',name:'My Drive'}}
async function listFor(a){
  const folder=currentFolder(a), q=encodeURIComponent(`'${folder.id}' in parents and trashed=false`);
  const data=await api(a,`/drive/v3/files?q=${q}&pageSize=1000&orderBy=folder,name&fields=files(id,name,mimeType,size,modifiedTime,webViewLink,webContentLink,parents,iconLink,thumbnailLink,capabilities(canCopy,canDelete,canDownload,canEdit,canMoveItemWithinDrive))`);
  return data.files.map(f=>({...f,accountId:a.id,accountEmail:a.email}));
}
async function load(){
  try{
    $('#files').innerHTML='<tr><td colspan="6">Loading…</td></tr>';
    const targets=state.selected==='all'?state.accounts:[account()];
    const groups=await Promise.all(targets.filter(Boolean).map(listFor));
    state.files=groups.flat();state.selectedFiles.clear();render();
  }catch(e){state.files=[];render();toast(e.message)}
}
function renderAccounts(){
  $('#accounts').innerHTML=state.accounts.map(a=>`<button class="drive-item ${state.selected===a.id?'active':''}" data-account="${esc(a.id)}"><span class="account-dot">${esc((a.name||'G')[0])}</span><span><b>${esc(a.name)}</b><small>${esc(a.email)}</small></span></button>`).join('');
  $$('[data-account]').forEach(b=>b.onclick=()=>{state.selected=b.dataset.account;$$('.drive-item').forEach(x=>x.classList.remove('active'));b.classList.add('active');load()});
}
function totals(){
  let limit=0,usage=0,known=true;state.accounts.forEach(a=>{usage+=Number(a.quota.usage||0);if(a.quota.limit==null)known=false;else limit+=Number(a.quota.limit)});
  const free=known?Math.max(0,limit-usage):null,pct=limit?Math.min(100,usage/limit*100):0;
  $('#storage').innerHTML=[['TOTAL STORAGE',known?fmt(limit):'Mixed / unknown'],['USED',fmt(usage)],['FREE',fmt(free)]].map((x,i)=>`<div class="stat"><span>${x[0]}</span><b>${x[1]}</b><div class="meter"><i style="width:${i===0?pct:i===1?pct:100-pct}%"></i></div></div>`).join('');
}
function icon(f){return f.mimeType==='application/vnd.google-apps.folder'?'📁':f.mimeType?.includes('image')?'▧':f.mimeType?.includes('audio')?'♫':f.mimeType?.includes('video')?'▶':'▤'}
function visibleFiles(){
  let rows=state.files.filter(f=>!state.query||f.name.toLowerCase().includes(state.query));
  const k=state.sort;return rows.sort((a,b)=>k==='size'?Number(a.size||0)-Number(b.size||0):k==='modifiedTime'?String(b[k]).localeCompare(String(a[k])):String(a[k]||'').localeCompare(String(b[k]||''),undefined,{numeric:true,sensitivity:'base'}));
}
function render(){
  renderAccounts();totals();
  const a=account(), all=state.selected==='all';
  $('#viewTitle').textContent=all?'All Drives':a.name;
  $('#breadcrumb').innerHTML=all?'All connected accounts':state.folders[a.id].map((f,i)=>`<button data-crumb="${i}">${esc(f.name)}</button>`).join(' / ');
  $$('[data-crumb]').forEach(b=>b.onclick=()=>{state.folders[a.id]=state.folders[a.id].slice(0,Number(b.dataset.crumb)+1);load()});
  const rows=visibleFiles();
  $('#files').innerHTML=rows.map(f=>`<tr><td><input type="checkbox" data-select="${f.accountId}:${f.id}" ${state.selectedFiles.has(f.accountId+':'+f.id)?'checked':''}></td><td><div class="file-name" data-open="${f.accountId}:${f.id}"><span class="file-icon">${icon(f)}</span><span>${esc(f.name)}</span></div></td><td>${esc(f.accountEmail)}</td><td>${f.mimeType==='application/vnd.google-apps.folder'?'—':fmt(f.size)}</td><td>${f.modifiedTime?new Date(f.modifiedTime).toLocaleString():'—'}</td><td class="row-actions"><button data-more="${f.accountId}:${f.id}">•••</button></td></tr>`).join('');
  $('#empty').style.display=rows.length?'none':'flex';
  $$('[data-select]').forEach(x=>x.onchange=()=>{x.checked?state.selectedFiles.add(x.dataset.select):state.selectedFiles.delete(x.dataset.select);buttons()});
  $$('[data-open]').forEach(x=>x.ondblclick=()=>openItem(x.dataset.open));
  $$('[data-more]').forEach(x=>x.onclick=()=>{state.selectedFiles=new Set([x.dataset.more]);buttons();const f=getItem(x.dataset.more);if(f.mimeType==='application/vnd.google-apps.folder')openItem(x.dataset.more);else if(f.webViewLink)window.open(f.webViewLink,'_blank','noopener')});
  $('#selectAll').checked=rows.length>0&&rows.every(f=>state.selectedFiles.has(f.accountId+':'+f.id));
  buttons();
}
function getItem(key){const [aid,id]=key.split(':');return state.files.find(f=>f.accountId===aid&&f.id===id)}
async function openItem(key){const f=getItem(key),a=state.accounts.find(x=>x.id===f.accountId);if(f.mimeType==='application/vnd.google-apps.folder'){state.selected=a.id;state.folders[a.id].push({id:f.id,name:f.name});await load()}else if(f.webViewLink)window.open(f.webViewLink,'_blank','noopener')}
function buttons(){const n=state.selectedFiles.size;$('#copyBtn').disabled=!n;$('#cutBtn').disabled=!n;$('#renameBtn').disabled=n!==1;$('#deleteBtn').disabled=!n;$('#pasteBtn').disabled=!state.clipboard;$('#newFolder').disabled=state.selected==='all';}
function chosen(){return [...state.selectedFiles].map(getItem).filter(Boolean)}
async function createFolder(){const a=account();if(!a)return toast('Select one Google account first.');const name=prompt('Folder name');if(!name)return;await api(a,'/drive/v3/files?fields=id',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name,mimeType:'application/vnd.google-apps.folder',parents:[currentFolder(a).id]})});await load()}
async function rename(){const f=chosen()[0],a=state.accounts.find(x=>x.id===f.accountId),name=prompt('New name',f.name);if(!name)return;await api(a,'/drive/v3/files/'+encodeURIComponent(f.id)+'?fields=id,name',{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({name})});await load()}
async function trash(){if(!confirm('Move selected item(s) to Google Drive Trash?'))return;for(const f of chosen()){const a=state.accounts.find(x=>x.id===f.accountId);await api(a,'/drive/v3/files/'+encodeURIComponent(f.id)+'?fields=id,trashed',{method:'PATCH',headers:{'Content-Type':'application/json'},body:'{"trashed":true}'})}await load()}
async function paste(){
  const dst=account();if(!dst)return toast('Open one destination account first.');
  const parent=currentFolder(dst).id, clip=state.clipboard;
  try{for(const f of clip.items){const src=state.accounts.find(x=>x.id===f.accountId);if(src.id!==dst.id)throw new Error('Cross-account paste is available in the Windows edition; download/upload is required in browsers.');if(clip.mode==='copy')await api(src,'/drive/v3/files/'+encodeURIComponent(f.id)+'/copy?fields=id',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({parents:[parent],name:f.name})});else{const old=(f.parents||[]).join(',');await api(src,`/drive/v3/files/${encodeURIComponent(f.id)}?addParents=${encodeURIComponent(parent)}&removeParents=${encodeURIComponent(old)}&fields=id,parents`,{method:'PATCH'})}}if(clip.mode==='cut')state.clipboard=null;await load()}catch(e){toast(e.message)}
}
async function upload(files){
  let a=account();if(!a){a=[...state.accounts].sort((x,y)=>(Number(y.quota.limit||0)-Number(y.quota.usage||0))-(Number(x.quota.limit||0)-Number(x.quota.usage||0)))[0]}if(!a)return toast('Connect a Google account first.');
  const parent=currentFolder(a).id;
  for(let i=0;i<files.length;i++){const f=files[i],q=$('#queue');q.hidden=false;q.innerHTML=`Uploading ${esc(f.name)} (${i+1}/${files.length})<div class="progress"><i style="width:${(i/files.length)*100}%"></i></div>`;const meta={name:f.name,parents:[parent]};const boundary='fd'+Date.now();const body=new Blob([`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n`,JSON.stringify(meta),`\r\n--${boundary}\r\nContent-Type: ${f.type||'application/octet-stream'}\r\n\r\n`,f,`\r\n--${boundary}--`]);await api(a,'/upload/drive/v3/files?uploadType=multipart&fields=id',{method:'POST',headers:{'Content-Type':'multipart/related; boundary='+boundary},body})}$('#queue').hidden=true;await load();toast(files.length+' file(s) uploaded.')}
function openSettings(){$('#clientId').value=clientId();$('#settingsDialog').showModal()}
$('#addAccount').onclick=authorize;$('#allDrives').onclick=()=>{state.selected='all';load()};$('#openSettings').onclick=openSettings;$('#openHelp').onclick=()=>$('#helpDialog').showModal();
$('#saveSettings').onclick=e=>{e.preventDefault();const v=$('#clientId').value.trim();if(!v.endsWith('.apps.googleusercontent.com'))return toast('Enter a valid Google Web Client ID.');localStorage.setItem('fd.webClientId',v);$('#settingsDialog').close();toast('Client ID saved on this browser.')};
$('#newFolder').onclick=()=>createFolder().catch(e=>toast(e.message));$('#renameBtn').onclick=()=>rename().catch(e=>toast(e.message));$('#deleteBtn').onclick=()=>trash().catch(e=>toast(e.message));
$('#copyBtn').onclick=()=>{state.clipboard={mode:'copy',items:chosen()};buttons();toast('Copied. Open a folder and paste.')};$('#cutBtn').onclick=()=>{state.clipboard={mode:'cut',items:chosen()};buttons();toast('Ready to move. Open a folder and paste.')};$('#pasteBtn').onclick=paste;
$('#uploadInput').onchange=e=>upload([...e.target.files]).catch(x=>toast(x.message));$('#refresh').onclick=load;$('#sort').onchange=e=>{state.sort=e.target.value;render()};$('#search').oninput=e=>{state.query=e.target.value.trim().toLowerCase();render()};
$('#selectAll').onchange=e=>{visibleFiles().forEach(f=>{const k=f.accountId+':'+f.id;e.target.checked?state.selectedFiles.add(k):state.selectedFiles.delete(k)});render()};
render();
if(!clientId())setTimeout(openSettings,350);
