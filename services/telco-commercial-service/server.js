const {start,json,body,metricLine}=require('../lib/http');
const wallets={'partner-alpha':{partnerId:'partner-alpha',plan:'Gold API Partner',currency:'USD',balance:2500,includedUnits:1000,usedUnits:327},'partner-beta':{partnerId:'partner-beta',plan:'Prepaid Starter',currency:'USD',balance:95,includedUnits:100,usedUnits:91}};
const ledger=[];
start({name:'telco-commercial-service',metrics:()=>[metricLine('platform_telco_commercial_events_total',{},ledger.length)],routes:async(req,res,u)=>{
 let m=u.pathname.match(/^\/api\/wallets\/([^/]+)$/); if(req.method==='GET'&&m){const w=wallets[m[1]];return w?json(res,200,{...w,remainingIncluded:Math.max(0,w.includedUnits-w.usedUnits)}):json(res,404,{error:'partner_not_found'});}
 if(req.method==='GET'&&u.pathname==='/api/ledger')return json(res,200,{events:ledger.slice(-25).reverse()});
 if(req.method==='POST'&&u.pathname==='/api/authorize'){const p=await body(req);const w=wallets[p.partnerId];if(!w)return json(res,404,{error:'partner_not_found'});const price=Number(p.price||0.15);const included=w.usedUnits<w.includedUnits;const allowed=included||w.balance>=price;return json(res,allowed?200:402,{authorizationId:`AUTH-${Date.now()}`,partnerId:p.partnerId,product:p.product||'Network API',allowed,charge:included?0:price,balance:w.balance,reason:allowed?null:'INSUFFICIENT_PREPAID_CREDIT'});}
 if(req.method==='POST'&&u.pathname==='/api/settle'){const p=await body(req);const w=wallets[p.partnerId];if(!w)return json(res,404,{error:'partner_not_found'});const charge=Number(p.charge||0);w.usedUnits++;w.balance=Math.max(0,+(w.balance-charge).toFixed(2));const e={id:`LED-${Date.now()}`,ts:new Date().toISOString(),partnerId:p.partnerId,product:p.product||'Network API',outcome:p.outcome||'SUCCESS',charge,balanceAfter:w.balance};ledger.push(e);return json(res,201,e);}
 return false;
}});
