const LIMIT=90,RECOVERY=85;
function updateDeviceAlerts(agent,offline=false){
 const now=new Date().toISOString(),previous=agent.deviceAlerts||[],next=[];
 for(const metric of ['cpu','ram','gpu','disk']){
  const old=previous.find(a=>a.metric===metric),value=agent[metric];
  const limit=agent.thresholds?.[metric]??LIMIT,recovery=Math.max(0,limit-5);
  if(offline){if(old)next.push(old);continue;}
  if(typeof value==='number'&&(value>=limit||(old&&value>=recovery)))next.push({...old,metric,label:metric==='disk'?'Storage used':metric.toUpperCase(),value,threshold:limit,startedAt:old?.startedAt||now});
 }
 if(offline)next.push(previous.find(a=>a.metric==='connection')||{metric:'connection',label:'Connection lost',startedAt:now});
 agent.alertEvents||=[];agent.incidents||=[];
 for(const a of next){if(!previous.some(p=>p.metric===a.metric)){agent.alertEvents.push({...a,id:now+'-'+a.metric,type:'triggered',at:now});agent.incidents.push({startedAt:now,status:a.metric==='connection'?'down':'warning',metric:a.metric,resolvedAt:null});}}
 for(const a of previous){if(!next.some(n=>n.metric===a.metric)){agent.alertEvents.push({...a,id:now+'-'+a.metric+'-resolved',type:'resolved',at:now});const incident=agent.incidents.find(i=>i.metric===a.metric&&!i.resolvedAt);if(incident)incident.resolvedAt=now;}}
 // Close an old-format offline incident when an updated agent reconnects.
 if(!offline)agent.incidents.filter(i=>!i.metric&&i.status==='down'&&!i.resolvedAt).forEach(i=>i.resolvedAt=now);
 agent.deviceAlerts=next;agent.alertEvents=agent.alertEvents.slice(-200);agent.status=offline?'down':next.length?'warning':'healthy';return next;
}
module.exports={updateDeviceAlerts,LIMIT,RECOVERY};
