import {build} from 'esbuild';
import {copyFile} from 'node:fs/promises';
await build({entryPoints:['auth.js','callback.js'],bundle:true,outdir:'../web',entryNames:'microsoft-[name]',format:'iife',minify:true,legalComments:'eof'});
await copyFile('node_modules/@azure/msal-browser/LICENSE','../web/MICROSOFT-AUTH-LICENSE.txt');
