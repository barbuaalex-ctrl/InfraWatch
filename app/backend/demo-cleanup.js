const seededNames=new Map([[1,'api-prod-01'],[2,'web-prod-01'],[3,'worker-stg-01'],[4,'db-prod-01']]);
function removeSeededDemos(targets){return targets.filter(t=>!(seededNames.get(t.id)===t.name&&!t.url&&!t.kind));}
module.exports={removeSeededDemos};
