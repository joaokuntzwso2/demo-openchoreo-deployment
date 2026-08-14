const {start}=require('../lib/http');
const {createMcpRoutes}=require('../lib/mcp-server');

async function j(url,opts={}){
  const r=await fetch(url,{...opts,signal:AbortSignal.timeout(7000)});
  const raw=await r.text(); let d; try{d=raw?JSON.parse(raw):{}}catch{d={raw}};
  if(!r.ok) throw new Error(`${url} -> HTTP ${r.status}: ${raw.slice(0,180)}`);
  return d;
}
function context(req){
  const partnerId=req.headers['x-partner-id'];
  const correlationId=req.headers['x-correlation-id'];
  if(!partnerId) throw new Error('X-Partner-Id header is required');
  if(!correlationId) throw new Error('X-Correlation-ID header is required');
  return {partnerId:String(partnerId),correlationId:String(correlationId)};
}
const hdr=c=>({'content-type':'application/json','x-partner-id':c.partnerId,'x-correlation-id':c.correlationId});

const tools={
 retrieveSubscriberServiceStatus:{
   name:'retrieveSubscriberServiceStatus',description:'Retrieve a subscriber service status and access network using governed partner context.',
   inputSchema:{type:'object',properties:{subscriberId:{type:'string'}},required:['subscriberId'],additionalProperties:false},
   handler:({subscriberId},req)=>{const c=context(req);return j(`${process.env.SUBSCRIBER_URL}/api/subscribers/${subscriberId}/status`,{headers:hdr(c)}).then(result=>({...result,partnerId:c.partnerId,correlationId:c.correlationId}))}
 },
 inspectNetworkOutage:{
   name:'inspectNetworkOutage',description:'Inspect current network outages, optionally by region.',
   inputSchema:{type:'object',properties:{region:{type:'string'}},additionalProperties:false},
   handler:({region},req)=>{const c=context(req);return j(`${process.env.NETWORK_URL}/api/outages${region?`?region=${encodeURIComponent(region)}`:''}`,{headers:hdr(c)}).then(result=>({...result,partnerId:c.partnerId,correlationId:c.correlationId}))}
 },
 requestQualityOnDemand:{
   name:'requestQualityOnDemand',description:'Authorize, govern, create and commercially settle a Quality on Demand session.',
   inputSchema:{type:'object',properties:{subscriberId:{type:'string'},profile:{type:'string'},durationSeconds:{type:'number'},country:{type:'string'},dataResidency:{type:'string'}},required:['subscriberId'],additionalProperties:false},
   handler:async(a,req)=>{
     const c=context(req); const country=a.country||'BR';
     const authorization=await j(`${process.env.COMMERCIAL_URL}/api/authorize`,{method:'POST',headers:hdr(c),body:JSON.stringify({partnerId:c.partnerId,product:'5G Quality on Demand',price:0.25})});
     if(!authorization.allowed) return {status:'DENIED',stage:'commercial-authorization',partnerId:c.partnerId,correlationId:c.correlationId,authorization};
     const policy=await j(`${process.env.POLICY_URL}/api/policy/evaluate`,{method:'POST',headers:hdr(c),body:JSON.stringify({partnerId:c.partnerId,country,dataResidency:a.dataResidency||country,consent:'ACTIVE',action:'QOD'})});
     if(policy.decision!=='ALLOW') return {status:'DENIED',stage:'policy',partnerId:c.partnerId,correlationId:c.correlationId,authorization,policy};
     const network=await j(`${process.env.NETWORK_URL}/api/qod/sessions`,{method:'POST',headers:hdr(c),body:JSON.stringify({...a,country})});
     const settlement=await j(`${process.env.COMMERCIAL_URL}/api/settle`,{method:'POST',headers:hdr(c),body:JSON.stringify({partnerId:c.partnerId,product:'5G Quality on Demand',outcome:network.status,charge:authorization.charge||0})});
     return {...network,partnerId:c.partnerId,correlationId:c.correlationId,authorization,policy,settlement};
   }
 },
 checkPartnerWallet:{
   name:'checkPartnerWallet',description:'Check the authenticated partner prepaid wallet and included usage.',
   inputSchema:{type:'object',properties:{},additionalProperties:false},
   handler:(_,req)=>{const c=context(req);return j(`${process.env.COMMERCIAL_URL}/api/wallets/${c.partnerId}`,{headers:hdr(c)}).then(result=>({...result,correlationId:c.correlationId}))}
 },
 evaluateTelcoPolicy:{
   name:'evaluateTelcoPolicy',description:'Evaluate central partner, consent, purpose and residency policy using the authenticated partner context.',
   inputSchema:{type:'object',properties:{country:{type:'string'},consent:{type:'string'},dataResidency:{type:'string'},action:{type:'string'},simSwapAgeHours:{type:'number'}},additionalProperties:false},
   handler:(a,req)=>{const c=context(req);return j(`${process.env.POLICY_URL}/api/policy/evaluate`,{method:'POST',headers:hdr(c),body:JSON.stringify({...a,partnerId:c.partnerId})}).then(result=>({...result,partnerId:c.partnerId,correlationId:c.correlationId}))}
 }
};
start({name:'telco-mcp',routes:createMcpRoutes({name:'platform-telco-mcp',tools})});
