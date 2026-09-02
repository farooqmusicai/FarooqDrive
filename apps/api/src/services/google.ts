import { OAuth2Client } from 'google-auth-library';
import { nanoid } from 'nanoid';
import { all, get, run } from '../db/database.js';
import { decryptString, encryptString } from '../utils/crypto.js';
import { getGoogleOAuthConfig } from './oauth-config.js';

export const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive';
export const OIDC_SCOPES = ['openid','email','profile'];
export function newOAuthClient(redirectUri?: string) {
  const {clientId,clientSecret}=getGoogleOAuthConfig();
  return new OAuth2Client(clientId,clientSecret,redirectUri);
}
export async function driveOAuthClient(accountId:string,userId:string){
  const row=get<any>('SELECT encrypted_refresh_token FROM drive_accounts WHERE id=? AND user_id=?',[accountId,userId]);
  if(!row) throw new Error('Drive account not found');
  const client=newOAuthClient(); client.setCredentials({refresh_token:decryptString(row.encrypted_refresh_token)}); return client;
}
export async function accessTokenForDrive(accountId:string,userId:string){const c=await driveOAuthClient(accountId,userId);const t=await c.getAccessToken();if(!t.token)throw new Error('Could not obtain Google access token');return t.token;}
async function googleJson(url:string,accessToken:string,init?:RequestInit){const res=await fetch(url,{...init,headers:{...(init?.headers||{}),Authorization:`Bearer ${accessToken}`}});if(!res.ok)throw new Error(`Google API ${res.status}: ${await res.text()}`);return res.json() as Promise<any>;}
export async function getDriveAbout(accountId:string,userId:string){const token=await accessTokenForDrive(accountId,userId);return googleJson('https://www.googleapis.com/drive/v3/about?fields=user(displayName,emailAddress,photoLink,permissionId),storageQuota(limit,usage,usageInDrive,usageInDriveTrash),maxUploadSize',token);}
export async function ensureRootFolder(accountId:string,userId:string){
  const row=get<any>('SELECT root_folder_id FROM drive_accounts WHERE id=? AND user_id=?',[accountId,userId]);if(!row)throw new Error('Drive account not found');if(row.root_folder_id)return row.root_folder_id;
  const token=await accessTokenForDrive(accountId,userId);const q=encodeURIComponent("name='Farooqdrive' and mimeType='application/vnd.google-apps.folder' and trashed=false");
  const found=await googleJson(`https://www.googleapis.com/drive/v3/files?q=${q}&spaces=drive&fields=files(id,name)&pageSize=10`,token);let folderId=found.files?.[0]?.id as string|undefined;
  if(!folderId){const created=await googleJson('https://www.googleapis.com/drive/v3/files?fields=id,name',token,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:'Farooqdrive',mimeType:'application/vnd.google-apps.folder'})});folderId=created.id;}
  run('UPDATE drive_accounts SET root_folder_id=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND user_id=?',[folderId,accountId,userId]);return folderId!;
}
export function upsertDriveAccount(params:{userId:string;refreshToken:string;googleSub:string;email:string;displayName?:string|null;avatarUrl?:string|null}){
  const existing=get<any>('SELECT id FROM drive_accounts WHERE user_id=? AND google_sub=?',[params.userId,params.googleSub]);const encrypted=encryptString(params.refreshToken);const id=existing?.id??nanoid();
  if(existing)run('UPDATE drive_accounts SET email=?,display_name=?,avatar_url=?,encrypted_refresh_token=?,updated_at=CURRENT_TIMESTAMP WHERE id=?',[params.email,params.displayName??null,params.avatarUrl??null,encrypted,id]);
  else run('INSERT INTO drive_accounts (id,user_id,google_sub,email,display_name,avatar_url,encrypted_refresh_token) VALUES (?,?,?,?,?,?,?)',[id,params.userId,params.googleSub,params.email,params.displayName??null,params.avatarUrl??null,encrypted]);return id;
}
export async function refreshQuota(accountId:string,userId:string){const about=await getDriveAbout(accountId,userId);const limit=about.storageQuota?.limit?BigInt(about.storageQuota.limit):null;const usage=BigInt(about.storageQuota?.usage??'0');const usageDrive=BigInt(about.storageQuota?.usageInDrive??'0');run('UPDATE drive_accounts SET quota_limit=?,quota_usage=?,quota_usage_drive=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND user_id=?',[limit?.toString()??null,usage.toString(),usageDrive.toString(),accountId,userId]);return{limit,usage,usageDrive,about};}
export async function selectDriveForUpload(userId:string,sizeBytes:bigint){const accounts=all<any>('SELECT id FROM drive_accounts WHERE user_id=? ORDER BY created_at',[userId]);if(!accounts.length)throw new Error('No Drive account connected');for(const a of accounts){try{await refreshQuota(a.id,userId)}catch{}}
  const fresh=all<any>('SELECT id,quota_limit,quota_usage FROM drive_accounts WHERE user_id=?',[userId]);const candidates=fresh.map(a=>({id:a.id,free:a.quota_limit==null?null:BigInt(a.quota_limit)-BigInt(a.quota_usage??'0')})).filter(a=>a.free===null||a.free>=sizeBytes);if(!candidates.length)throw new Error('No connected Drive account has enough free storage');candidates.sort((a,b)=>a.free===null?1:b.free===null?-1:a.free!>b.free!?1:-1);return candidates[0]!.id;}
export async function startResumableUpload(params:{userId:string;accountId:string;name:string;mimeType:string;sizeBytes:bigint}){const token=await accessTokenForDrive(params.accountId,params.userId);const root=await ensureRootFolder(params.accountId,params.userId);const res=await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,name,mimeType,size,modifiedTime,webViewLink,iconLink',{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json; charset=UTF-8','X-Upload-Content-Type':params.mimeType||'application/octet-stream','X-Upload-Content-Length':params.sizeBytes.toString()},body:JSON.stringify({name:params.name,parents:[root]})});if(!res.ok)throw new Error(`Could not start Drive upload: ${res.status} ${await res.text()}`);const sessionUrl=res.headers.get('location');if(!sessionUrl)throw new Error('Google did not return a resumable upload URL');return sessionUrl;}
export async function listRootFiles(accountId:string,userId:string){const token=await accessTokenForDrive(accountId,userId);const root=await ensureRootFolder(accountId,userId);const q=encodeURIComponent(`'${root}' in parents and trashed=false`);let pageToken='';const files:any[]=[];do{const data=await googleJson(`https://www.googleapis.com/drive/v3/files?q=${q}&spaces=drive&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink,iconLink,trashed)&pageSize=1000${pageToken?`&pageToken=${encodeURIComponent(pageToken)}`:''}`,token);files.push(...(data.files||[]));pageToken=data.nextPageToken||'';}while(pageToken);return files;}
export async function patchDriveFile(accountId:string,userId:string,googleFileId:string,body:object){const token=await accessTokenForDrive(accountId,userId);return googleJson(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(googleFileId)}?fields=id,name,mimeType,size,modifiedTime,webViewLink,iconLink,trashed`,token,{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});}
export async function trashDriveFile(accountId:string,userId:string,googleFileId:string){return patchDriveFile(accountId,userId,googleFileId,{trashed:true});}
export async function revokeDriveAccount(accountId:string,userId:string){const client=await driveOAuthClient(accountId,userId);try{await client.revokeCredentials();}catch{}run('DELETE FROM drive_accounts WHERE id=? AND user_id=?',[accountId,userId]);}
