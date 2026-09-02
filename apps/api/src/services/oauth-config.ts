import { get, run } from '../db/database.js';
import { decryptString, encryptString } from '../utils/crypto.js';
import { env } from '../config.js';

const SECRET_NAME='google_oauth_config';

type GoogleOAuthConfig={clientId:string;clientSecret:string};

function validClientId(value:string){
  return value.trim().endsWith('.apps.googleusercontent.com') && value.trim().length > 40;
}

export function getGoogleOAuthConfig():GoogleOAuthConfig {
  const row=get<any>('SELECT encrypted_value FROM app_secrets WHERE name=?',[SECRET_NAME]);
  if(row?.encrypted_value){
    try{
      const parsed=JSON.parse(decryptString(String(row.encrypted_value)));
      if(validClientId(parsed.clientId||'') && String(parsed.clientSecret||'').trim()){
        return {clientId:String(parsed.clientId).trim(),clientSecret:String(parsed.clientSecret).trim()};
      }
    }catch{}
  }
  // Developer-only fallback. Official/public builds do not embed these values.
  const e=env();
  if(e.GOOGLE_CLIENT_ID && e.GOOGLE_CLIENT_SECRET){
    return {clientId:e.GOOGLE_CLIENT_ID,clientSecret:e.GOOGLE_CLIENT_SECRET};
  }
  throw new Error('Google OAuth is not configured on this PC');
}

export function saveGoogleOAuthConfig(config:GoogleOAuthConfig){
  const clientId=config.clientId.trim();
  const clientSecret=config.clientSecret.trim();
  if(!validClientId(clientId)) throw new Error('Client ID does not look like a Google Desktop OAuth Client ID');
  if(clientSecret.length < 4) throw new Error('Client Secret is required');
  const encrypted=encryptString(JSON.stringify({clientId,clientSecret}));
  run(`INSERT INTO app_secrets (name,encrypted_value,updated_at)
       VALUES (?,?,CURRENT_TIMESTAMP)
       ON CONFLICT(name) DO UPDATE SET encrypted_value=excluded.encrypted_value,updated_at=CURRENT_TIMESTAMP`,
      [SECRET_NAME,encrypted]);
}

export function clearGoogleOAuthConfig(){
  run('DELETE FROM app_secrets WHERE name=?',[SECRET_NAME]);
}

export function googleOAuthConfigured(){
  try{ getGoogleOAuthConfig(); return true; }catch{ return false; }
}

export function googleOAuthPublicInfo(){
  try{
    const {clientId}=getGoogleOAuthConfig();
    const visible=clientId.length>28 ? `${clientId.slice(0,12)}…${clientId.slice(-18)}` : clientId;
    return {configured:true,clientIdHint:visible};
  }catch{
    return {configured:false,clientIdHint:null};
  }
}
