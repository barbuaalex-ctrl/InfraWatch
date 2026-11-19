const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
test('admin editing, simulation failure and recovery retain incident history',async()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'infrawatch-test-'));process.env.DATA_DIR=folder;
 const app=require('./server');const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));const base=`http://127.0.0.1:${server.address().port}`;let token='';
 async function call(url,method='GET',body){const r=await fetch(base+url,{method,headers:{'Content-Type':'application/json','x-infrawatch-token':token},body:body?JSON.stringify(body):undefined});return {status:r.status,data:await r.json()}}
 try{
 assert.equal((await call('/api/simulations','POST',{mode:'down'})).status,401);
 token=(await call('/api/auth/login','POST',{password:process.env.ADMIN_PASSWORD||'infrawatch-admin'})).data.token;assert.ok(token);
 const created=await call('/api/simulations','POST',{mode:'down'});assert.equal(created.status,201);assert.equal(created.data.status,'down');assert.equal(created.data.incidents.length,1);
 const url='/api/servers/'+created.data.id;
 const detected=await call('/api/servers','POST',{name:'Automatic protocol test',url:base.replace('http://','')+'/health'});assert.equal(detected.status,201);assert.equal(detected.data.url,base+'/health');assert.equal(detected.data.status,'healthy');
 assert.equal((await call('/api/servers','POST',{name:'Invalid protocol',url:'ftp://example.com'})).status,400);
 assert.equal((await call(url,'PATCH',{name:'Should not save',intervalSeconds:1})).status,400);
 const list=await call('/api/servers');assert.notEqual(list.data.find(t=>t.id===created.data.id).name,'Should not save');
 assert.equal((await call(url,'PATCH',{name:'Recovered test',simulation:'healthy',intervalSeconds:10,slowThresholdMs:1500})).status,200);
 const checked=await call(url+'/check','POST');assert.equal(checked.data.status,'healthy');assert.ok(checked.data.incidents[0].resolvedAt);assert.equal(checked.data.history.length,2);
 const stored=JSON.parse(fs.readFileSync(path.join(folder,'targets.json'),'utf8'));assert.equal(stored.find(t=>t.id===created.data.id).name,'Recovered test');
 assert.equal((await call(url,'PATCH',{paused:true})).status,200);
 assert.equal((await call(url+'/check','POST')).data.history.length,2);
 assert.equal((await call(url,'PATCH',{paused:false})).status,200);
 assert.equal((await call(url+'/check','POST')).data.history.length,3);
 const status=await call('/api/auth/status');assert.equal(status.data.authenticated,true);assert.ok(status.data.expiresAt>Date.now());
 await call('/api/auth/logout','POST');assert.equal((await call(url,'PATCH',{paused:true})).status,401);
 token=(await call('/api/auth/login','POST',{password:process.env.ADMIN_PASSWORD||'infrawatch-admin'})).data.token;
 assert.equal((await call('/api/auth/password','POST',{currentPassword:'wrong',newPassword:'new-secure-password'})).status,400);
 assert.equal((await call('/api/auth/password','POST',{currentPassword:process.env.ADMIN_PASSWORD||'infrawatch-admin',newPassword:'new-secure-password'})).status,200);
 assert.equal((await call('/api/auth/status')).data.authenticated,false);
 assert.equal((await call('/api/auth/login','POST',{password:'new-secure-password'})).status,200);
 const passwordFile=fs.readFileSync(path.join(folder,'admin-password.json'),'utf8');assert.ok(!passwordFile.includes('new-secure-password'));
 }finally{await new Promise(r=>server.close(r));fs.rmSync(folder,{recursive:true,force:true})}
});
