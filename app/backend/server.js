const express = require('express');
const path = require('path');
const fs = require('fs');
const crypto = require('node:crypto');
const client = require('prom-client');
const {isDeviceAgent}=require('./device-types');

const app = express();
const adminPassword = process.env.ADMIN_PASSWORD || 'infrawatch-admin';
const sessions = new Map();
const sessionTTL = Number(process.env.SESSION_TTL_MS) || 3600000;
function requestToken(req){return req.get('x-infrawatch-token')||req.get('cookie')?.split(';').map(v=>v.trim()).find(v=>v.startsWith('iw_session='))?.slice(11);}
function authenticated(req) { const token=requestToken(req);const expires=sessions.get(token);if(expires>Date.now())return true;sessions.delete(token);return false; }
const port = process.env.PORT || 3000;
const startedAt = Date.now();
const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry });
const checksTotal = new client.Counter({ name: 'infrawatch_health_checks_total', help: 'Health checks served', registers: [registry] });

app.use(express.json());
app.get('/',(_req,res)=>res.sendFile(path.join(__dirname,'../frontend/index.html')));
app.get('/admin',(_req,res)=>res.redirect('/'));
app.use('/api',(_req,res,next)=>{res.set('Cache-Control','no-store');next();});
app.use(express.static(path.join(__dirname, '../frontend')));
function requireAdmin(req, res, next) { if (authenticated(req)) return next(); return res.status(401).json({ error: 'Administrator login required.' }); }

const defaults = [];
const dataDir = process.env.DATA_DIR || path.join(__dirname, 'data');
const targetFile = path.join(dataDir, 'targets.json');
fs.mkdirSync(dataDir, { recursive: true });
const passwordFile=path.join(dataDir,'admin-password.json');
function hashPassword(password,salt){return crypto.scryptSync(password,salt,64).toString('hex');}
let passwordRecord;try{passwordRecord=JSON.parse(fs.readFileSync(passwordFile,'utf8'));}catch{const salt=crypto.randomBytes(16).toString('hex');passwordRecord={salt,hash:hashPassword(adminPassword,salt)};}
function validPassword(value){return typeof value==='string'&&value.length<=256&&crypto.timingSafeEqual(Buffer.from(hashPassword(value,passwordRecord.salt),'hex'),Buffer.from(passwordRecord.hash,'hex'));}
let servers;
try { servers = JSON.parse(fs.readFileSync(targetFile, 'utf8')); } catch { servers = defaults; }
const cleanedTargets=require('./demo-cleanup').removeSeededDemos(servers);
if(cleanedTargets.length!==servers.length){fs.copyFileSync(targetFile,path.join(dataDir,'targets-before-demo-cleanup-'+Date.now()+'.json'));servers=cleanedTargets;fs.writeFileSync(targetFile,JSON.stringify(servers,null,2));}
servers.forEach(target=>{target.checking=false;});
const saveTargets = () => fs.writeFileSync(targetFile, JSON.stringify(servers, null, 2));
const liveClients = new Map();
function closeInvalidStreams(){for(const [res,token]of liveClients){if(!(sessions.get(token)>Date.now())){res.end();liveClients.delete(res);}}}
const privateHeartbeat=setInterval(()=>{closeInvalidStreams();liveClients.forEach((_token,res)=>res.write(': keep-alive\n\n'));},15000);privateHeartbeat.unref();
function normalizeWebsite(value){
 if(typeof value!=='string'||!value.trim()||/\s/.test(value.trim()))throw Error('Enter a valid website address.');
 const input=value.trim();const hasScheme=/^[a-z][a-z0-9+.-]*:\/\//i.test(input);
 const url=new URL(hasScheme?input:'https://'+input);
 if(!['http:','https:'].includes(url.protocol)||!url.hostname||url.username||url.password)throw Error('Enter an HTTP(S) website without credentials.');
 return {url:url.toString(),autoProtocol:!hasScheme};
}
function publish(event, data) { closeInvalidStreams();const message = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`; liveClients.forEach((_token,res) => res.write(message)); }
async function checkTarget(target) {
  if (!target.url || target.paused) return target;
  if (target.checking) return target;
  target.checking = true;
  const started = Date.now();
  try {
    let response;
    if(target.simulation){response={ok:target.simulation!=='down',status:target.simulation==='down'?503:200};}
    else {try{response=await fetch(target.url,{redirect:'follow',signal:AbortSignal.timeout(8000)});}catch(error){
      if(!target.autoProtocol||!target.url.startsWith('https://'))throw error;
      const fallback=new URL(target.url);fallback.protocol='http:';
      response=await fetch(fallback,{redirect:'follow',signal:AbortSignal.timeout(8000)});target.url=fallback.toString();
    }}
    if (target.simulation === 'slow') await new Promise(resolve => setTimeout(resolve, 2200));
    const responseTime = Date.now() - started;
    Object.assign(target, { status: response.ok ? (responseTime > (target.slowThresholdMs || 1500) ? 'warning' : 'healthy') : 'down', responseTime, httpStatus: response.status, lastError: null, lastCheck: 'just now', lastCheckedAt: new Date().toISOString() });
    if (response.body) await response.body.cancel();
  } catch (error) {
    Object.assign(target, { status: 'down', responseTime: null, httpStatus: null, lastCheck: 'failed', lastError: error.cause?.code || error.name, lastCheckedAt: new Date().toISOString() });
  }
  target.checking = false;
  target.incidents ||= [];
  const open = target.incidents.find(i => !i.resolvedAt);
  if (target.status !== 'healthy' && !open) target.incidents.push({ startedAt: target.lastCheckedAt, status: target.status, resolvedAt: null });
  if (open && target.status === 'healthy') open.resolvedAt = target.lastCheckedAt;
  target.history = [...(target.history || []), { at: target.lastCheckedAt, status: target.status, responseTime: target.responseTime, httpStatus: target.httpStatus }].slice(-1440);
  return target;
}
async function refreshTargets() { const due=servers.filter(s => s.url && !s.paused && !s.checking && (!s.lastCheckedAt || Date.now()-Date.parse(s.lastCheckedAt)>=(s.intervalSeconds||60)*1000));if(!due.length)return;await Promise.all(due.map(checkTarget));saveTargets();publish('targets',servers); }

app.get('/api/servers', requireAdmin, (_req, res) => res.json(servers));
app.post('/api/auth/login', (req, res) => { if (!validPassword(req.body?.password)) return res.status(401).json({ error: 'Incorrect password.' });for(const [key,value] of sessions){if(value<=Date.now())sessions.delete(key);}const token=crypto.randomUUID(),expiresAt=Date.now()+sessionTTL;sessions.set(token,expiresAt);res.cookie('iw_session',token,{httpOnly:true,sameSite:'strict',secure:req.secure,path:'/',maxAge:sessionTTL});res.json({token,expiresAt}); });
app.get('/api/auth/status', (req, res) => res.json({ authenticated:authenticated(req),expiresAt:sessions.get(requestToken(req))||null }));
app.post('/api/auth/logout',(req,res)=>{sessions.delete(requestToken(req));res.clearCookie('iw_session',{path:'/'});closeInvalidStreams();res.json({ok:true});});
app.post('/api/auth/password',requireAdmin,(req,res)=>{if(!validPassword(req.body.currentPassword))return res.status(400).json({error:'Current password is incorrect.'});if(typeof req.body.newPassword!=='string'||req.body.newPassword.length<12||req.body.newPassword.length>256)return res.status(400).json({error:'Use a password of 12–256 characters.'});const salt=crypto.randomBytes(16).toString('hex');const record={salt,hash:hashPassword(req.body.newPassword,salt)};fs.writeFileSync(passwordFile,JSON.stringify(record),{mode:0o600});passwordRecord=record;sessions.clear();res.json({ok:true});});
app.get('/api/events', requireAdmin, (req, res) => { res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-store', Connection: 'keep-alive' }); res.write(`event: targets\ndata: ${JSON.stringify(servers)}\n\n`); liveClients.set(res,requestToken(req)); req.on('close', () => liveClients.delete(res)); });
app.get('/api/servers/:id/history', requireAdmin, (req, res) => { const target = servers.find(s => String(s.id) === req.params.id); if (!target) return res.status(404).json({ error: 'Target not found.' }); res.json(target.history || []); });
app.get('/api/summary', requireAdmin, (_req, res) => {
  const healthy = servers.filter(s => s.status === 'healthy').length;
  res.json({ total: servers.length, healthy, warning: servers.filter(s => s.status === 'warning').length, down: servers.filter(s => s.status === 'down').length, averageCpu: Math.round(servers.filter(s => typeof s.cpu === 'number').reduce((n,s) => n+s.cpu,0) / (servers.filter(s => typeof s.cpu === 'number').length || 1)), averageRam: Math.round(servers.filter(s => typeof s.ram === 'number').reduce((n,s) => n+s.ram,0) / (servers.filter(s => typeof s.ram === 'number').length || 1)) });
});
app.post('/api/servers', requireAdmin, async (req, res) => {
  const { name, url } = req.body || {};
  if (!name || typeof name !== 'string' || name.length > 60) return res.status(400).json({ error: 'A name of up to 60 characters is required.' });
  let parsed; try { parsed = normalizeWebsite(url); } catch(error) { return res.status(400).json({ error:error.message }); }
  if (servers.length >= 25) return res.status(400).json({ error: 'Maximum of 25 monitored targets reached.' });
  const target = { id: crypto.randomUUID(), name: name.trim(), url: parsed.url, autoProtocol:parsed.autoProtocol, environment: 'external', status: 'checking', cpu: null, ram: null, uptime: 'URL check', lastCheck: 'checking' };
  servers.push(target); await checkTarget(target); saveTargets(); publish('targets', servers); res.status(201).json(target);
});
app.post('/api/servers/:id/check', requireAdmin, async (req, res) => { const target = servers.find(s => String(s.id) === req.params.id); if (!target) return res.status(404).json({ error: 'Target not found.' }); await checkTarget(target); saveTargets(); publish('targets', servers); res.json(target); });
app.patch('/api/servers/:id', requireAdmin, (req, res) => {
 const target=servers.find(s=>String(s.id)===req.params.id); if(!target)return res.status(404).json({error:'Target not found.'});
 const next={};
 if('thresholds' in req.body){if(!isDeviceAgent(target)||!req.body.thresholds||typeof req.body.thresholds!=='object'||Array.isArray(req.body.thresholds))return res.status(400).json({error:'Invalid device thresholds.'});next.thresholds={...(target.thresholds||{})};for(const [metric,value] of Object.entries(req.body.thresholds)){if(!['cpu','ram','gpu','disk'].includes(metric)||!Number.isInteger(value)||value<10||value>100)return res.status(400).json({error:'Thresholds must be whole percentages from 10 to 100.'});next.thresholds[metric]=value;}}
 if('paused' in req.body){if(typeof req.body.paused!=='boolean')return res.status(400).json({error:'Invalid pause state.'});if(target.checking)return res.status(409).json({error:'A check is running. Try again in a moment.'});next.paused=req.body.paused;}
 if('name' in req.body){if(typeof req.body.name!=='string'||!req.body.name.trim()||req.body.name.length>60)return res.status(400).json({error:'Name must contain 1–60 characters.'});next.name=req.body.name.trim();}
 if('url' in req.body){try{Object.assign(next,normalizeWebsite(req.body.url));}catch(error){return res.status(400).json({error:error.message});}}
 for(const [key,min,max] of [['intervalSeconds',10,3600],['slowThresholdMs',100,8000]]){if(key in req.body){const value=req.body[key];if(!Number.isInteger(value)||value<min||value>max)return res.status(400).json({error:`${key} must be between ${min} and ${max}.`});next[key]=value;}}
 if('simulation' in req.body){if(!target.simulation||!['healthy','slow','down'].includes(req.body.simulation))return res.status(400).json({error:'Invalid simulation mode.'});next.simulation=req.body.simulation;}
 Object.assign(target,next);if(next.thresholds&&target.lastSeen&&!target.paused)require('./device-alerts').updateDeviceAlerts(target,Date.now()-Date.parse(target.lastSeen)>30000);saveTargets();publish('targets',servers);res.json(target);
});
app.post('/api/simulations',requireAdmin,async(req,res)=>{if(!['healthy','slow','down'].includes(req.body.mode))return res.status(400).json({error:'Invalid simulation mode.'});if(servers.length>=25)return res.status(400).json({error:'Maximum 25 monitors.'});const target={id:crypto.randomUUID(),name:`Test · ${req.body.mode}`,url:'https://simulation.invalid/',simulation:req.body.mode,environment:'simulation',cpu:null,ram:null,intervalSeconds:10,slowThresholdMs:1500};servers.push(target);await checkTarget(target);saveTargets();publish('targets',servers);res.status(201).json(target);});
app.delete('/api/servers/:id', requireAdmin, (req, res) => { const before = servers.length; servers = servers.filter(s => String(s.id) !== req.params.id); if (servers.length === before) return res.status(404).json({ error: 'Target not found.' }); saveTargets(); publish('targets', servers); res.status(204).end(); });
app.get('/health', (req, res) => { checksTotal.inc(); res.json(authenticated(req)?{ status: 'ok', uptimeSeconds: Math.floor((Date.now() - startedAt)/1000), timestamp: new Date().toISOString() }:{status:'ok'}); });
app.get('/metrics', requireAdmin, async (_req, res) => { res.set('Content-Type', registry.contentType); res.end(await registry.metrics()); });
require('./agents')(app,{servers:()=>servers,save:saveTargets,publish,requireAdmin,dataDir});
app.use((req, res) => res.status(404).json({ error: 'Not found', path: req.path }));

if (require.main === module) { refreshTargets().finally(() => app.listen(port, () => console.log(`InfraWatch API listening on ${port}`))); setInterval(refreshTargets, 1000).unref(); }
module.exports = app;
