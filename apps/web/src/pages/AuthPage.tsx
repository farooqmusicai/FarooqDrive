import { FormEvent,useEffect,useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import { googleAuthorization } from '../lib/googleAuth';
import { GoogleSetupWizard } from '../components/GoogleSetupWizard';

export function AuthPage(){
 const[mode,setMode]=useState<'login'|'register'>('login');const[email,setEmail]=useState('');const[password,setPassword]=useState('');const[name,setName]=useState('');const[error,setError]=useState('');const[busy,setBusy]=useState(false);const[googleReady,setGoogleReady]=useState<boolean|null>(null);const[status,setStatus]=useState('');const nav=useNavigate();
 const check=()=>api<any>('/api/system/status').then(s=>setGoogleReady(Boolean(s.googleOAuthConfigured))).catch(()=>setGoogleReady(false));
 useEffect(()=>{check()},[]);
 async function submit(e:FormEvent){e.preventDefault();setError('');setBusy(true);try{await api(`/api/auth/${mode}`,{method:'POST',body:JSON.stringify({email,password,displayName:name||undefined})});nav('/dashboard')}catch(e:any){setError(e.message)}finally{setBusy(false)}}
 async function google(){setError('');setBusy(true);try{await googleAuthorization('login',setStatus);nav('/dashboard')}catch(e:any){setError(e.message)}finally{setBusy(false);setStatus('')}}
 if(googleReady===null)return <div className="loading">Starting FarooqDrive…</div>;
 if(!googleReady)return <GoogleSetupWizard onDone={()=>setGoogleReady(true)}/>;
 return <main className="auth-shell"><section className="auth-card"><div className="brand"><div className="logo">FD</div><div><h1>FarooqDrive</h1><p>All your Google Drives. One dashboard.</p></div></div><div className="tabs"><button className={mode==='login'?'active':''} onClick={()=>setMode('login')}>Sign in</button><button className={mode==='register'?'active':''} onClick={()=>setMode('register')}>Register</button></div><form onSubmit={submit}>{mode==='register'&&<input placeholder="Display name" value={name} onChange={e=>setName(e.target.value)}/>}<input type="email" placeholder="Email" value={email} onChange={e=>setEmail(e.target.value)} required/><input type="password" minLength={10} placeholder="Password (10+ characters)" value={password} onChange={e=>setPassword(e.target.value)} required/>{error&&<p className="error">{error}</p>}<button className="primary" disabled={busy} type="submit">{busy?'Please wait…':mode==='login'?'Sign in':'Create account'}</button></form><div className="or"><span/>or<span/></div><button className="google" disabled={busy} onClick={google}>Continue with Google</button>{status&&<p className="status">{status}</p>}<p className="fine">Google sign-in opens your default browser and connects the selected Drive account.</p></section></main>
}
