const {start,json,body,log,metricLine} = require('../lib/http');
let checks=0;
const sanctions=['Test Sanctioned Person','Acme Blocked Trading LLC'];
start({name:'compliance-service',metrics:()=>[metricLine('platform_demo_compliance_checks_total',{},checks)],routes:async(req,res,u,ctx)=>{
  if(req.method==='POST'&&u.pathname==='/api/compliance/check'){checks++; const p=await body(req); const hit=sanctions.some(x=>(p.beneficiaryName||'').toLowerCase()===x.toLowerCase()); const highRiskCountry=['IR','KP','SY'].includes(p.destinationCountry); const decision=(hit||highRiskCountry)?'HOLD':'CLEAR'; const reasons=[...(hit?['SANCTIONS_MATCH']:[]),...(highRiskCountry?['HIGH_RISK_JURISDICTION']:[])]; log('compliance_check',{decision,reasons,correlationId:ctx.correlation}); return json(res,200,{decision,reasons,screeningListVersion:'demo-2026-08',checkedAt:new Date().toISOString()});}
  if(req.method==='GET'&&u.pathname==='/api/compliance/policies') return json(res,200,{policies:[{id:'AML-001',name:'Sanctions screening',mode:'ENFORCE'},{id:'PAY-007',name:'High-value transfer review',threshold:50000,currency:'USD-equivalent'},{id:'KYC-003',name:'KYC recertification',mode:'ENFORCE'}]});
  return false;
}});
