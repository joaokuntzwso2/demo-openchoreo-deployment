const {start,json,body,metricLine}=require('../lib/http');
let decisions=0;
start({name:'telco-policy-service',metrics:()=>[metricLine('platform_telco_policy_decisions_total',{},decisions)],routes:async(req,res,u)=>{
 if(req.method==='GET'&&u.pathname==='/api/policies')return json(res,200,{policies:[{id:'TEL-001',name:'Partner isolation',mode:'ENFORCE'},{id:'TEL-002',name:'Consent and purpose',mode:'ENFORCE'},{id:'TEL-003',name:'Data residency',mode:'ENFORCE'},{id:'TEL-004',name:'High-risk SIM swap',mode:'ADVISE'}]});
 if(req.method==='POST'&&u.pathname==='/api/policy/evaluate'){decisions++;const p=await body(req);const reasons=[];if(!String(p.partnerId||'').startsWith('partner-'))reasons.push('UNKNOWN_PARTNER');if(p.country==='BR'&&p.dataResidency==='OUTSIDE_BR')reasons.push('BR_DATA_RESIDENCY');if(p.consent==='EXPIRED')reasons.push('CONSENT_EXPIRED');if(p.simSwapAgeHours!=null&&Number(p.simSwapAgeHours)<24&&p.action==='NUMBER_VERIFICATION')reasons.push('RECENT_SIM_SWAP');const blocking=reasons.filter(x=>x!=='RECENT_SIM_SWAP');return json(res,200,{decisionId:`POL-${Date.now()}`,decision:blocking.length?'DENY':'ALLOW',blockingFindings:blocking,advisories:reasons.filter(x=>x==='RECENT_SIM_SWAP'),policySet:'group-baseline-2026.08'});}
 return false;
}});
