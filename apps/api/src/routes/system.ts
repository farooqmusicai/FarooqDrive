import { Router } from 'express';
import { z } from 'zod';
import { get } from '../db/database.js';
import { googleOAuthConfigured,googleOAuthPublicInfo,saveGoogleOAuthConfig } from '../services/oauth-config.js';

export const systemRouter=Router();

systemRouter.get('/status',(_req,res)=>{
  const oauth=googleOAuthPublicInfo();
  const driveAccountCount=Number(get<any>('SELECT COUNT(*) AS count FROM drive_accounts')?.count??0);
  res.json({
    app:'FarooqDrive',
    version:process.env.FAROOQDRIVE_VERSION||process.env.npm_package_version||'0.9.3',
    googleOAuthConfigured:oauth.configured,
    googleOAuthClientHint:oauth.clientIdHint,
    driveAccountCount,
    platform:process.platform
  });
});

systemRouter.post('/google-oauth',(req,res,next)=>{
  try{
    const b=z.object({
      clientId:z.string().trim().min(40).max(300),
      clientSecret:z.string().trim().min(4).max(300)
    }).parse(req.body);

    const existingCount=Number(get<any>('SELECT COUNT(*) AS count FROM drive_accounts')?.count??0);
    if(existingCount>0 && googleOAuthConfigured()){
      return res.status(409).json({
        error:'Disconnect all Google Drive accounts before replacing the Google OAuth Client ID and Secret.'
      });
    }
    saveGoogleOAuthConfig(b);
    res.json({...googleOAuthPublicInfo(),ok:true});
  }catch(e){next(e)}
});
