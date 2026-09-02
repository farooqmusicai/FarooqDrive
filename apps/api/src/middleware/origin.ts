import type { NextFunction, Request, Response } from 'express';
export function requireLocalOrigin(req: Request,res: Response,next: NextFunction) {
  const remote = req.socket.remoteAddress || '';
  if (!['127.0.0.1','::1','::ffff:127.0.0.1'].includes(remote)) return res.status(403).json({error:'Local access only'});
  if (['GET','HEAD','OPTIONS'].includes(req.method)) return next();
  const origin = req.headers.origin;
  if (!origin) return next();
  try {
    const u = new URL(origin);
    if ((u.hostname === '127.0.0.1' || u.hostname === 'localhost') && u.host === req.headers.host) return next();
  } catch {}
  return res.status(403).json({error:'Invalid origin'});
}
