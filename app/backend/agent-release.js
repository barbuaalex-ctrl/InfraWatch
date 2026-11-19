const fs=require('node:fs'),path=require('node:path');
const {zipSync,strToU8}=require('fflate');
const release=require('../agent/version.json');
const filename=`${release.name}-v${release.version}.zip`;
function buildAgentArchive(config,readme){return Buffer.from(zipSync({'InfraWatch-Agent':{
 'Agent.ps1':new Uint8Array(fs.readFileSync(path.join(__dirname,'../agent/Pairing-Agent.ps1'))),
 'Start Agent.cmd':new Uint8Array(fs.readFileSync(path.join(__dirname,'../agent/Start Agent.cmd'))),
 'Update-Agent.ps1':new Uint8Array(fs.readFileSync(path.join(__dirname,'../agent/Update-Agent.ps1'))),
 'version.json':strToU8(JSON.stringify(release,null,2)),
 'config.json':strToU8(JSON.stringify(config,null,2)),
 'READ ME.txt':strToU8(`${release.name} v${release.version}\r\n\r\n${readme}`)
}}));}
let updateCache;
function updateArchive(){if(!updateCache){const files={};for(const file of ['Pairing-Agent.ps1','Start Agent.cmd','Update-Agent.ps1','version.json'])files[file==='Pairing-Agent.ps1'?'Agent.ps1':file]=new Uint8Array(fs.readFileSync(path.join(__dirname,'../agent',file)));updateCache=Buffer.from(zipSync({'InfraWatch-Agent':files}));}return updateCache;}
function updateManifest(){return {name:release.name,version:release.version,filename,updateUrl:'/agent/update.zip',sha256:require('node:crypto').createHash('sha256').update(updateArchive()).digest('hex')};}
module.exports={...release,filename,buildAgentArchive,updateArchive,updateManifest};
