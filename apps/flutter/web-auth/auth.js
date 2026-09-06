import {PublicClientApplication, BrowserCacheLocation} from '@azure/msal-browser';
const clients = new Map();
const connections = new Map();
const scopes = ['User.Read', 'Files.ReadWrite'];
const redirectUri = new URL('microsoft-callback.html', document.baseURI).href;
async function client(id) {
  if (!clients.has(id)) {
    const app = new PublicClientApplication({auth:{clientId:id, authority:'https://login.microsoftonline.com/common',redirectUri},
      cache:{cacheLocation:BrowserCacheLocation.MemoryStorage},system:{loggerOptions:{loggerCallback:()=>{},piiLoggingEnabled:false}}});
    clients.set(id, app.initialize().then(()=>app));
  }
  return clients.get(id);
}
function failure(e) {
  const code = /^[a-zA-Z0-9_]{1,100}$/.test(e?.errorCode||'') ? e.errorCode : 'sign_in_failed';
  return JSON.stringify({error:`Microsoft sign-in: ${code}. Allow popups. Check the registered SPA redirect URI, consent and account access, then reconnect.`});
}
window.fdMicrosoftLogin = async id => {
  try {
    const app=await client(id);
    const result=await app.loginPopup({scopes,prompt:'select_account',redirectUri});
    const key='onedrive:'+result.account.homeAccountId;
    connections.set(key,{app,account:result.account});
    return JSON.stringify({id:key,email:result.account.username,name:result.account.name||result.account.username,token:result.accessToken});
  } catch(e) {return failure(e);}
};
window.fdMicrosoftToken = async (id,force) => {
  try {
    const connection=connections.get(id);
    if(!connection) return JSON.stringify({error:'Microsoft session ended. Reconnect this account.'});
    const result=await connection.app.acquireTokenSilent({scopes,account:connection.account,forceRefresh:force});
    if(connections.get(id)!==connection) return JSON.stringify({error:'Microsoft account disconnected.'});
    return JSON.stringify({token:result.accessToken});
  } catch(e){return failure(e);}
};
window.fdMicrosoftForget = async id => {
  const connection=connections.get(id);
  connections.delete(id);
  if(connection) await connection.app.clearCache({account:connection.account});
  return '';
};
