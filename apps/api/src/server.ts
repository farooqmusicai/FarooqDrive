import fs from 'node:fs';
import path from 'node:path';
import express from 'express';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import { initDatabase } from './db/database.js';
import { migrate } from './db/migrate.js';
import { env } from './config.js';
import { authRouter } from './routes/auth.js';
import { driveRouter } from './routes/drive.js';
import { systemRouter } from './routes/system.js';
import { requireLocalOrigin } from './middleware/origin.js';

export async function startServer(opts:{host?:string;port?:number;staticDir:string;migrationDir:string}){
  initDatabase(env().FAROOQDRIVE_DATA_DIR);migrate(opts.migrationDir);
  const app=express();app.disable('x-powered-by');app.use(helmet({contentSecurityPolicy:false,crossOriginResourcePolicy:{policy:'cross-origin'}}));app.use(cookieParser());app.use(express.json({limit:'1mb'}));app.use(requireLocalOrigin);
  app.get('/health',(_req,res)=>res.json({ok:true,service:'farooqdrive'}));app.use('/api/system',systemRouter);app.use('/api/auth',authRouter);app.use('/api/drive',driveRouter);
  if(fs.existsSync(opts.staticDir)){app.use(express.static(opts.staticDir));app.use((req,res,next)=>{if(req.path.startsWith('/api/'))return next();res.sendFile(path.join(opts.staticDir,'index.html'));});}
  app.use((err:any,_req:express.Request,res:express.Response,_next:express.NextFunction)=>{console.error(err);res.status(500).json({error:err?.message||'Internal server error'});});
  return await new Promise<{server:any;url:string;port:number}>((resolve,reject)=>{const server=app.listen(opts.port??0,opts.host??'127.0.0.1',()=>{const a=server.address();const port=typeof a==='object'&&a?a.port:opts.port??0;resolve({server,url:`http://127.0.0.1:${port}`,port});});server.on('error',reject);});
}
