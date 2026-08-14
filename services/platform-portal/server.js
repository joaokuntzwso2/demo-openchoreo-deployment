const fs=require('fs');
const path=require('path');
const {start,json,text,body}=require('../lib/http');
const index=fs.readFileSync(path.join(__dirname,'index.html'),'utf8');

async function call(base,route,{method='GET',payload}={}){
  if(!base) throw new Error(`Dependency for ${route} is not configured`);
  const r=await fetch(base+route,{method,headers:payload?{'content-type':'application/json'}:undefined,body:payload?JSON.stringify(payload):undefined,signal:AbortSignal.timeout(8000)});
  const raw=await r.text();
  let data={}; try{data=raw?JSON.parse(raw):{}}catch{data={raw};}
  if(!r.ok) throw new Error(`${route} -> HTTP ${r.status}: ${raw.slice(0,240)}`);
  return data;
}
const dep={
 financial:()=>process.env.FINANCIAL_BFF_URL,
 subscriber:()=>process.env.TELCO_SUBSCRIBER_URL,
 network:()=>process.env.TELCO_NETWORK_URL,
 commercial:()=>process.env.TELCO_COMMERCIAL_URL,
 policy:()=>process.env.TELCO_POLICY_URL,
 bss:()=>process.env.TELCO_BSS_URL,
 telcoPortal:()=>process.env.TELCO_PORTAL_URL,
 ops:()=>process.env.OPS_CONSOLE_URL,
};
async function health(name,base){try{const d=await call(base,'/health');return {name,ok:true,service:d.service||name}}catch(e){return {name,ok:false,error:e.message}}}

start({name:'platform-portal',routes:async(req,res,u)=>{
  if(req.method==='GET'&&u.pathname==='/') return text(res,200,index,'text/html; charset=utf-8');
  if(req.method==='GET'&&u.pathname==='/api/status'){
    const services=await Promise.all([
      health('Financial Experience',dep.financial()),health('Subscriber & BSS',dep.subscriber()),
      health('Network & QoD',dep.network()),health('Commercial',dep.commercial()),health('Policy',dep.policy()),
      health('Legacy BSS Facade',dep.bss()),health('Telco Experience',dep.telcoPortal()),health('Kubernetes Ops',dep.ops())
    ]);
    return json(res,200,{platform:'OpenChoreo',environment:'development',services,healthy:services.filter(x=>x.ok).length,total:services.length});
  }
  if(req.method==='GET'&&u.pathname==='/api/financial/overview') return json(res,200,await call(dep.financial(),`/api/overview?customerId=${encodeURIComponent(u.searchParams.get('customerId')||'C001')}`));
  if(req.method==='GET'&&u.pathname==='/api/financial/payments') return json(res,200,await call(dep.financial(),'/api/payments'));
  if(req.method==='POST'&&u.pathname==='/api/financial/pay') return json(res,200,await call(dep.financial(),'/api/pay',{method:'POST',payload:await body(req)}));
  if(req.method==='GET'&&u.pathname==='/api/telco/subscribers') return json(res,200,await call(dep.subscriber(),'/api/subscribers'));
  let m=u.pathname.match(/^\/api\/telco\/subscribers\/([^/]+)$/); if(req.method==='GET'&&m) return json(res,200,await call(dep.subscriber(),`/api/subscribers/${m[1]}/status`));
  if(req.method==='GET'&&u.pathname==='/api/telco/network') return json(res,200,await call(dep.network(),'/api/network/summary'));
  if(req.method==='GET'&&u.pathname==='/api/telco/outages') return json(res,200,await call(dep.network(),'/api/outages'));
  if(req.method==='POST'&&u.pathname==='/api/telco/qod') return json(res,200,await call(dep.network(),'/api/qod/sessions',{method:'POST',payload:await body(req)}));
  m=u.pathname.match(/^\/api\/telco\/wallets\/([^/]+)$/); if(req.method==='GET'&&m) return json(res,200,await call(dep.commercial(),`/api/wallets/${m[1]}`));
  if(req.method==='POST'&&u.pathname==='/api/telco/policy') return json(res,200,await call(dep.policy(),'/api/policy/evaluate',{method:'POST',payload:await body(req)}));
  m=u.pathname.match(/^\/api\/telco\/billing\/([^/]+)$/); if(req.method==='GET'&&m) return json(res,200,await call(dep.bss(),`/api/billing/${m[1]}`));
  return false;
}});
