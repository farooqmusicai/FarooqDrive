import { FormEvent,useEffect,useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../lib/api';

export function SettingsPage(){
 const[info,setInfo]=useState<any>(null),[clientId,setClientId]=useState(''),[clientSecret,setClientSecret]=useState(''),[error,setError]=useState(''),[ok,setOk]=useState('');
 const load=()=>api('/api/system/status').then(setInfo).catch((e:any)=>setError(e.message));
 useEffect(()=>{load()},[]);
 async function save(e:FormEvent){e.preventDefault();setError('');setOk('');try{await api('/api/system/google-oauth',{method:'POST',body:JSON.stringify({clientId,clientSecret})});setClientId('');setClientSecret('');setOk('Google OAuth credentials updated.');await load()}catch(e:any){setError(e.message)}}
 if(!info)return <div className="loading">Loading settings…</div>;
 return <main className="settings-shell"><section className="settings-card">
   <div className="settings-head"><div><h1>FarooqDrive settings</h1><p>Google OAuth credentials on this PC</p></div><Link to="/dashboard">← Dashboard</Link></div>
   <div className="settings-summary"><b>Status</b><span>{info.googleOAuthConfigured?'Configured':'Not configured'}</span><b>Client ID</b><span>{info.googleOAuthClientHint||'—'}</span><b>Connected Drives</b><span>{info.driveAccountCount}</span></div>
   <div className="note-box">Your OAuth Client ID and Secret are local to this installation. FarooqDrive's public GitHub source and standard Windows installer do not contain the publisher's credentials.</div>
   {info.driveAccountCount>0&&<div className="warning-box">To replace the OAuth Client ID/Secret, first disconnect all currently connected Google Drive accounts. Refresh tokens belong to the OAuth client that created them.</div>}
   <form className="oauth-form" onSubmit={save}>
     <h2>Replace credentials</h2>
     <input value={clientId} onChange={e=>setClientId(e.target.value)} placeholder="Desktop OAuth Client ID" required/>
     <input type="password" value={clientSecret} onChange={e=>setClientSecret(e.target.value)} placeholder="Client Secret" required/>
     {error&&<p className="error">{error}</p>}{ok&&<p className="success">{ok}</p>}
     <button className="primary" type="submit" disabled={info.driveAccountCount>0}>Save new credentials</button>
   </form>
   <p className="fine"><a href="https://console.cloud.google.com/auth/clients" target="_blank" rel="noreferrer">Open Google OAuth Clients in your browser</a></p>
 </section></main>
}
