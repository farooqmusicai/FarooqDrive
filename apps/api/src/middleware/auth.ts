import type { NextFunction, Request, Response } from 'express';
import crypto from 'node:crypto';
import { env } from '../config.js';

declare global { namespace Express { interface Request { userId?: string } } }

function sign(value: string) { return crypto.createHmac('sha256', env().JWT_SECRET).update(value).digest('base64url'); }
export function issueSession(res: Response, userId: string) {
  const payload = Buffer.from(JSON.stringify({ sub:userId, exp:Date.now()+7*86400000 })).toString('base64url');
  res.cookie('farooqdrive_session', `${payload}.${sign(payload)}`, { httpOnly:true, sameSite:'lax', secure:false, maxAge:7*86400000, path:'/' });
}
export function sessionUserId(req: Request): string | null {
  const token = req.cookies?.farooqdrive_session as string | undefined;
  if (!token) return null;
  const [payload,sig] = token.split('.');
  if (!payload || !sig) return null;
  const expected = sign(payload);
  if (sig.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(sig),Buffer.from(expected))) return null;
  try {
    const data = JSON.parse(Buffer.from(payload,'base64url').toString());
    if (!data.sub || Date.now() > data.exp) throw new Error('expired');
    return String(data.sub);
  } catch { return null; }
}
export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const userId=sessionUserId(req);
  if(!userId) return res.status(401).json({error:'Unauthenticated'});
  req.userId=userId; next();
}
