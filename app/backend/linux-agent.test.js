const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');
const {unzipSync, strFromU8} = require('fflate');
const release = require('./agent-release');
const {isDeviceAgent} = require('./device-types');

test('Linux ZIP uses the shared release and ships no pairing secrets', () => {
  const entries = unzipSync(release.buildLinuxArchive({serverUrl: 'https://monitor.example', token: 'never-ship'}));
  assert.ok(Object.keys(entries).every(name => name.startsWith('InfraWatch-Agent/')));
  assert.ok(entries['InfraWatch-Agent/agent.py']);
  assert.ok(entries['InfraWatch-Agent/README.txt']);
  assert.equal(JSON.parse(strFromU8(entries['InfraWatch-Agent/version.json'])).version, release.version);
  assert.deepEqual(JSON.parse(strFromU8(entries['InfraWatch-Agent/config.json'])), {serverUrl: 'https://monitor.example'});
  assert.equal(entries['InfraWatch-Agent/connection.json'], undefined);
  assert.equal(release.updateManifest().linux.downloadUrl, '/agent/linux.zip');
  assert.match(release.linuxFilename, new RegExp(`linux-v${release.version.replaceAll('.', '\\.')}\\.zip$`));
  assert.ok(isDeviceAgent({kind: 'linux-agent'}));
  assert.ok(isDeviceAgent({kind: 'windows-agent'}));
  assert.equal(isDeviceAgent({kind: 'website'}), false);
});

test('Linux pairing, metric delivery, alerts and reconnection work with the real Python client', {timeout: 30000}, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'iw-linux-'));
  process.env.DATA_DIR = path.join(dir, 'data');
  const app = require('./server');
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const post = (route, body, headers={}) => fetch(base+route, {method:'POST', headers:{'Content-Type':'application/json',...headers}, body:JSON.stringify(body)});
  let child;
  try {
    const login = await (await post('/api/auth/login', {password:process.env.ADMIN_PASSWORD || 'infrawatch-admin'})).json();
    const admin = {'x-infrawatch-token':login.token};
    assert.equal((await fetch(base+'/agent/linux.zip')).status, 401);
    const zip = await fetch(base+'/agent/linux.zip', {headers:admin});
    assert.equal(zip.status, 200);
    assert.ok(zip.headers.get('content-disposition').includes(release.linuxFilename));
    assert.equal((await post('/api/pairing/request', {platform:'unsupported', inventory:{hostname:'test'}})).status, 400);
    const proc = path.join(dir, 'proc'); fs.mkdirSync(proc);
    fs.writeFileSync(path.join(proc,'stat'), 'cpu 100 0 100 700 100 0 0 0 0 0\n');
    fs.writeFileSync(path.join(proc,'meminfo'), 'MemTotal: 8388608 kB\nMemAvailable: 2097152 kB\n');
    fs.writeFileSync(path.join(proc,'uptime'), '1234.5 900.0\n');
    fs.writeFileSync(path.join(proc,'cpuinfo'), 'processor : 0\nmodel name : Fixture CPU\nphysical id : 0\ncore id : 0\n');
    const driver = `import importlib.util, pathlib, sys
spec=importlib.util.spec_from_file_location('agent',sys.argv[1])
agent=importlib.util.module_from_spec(spec)
spec.loader.exec_module(agent)
agent.PROC_DIR=pathlib.Path(sys.argv[2])
agent.platform.freedesktop_os_release=lambda:{'PRETTY_NAME':'Debian GNU/Linux 13'}
agent.socket.gethostname=lambda:'ec2-linux-test'
file=pathlib.Path(sys.argv[3])
connection=agent.load_connection(file)
if connection is None:
    connection=agent.pair(sys.argv[4])
    agent.save_connection(file,connection)
agent.run(connection,agent.read_version(),once=True)
`;
    const driverPath = path.join(dir,'driver.py'); fs.writeFileSync(driverPath,driver);
    const stateFile = path.join(dir,'private-state','connection.json');
    let approvalCount = 0;
    const runClient = () => new Promise((resolve,reject) => {
      child=spawn(process.platform==='win32'?'python':'python3', ['-u',driverPath,path.join(__dirname,'../agent/linux/agent.py'),proc,stateFile,base]);
      let output='', errors='', approving=false;
      child.stdout.on('data', async chunk => {
        output+=chunk;
        const match=output.match(/Pairing code: ([A-Z2-9]{3}-[A-Z2-9]{3})/);
        if(match&&!approving){approving=true;try{const response=await post('/api/pairing/approve',{code:match[1]},admin);assert.equal(response.status,201);approvalCount++;}catch(error){child.kill();reject(error)}}
      });
      child.stderr.on('data',chunk=>errors+=chunk);
      child.on('error',reject);
      child.on('exit',code=>code===0?resolve(output):reject(new Error(`Python exited ${code}: ${errors}`)));
    });
    const output=await runClient();
    let devices=await (await fetch(base+'/api/servers',{headers:admin})).json();
    assert.equal(devices.length,1);
    const device=devices[0];
    assert.equal(device.kind,'linux-agent');
    assert.equal(device.environment,'linux');
    assert.equal(device.hostname,'ec2-linux-test');
    assert.equal(device.inventory.osName,'Debian GNU/Linux 13');
    assert.equal(device.agentVersion,release.version);
    assert.equal(device.status,'healthy');
    assert.equal(device.gpu,null);
    assert.equal(device.systemDrive,'/');
    assert.equal(device.ram,75);
    assert.equal(device.metricsHistory.length,1);
    const connection=JSON.parse(fs.readFileSync(stateFile));
    assert.ok(!output.includes(connection.token));
    assert.ok(!JSON.stringify(devices).includes(connection.token));
    await runClient();
    devices=await (await fetch(base+'/api/servers',{headers:admin})).json();
    assert.equal(devices.length,1);
    assert.equal(approvalCount,1);
    assert.equal(devices[0].metricsHistory.length,2);
    const updated=await fetch(base+'/api/servers/'+device.id,{method:'PATCH',headers:{...admin,'Content-Type':'application/json'},body:JSON.stringify({thresholds:{cpu:60},name:'Linux server'})});
    assert.equal(updated.status,200);
    const metric={cpu:95,ram:40,disk:30,uptimeSeconds:500,hostname:'ec2-linux-test'};
    assert.equal((await post('/api/agents/'+device.id+'/metrics',metric,{'x-agent-token':'wrong'})).status,401);
    assert.equal((await post('/api/agents/'+device.id+'/metrics',{...metric,cpu:101},{'x-agent-token':connection.token})).status,400);
    assert.equal((await post('/api/agents/'+device.id+'/metrics',metric,{'x-agent-token':connection.token})).status,200);
    devices=await (await fetch(base+'/api/servers',{headers:admin})).json();
    assert.equal(devices[0].deviceAlerts[0].metric,'cpu');
    assert.equal(devices[0].deviceAlerts[0].threshold,60);
    await fetch(base+'/api/servers/'+device.id,{method:'PATCH',headers:{...admin,'Content-Type':'application/json'},body:JSON.stringify({paused:true})});
    assert.equal((await post('/api/agents/'+device.id+'/metrics',metric,{'x-agent-token':connection.token})).status,409);
  } finally {
    if(child&&child.exitCode===null)child.kill();
    await new Promise(resolve=>server.close(resolve));
    fs.rmSync(dir,{recursive:true,force:true});
  }
});


test('registered offline detector includes Linux and Windows devices, excluding websites and paused devices', () => {
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'iw-offline-'));
  const stale=new Date(Date.now()-40000).toISOString();
  const devices=[{kind:'linux-agent',lastSeen:stale},{kind:'windows-agent',lastSeen:stale},{kind:'linux-agent',lastSeen:stale,paused:true},{kind:'website',lastSeen:stale}];
  let tick,saved=0,published=0;
  const original=setInterval;
  try {
    global.setInterval=(callback)=>{tick=callback;return {unref(){}};};
    require('./agents')({get(){},post(){}},{servers:()=>devices,save(){saved++;},publish(){published++;},requireAdmin(){},dataDir:dir});
  } finally {global.setInterval=original;}
  try {
    tick();
    assert.equal(devices[0].status,'down');
    assert.equal(devices[1].status,'down');
    assert.equal(devices[2].status,undefined);
    assert.equal(devices[3].status,undefined);
    assert.ok(devices[0].deviceAlerts.some(a=>a.metric==='connection'));
    assert.equal(saved,1);assert.equal(published,1);
    tick();assert.equal(saved,1);
  } finally {fs.rmSync(dir,{recursive:true,force:true});}
});
