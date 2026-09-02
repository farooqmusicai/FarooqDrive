import { Router } from 'express';
import crypto from 'node:crypto';
import { nanoid } from 'nanoid';
import { z } from 'zod';
import { all,get,run } from '../db/database.js';
import { issueSession,requireAuth,sessionUserId } from '../middleware/auth.js';
import { hashPassword,verifyPassword } from '../utils/crypto.js';
import { DRIVE_SCOPE,OIDC_SCOPES,ensureRootFolder,newOAuthClient,refreshQuota,upsertDriveAccount } from '../services/google.js';
import { googleOAuthConfigured } from '../services/oauth-config.js';

export const authRouter=Router();
const credentials=z.object({email:z.string().email().transform(v=>v.trim().toLowerCase()),password:z.string().min(10).max(200),displayName:z.string().max(255).optional()});

authRouter.post('/register',(req,res,next)=>{try{const b=credentials.parse(req.body);if(get('SELECT id FROM users WHERE email=?',[b.email]))return res.status(409).json({error:'Email already registered'});const id=nanoid();run('INSERT INTO users (id,email,password_hash,display_name) VALUES (?,?,?,?)',[id,b.email,hashPassword(b.password),b.displayName??null]);issueSession(res,id);res.status(201).json({ok:true});}catch(e){next(e)}});
authRouter.post('/login',(req,res,next)=>{try{const b=credentials.pick({email:true,password:true}).parse(req.body);const row=get<any>('SELECT id,password_hash FROM users WHERE email=?',[b.email]);if(!row?.password_hash||!verifyPassword(row.password_hash,b.password))return res.status(401).json({error:'Invalid credentials'});issueSession(res,row.id);res.json({ok:true});}catch(e){next(e)}});
authRouter.post('/logout',(_req,res)=>{res.clearCookie('farooqdrive_session',{path:'/'});res.json({ok:true})});
authRouter.get('/me',requireAuth,(req,res)=>{res.json(get<any>('SELECT id,email,display_name AS displayName,avatar_url AS avatarUrl FROM users WHERE id=?',[req.userId!])??null)});

authRouter.get('/google/start',(req,res,next)=>{try{if(!googleOAuthConfigured())return res.status(503).json({error:'Google OAuth is not configured yet. Open FarooqDrive setup and add your own Google Desktop OAuth Client ID and Client Secret.'});const purpose=String(req.query.purpose||'login');let userId:string|null=null;if(purpose==='connect'){userId=sessionUserId(req);if(!userId)return res.status(401).json({error:'Sign in first'});}
  const state=crypto.randomBytes(32).toString('base64url');run('DELETE FROM oauth_states WHERE created_at < ?',[Date.now()-15*60*1000]);run('INSERT INTO oauth_states (state,purpose,user_id,created_at) VALUES (?,?,?,?)',[state,purpose,userId,Date.now()]);
  const callback=`http://${req.headers.host}/api/auth/google/callback`;const oauth=newOAuthClient(callback);const url=oauth.generateAuthUrl({access_type:'offline',prompt:'consent select_account',include_granted_scopes:true,scope:[...OIDC_SCOPES,DRIVE_SCOPE],state});res.json({url,state});}catch(e){next(e)}});

authRouter.get('/google/callback',async(req,res,next)=>{try{const code=z.string().parse(req.query.code);const state=z.string().parse(req.query.state);const st=get<any>('SELECT * FROM oauth_states WHERE state=?',[state]);if(!st||Date.now()-Number(st.created_at)>15*60*1000)return res.status(400).send('This authorization request has expired. Return to FarooqDrive and try again.');
 const callback=`http://${req.headers.host}/api/auth/google/callback`;const oauth=newOAuthClient(callback);const {tokens}=await oauth.getToken(code);oauth.setCredentials(tokens);if(!tokens.id_token)throw new Error('Google did not return an ID token');const ticket=await oauth.verifyIdToken({idToken:tokens.id_token});const p=ticket.getPayload();if(!p?.sub||!p.email)throw new Error('Google profile is missing required fields');let userId=st.user_id as string|null;
 if(!userId){const existing=get<any>('SELECT id FROM users WHERE email=?',[p.email.toLowerCase()]);userId=existing?.id??nanoid();if(!existing)run('INSERT INTO users (id,email,display_name,avatar_url) VALUES (?,?,?,?)',[userId,p.email.toLowerCase(),p.name??null,p.picture??null]);}
 let refreshToken=tokens.refresh_token;if(!refreshToken){const known=get<any>('SELECT encrypted_refresh_token FROM drive_accounts WHERE user_id=? AND google_sub=?',[userId,p.sub]);if(!known)throw new Error('No refresh token returned. Remove FarooqDrive access from your Google account and reconnect.');run('UPDATE oauth_states SET completed_user_id=?,completed_at=? WHERE state=?',[userId,Date.now(),state]);return res.send(successHtml());}
 const accountId=upsertDriveAccount({userId,refreshToken,googleSub:p.sub,email:p.email,displayName:p.name,avatarUrl:p.picture});await ensureRootFolder(accountId,userId);await refreshQuota(accountId,userId);run('UPDATE oauth_states SET completed_user_id=?,completed_at=? WHERE state=?',[userId,Date.now(),state]);res.send(successHtml());}catch(e){next(e)}});

authRouter.get('/google/poll',(req,res)=>{const state=String(req.query.state||'');const st=get<any>('SELECT completed_user_id,created_at FROM oauth_states WHERE state=?',[state]);if(!st||Date.now()-Number(st.created_at)>15*60*1000)return res.status(404).json({done:false,error:'Authorization expired'});if(!st.completed_user_id)return res.json({done:false});issueSession(res,st.completed_user_id);run('DELETE FROM oauth_states WHERE state=?',[state]);res.json({done:true});});

function successHtml(){return `<!doctype html><html><head><meta charset="utf-8"><title>FarooqDrive</title><style>body{font-family:Segoe UI,sans-serif;background:#f4f7fb;color:#10243f;display:grid;place-items:center;height:100vh;margin:0}.c{background:white;padding:34px;border-radius:18px;box-shadow:0 18px 60px #10243f22;text-align:center;max-width:460px}h1{color:#167d55}</style></head><body><div class="c"><h1>FarooqDrive connected</h1><p>Authorization is complete. You can close this browser tab and return to FarooqDrive.</p></div></body></html>`}
