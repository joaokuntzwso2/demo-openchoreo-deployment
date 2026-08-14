const fs=require('fs');
const path=require('path');
const {randomUUID}=require('crypto');
const {start,json,text,body}=require('../lib/http');
const index=fs.readFileSync(path.join(__dirname,'index.html'),'utf8');
async function q(base,p,opt={}){
  const r=await fetch(base+p,{...opt,signal:AbortSignal.timeout(8000)});
  const raw=await r.text(); let d; try{d=raw?JSON.parse(raw):{}}catch{d={raw}};
  if(!r.ok)throw new Error(`${p}: HTTP ${r.status}: ${raw.slice(0,160)}`); return d;
}
function ctx(req){return {partnerId:String(req.headers['x-partner-id']||'partner-alpha'),correlationId:String(req.headers['x-correlation-id']||randomUUID())}}
function headers(c){return {'content-type':'application/json','x-partner-id':c.partnerId,'x-correlation-id':c.correlationId}}
start({name:'telco-portal',routes:async(req,res,u)=>{
  const c=ctx(req);
  if(req.method==='GET'&&u.pathname==='/')return text(res,200,index,'text/html; charset=utf-8');
  if(req.method==='GET'&&u.pathname==='/api/subscribers')return json(res,200,await q(process.env.SUBSCRIBER_URL,'/api/subscribers',{headers:headers(c)}));
  let m=u.pathname.match(/^\/api\/subscriber\/([^/]+)$/);if(req.method==='GET'&&m)return json(res,200,{...(await q(process.env.SUBSCRIBER_URL,`/api/subscribers/${m[1]}/status`,{headers:headers(c)})),partnerId:c.partnerId,correlationId:c.correlationId});
  if(req.method==='GET'&&u.pathname==='/api/network')return json(res,200,{summary:await q(process.env.NETWORK_URL,'/api/network/summary',{headers:headers(c)}),outages:await q(process.env.NETWORK_URL,'/api/outages',{headers:headers(c)}),partnerId:c.partnerId,correlationId:c.correlationId});
  if(req.method==='POST'&&u.pathname==='/api/qod'){
    const p=await body(req); const country=p.country||'BR';
    const authorization=await q(process.env.COMMERCIAL_URL,'/api/authorize',{method:'POST',headers:headers(c),body:JSON.stringify({partnerId:c.partnerId,product:'5G Quality on Demand',price:0.25})});
    if(!authorization.allowed)return json(res,402,{status:'DENIED',stage:'commercial-authorization',partnerId:c.partnerId,correlationId:c.correlationId,authorization});
    const policy=await q(process.env.POLICY_URL,'/api/policy/evaluate',{method:'POST',headers:headers(c),body:JSON.stringify({partnerId:c.partnerId,country,dataResidency:p.dataResidency||country,consent:'ACTIVE',action:'QOD'})});
    if(policy.decision!=='ALLOW')return json(res,403,{status:'DENIED',stage:'policy',partnerId:c.partnerId,correlationId:c.correlationId,authorization,policy});
    const network=await q(process.env.NETWORK_URL,'/api/qod/sessions',{method:'POST',headers:headers(c),body:JSON.stringify({...p,country})});
    const settlement=await q(process.env.COMMERCIAL_URL,'/api/settle',{method:'POST',headers:headers(c),body:JSON.stringify({partnerId:c.partnerId,product:'5G Quality on Demand',outcome:network.status,charge:authorization.charge||0})});
    return json(res,200,{...network,partnerId:c.partnerId,correlationId:c.correlationId,authorization,policy,settlement});
  }
  m=u.pathname.match(/^\/api\/wallet\/([^/]+)$/);if(req.method==='GET'&&m)return json(res,200,await q(process.env.COMMERCIAL_URL,`/api/wallets/${m[1]}`,{headers:headers(c)}));
  if(req.method==='POST'&&u.pathname==='/api/policy'){const p=await body(req);return json(res,200,{...(await q(process.env.POLICY_URL,'/api/policy/evaluate',{method:'POST',headers:headers(c),body:JSON.stringify({...p,partnerId:p.partnerId||c.partnerId})})),correlationId:c.correlationId});}
  m=u.pathname.match(/^\/api\/billing\/([^/]+)$/);if(req.method==='GET'&&m)return json(res,200,{...(await q(process.env.BSS_URL,`/api/billing/${m[1]}`,{headers:headers(c)})),partnerId:c.partnerId,correlationId:c.correlationId});
  return false;
}});
