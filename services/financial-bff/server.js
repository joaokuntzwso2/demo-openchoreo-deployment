const fs=require('fs'); const path=require('path'); const {start,json,text,body}=require('../lib/http');
const index=fs.readFileSync(path.join(__dirname,'index.html'),'utf8');
async function fetchJson(url,options={}){const r=await fetch(url,{...options,signal:AbortSignal.timeout(8000)});const raw=await r.text();let data;try{data=raw?JSON.parse(raw):{}}catch{throw new Error(`upstream ${url} returned non-JSON HTTP ${r.status}`)}return {status:r.status,ok:r.ok,data};}
async function get(base,p){const out=await fetchJson(base+p);if(!out.ok)throw new Error(`${p} ${out.status}`);return out.data;}
async function post(base,p,payload,headers={}){const out=await fetchJson(base+p,{method:'POST',headers:{'content-type':'application/json',...headers},body:JSON.stringify(payload)});return {status:out.status,data:out.data};}
start({name:'financial-bff',routes:async(req,res,u,ctx)=>{
  if(req.method==='GET'&&u.pathname==='/') return text(res,200,index,'text/html; charset=utf-8');
  if(req.method==='GET'&&u.pathname==='/api/overview'){const customerId=u.searchParams.get('customerId')||'C001'; const [customer,acct,policies,signals]=await Promise.all([get(process.env.ACCOUNTS_API_URL,`/api/customers/${customerId}`),get(process.env.ACCOUNTS_API_URL,`/api/customers/${customerId}/accounts`),get(process.env.COMPLIANCE_API_URL,'/api/compliance/policies'),get(process.env.FRAUD_API_URL,'/api/fraud/signals')]); return json(res,200,{customer,accounts:acct.accounts,policies:policies.policies,signals:signals.signals,platform:{runtime:'OpenChoreo',cell:'experience'}});}
  if(req.method==='POST'&&u.pathname==='/api/pay'){const p=await body(req);const out=await post(process.env.PAYMENTS_API_URL,'/api/payments',p,{'x-correlation-id':ctx.correlation});return json(res,out.status,out.data);}
  if(req.method==='GET'&&u.pathname==='/api/payments'){const out=await get(process.env.PAYMENTS_API_URL,'/api/payments'); return json(res,200,out);}
  return false;
}});
