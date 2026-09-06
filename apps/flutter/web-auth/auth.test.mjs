import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const source=(await readFile(new URL('./auth.js',import.meta.url),'utf8')).replace(/^import .*;\n/,'');
function setup() {
 const state={next:'one',error:null,configs:[],cleared:[]};
 class PublicClientApplication {
  constructor(config){state.configs.push(config);}
  async initialize(){}
  async loginPopup(){if(state.error)throw state.error;return {account:{homeAccountId:state.next,username:state.next+'@example.com',name:state.next},accessToken:'login-'+state.next};}
  async acquireTokenSilent(request){state.request=request;return {accessToken:'token-'+request.account.homeAccountId};}
  async clearCache({account}){state.cleared.push(account.homeAccountId);}
 }
 const window={};
 vm.runInNewContext(source,{PublicClientApplication,BrowserCacheLocation:{MemoryStorage:'memoryStorage'},URL,document:{baseURI:'https://farooqmusicai.github.io/FarooqDrive/'},window});
 return {window,state};
}
test('separate accounts use their own token and disconnect clears only selected account',async()=>{
 const {window:w,state:s}=setup();
 const a=JSON.parse(await w.fdMicrosoftLogin('client'));s.next='two';const b=JSON.parse(await w.fdMicrosoftLogin('client'));
 assert.equal(JSON.parse(await w.fdMicrosoftToken(a.id,true)).token,'token-one');
 assert.equal(s.request.forceRefresh,true);
 await w.fdMicrosoftForget(a.id);
 assert.ok(JSON.parse(await w.fdMicrosoftToken(a.id,false)).error);
 assert.equal(JSON.parse(await w.fdMicrosoftToken(b.id,false)).token,'token-two');
 assert.deepEqual(s.cleared,['one']);
 assert.equal(s.configs[0].cache.cacheLocation,'memoryStorage');
 assert.equal(s.configs[0].auth.redirectUri,'https://farooqmusicai.github.io/FarooqDrive/microsoft-callback.html');
});
test('provider errors never expose raw error text or tokens',async()=>{
 const {window:w,state:s}=setup();s.error={errorCode:'invalid_client',message:'secret value'};
 const result=await w.fdMicrosoftLogin('client');assert.match(result,/invalid_client/);assert.doesNotMatch(result,/secret value/);
 s.error={errorCode:'https://secret.example/token'};assert.doesNotMatch(await w.fdMicrosoftLogin('client'),/secret.example/);
});
