import { FormEvent,useState } from 'react';
import { api } from '../lib/api';

export function GoogleSetupWizard({onDone}:{onDone:()=>void}){
  const[clientId,setClientId]=useState('');
  const[clientSecret,setClientSecret]=useState('');
  const[error,setError]=useState('');
  const[busy,setBusy]=useState(false);
  const[showSteps,setShowSteps]=useState(true);

  async function save(e:FormEvent){
    e.preventDefault();setError('');setBusy(true);
    try{
      await api('/api/system/google-oauth',{method:'POST',body:JSON.stringify({clientId,clientSecret})});
      onDone();
    }catch(e:any){setError(e.message)}finally{setBusy(false)}
  }

  return <main className="setup-shell">
    <section className="setup-card">
      <div className="brand setup-brand"><div className="logo">FD</div><div><h1>FarooqDrive setup</h1><p>Use your own Google OAuth credentials</p></div></div>
      <div className="privacy-chip">🔒 Your Client ID and Secret stay on this Windows PC.</div>
      <p className="setup-intro">FarooqDrive does not include the publisher's Google credentials. Create a free Google Cloud OAuth Desktop client for yourself, then paste its Client ID and Client Secret below.</p>

      <button className="guide-toggle" onClick={()=>setShowSteps(v=>!v)}>{showSteps?'Hide':'Show'} Google Cloud instructions</button>
      {showSteps&&<div className="setup-guide">
        <ol>
          <li><b>Create or choose a Google Cloud project.</b> <a href="https://console.cloud.google.com/projectcreate" target="_blank" rel="noreferrer">Open Google Cloud</a></li>
          <li><b>Enable Google Drive API.</b> <a href="https://console.cloud.google.com/apis/library/drive.googleapis.com" target="_blank" rel="noreferrer">Open Drive API</a></li>
          <li>Open <b>Google Auth Platform</b>, set the audience to <b>External</b>, and enter an app name.</li>
          <li>In <b>Data Access</b>, add <code>https://www.googleapis.com/auth/drive</code>. FarooqDrive needs this full Drive permission to find/sync files placed manually in each account's <b>Farooqdrive</b> folder and to rename, move, download or delete managed files across connected accounts.</li>
          <li>In <b>Clients</b>, create a new OAuth Client with application type <b>Desktop app</b>.</li>
          <li>If your OAuth project remains in <b>Testing</b>, add your Google account as a Test User. For long-term daily use, Google testing-mode refresh tokens are limited; review Google's publishing options for your own project.</li>
          <li>Copy the Desktop Client ID and Client Secret into the fields below.</li>
        </ol>
        <p className="guide-note"><b>Permission notice:</b> Google classifies full Drive access as a restricted scope. Use a Google Cloud project you control. If the project is in Testing, add every Google account you want to connect as a Test User. Google may require verification/security review for wider production use.</p>
        <p className="guide-note">Never post your Client Secret on GitHub, a forum, screenshot, or public website.</p>
      </div>}

      <form className="oauth-form" onSubmit={save}>
        <label>Google Desktop OAuth Client ID
          <input value={clientId} onChange={e=>setClientId(e.target.value)} placeholder="1234567890-….apps.googleusercontent.com" required/>
        </label>
        <label>Google Desktop OAuth Client Secret
          <input type="password" value={clientSecret} onChange={e=>setClientSecret(e.target.value)} placeholder="Paste your client secret" required/>
        </label>
        {error&&<p className="error">{error}</p>}
        <button className="primary" disabled={busy} type="submit">{busy?'Saving securely…':'Save and continue'}</button>
      </form>
      <p className="fine">FarooqDrive stores these values in its local encrypted application data. They are not added to the public source code. Your Google authorization remains tied to your own Google Cloud project.</p>
    </section>
  </main>
}
