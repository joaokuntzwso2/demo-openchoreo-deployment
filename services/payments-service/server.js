const net = require('net');
const {start,json,body,log,sleep,metricLine} = require('../lib/http');
const payments=new Map(); let accepted=0,rejected=0;

function respCommand(parts){return `*${parts.length}\r\n${parts.map(p=>`$${Buffer.byteLength(String(p))}\r\n${p}\r\n`).join('')}`;}
async function cacheProbe(){
  const host=process.env.VALKEY_HOST, port=Number(process.env.VALKEY_PORT||6379), password=process.env.VALKEY_PASSWORD;
  if(!host) return {configured:false,status:'NOT_CONFIGURED'};
  return new Promise(resolve=>{
    const socket=net.createConnection({host,port}); let data=''; let done=false;
    const finish=(status,error)=>{if(done)return;done=true;socket.destroy();resolve({configured:true,host,port,status,error});};
    socket.setTimeout(1200,()=>finish('TIMEOUT'));
    socket.on('error',e=>finish('ERROR',e.message));
    socket.on('data',chunk=>{data+=chunk.toString();if(/\+PONG|\+OK/.test(data)&&(!password||data.includes('+PONG')))finish('UP');});
    socket.on('connect',()=>{socket.write(password?respCommand(['AUTH',password])+respCommand(['PING']):respCommand(['PING']));});
  });
}
async function call(url,path,payload,correlation){const r=await fetch(url+path,{method:'POST',headers:{'content-type':'application/json','x-correlation-id':correlation},body:JSON.stringify(payload),signal:AbortSignal.timeout(8000)});if(!r.ok)throw new Error(`upstream ${path} ${r.status}`);return r.json();}
start({name:'payments-service',metrics:()=>[metricLine('platform_demo_payments_accepted_total',{},accepted),metricLine('platform_demo_payments_rejected_total',{},rejected)],routes:async(req,res,u,ctx)=>{
  if(req.method==='POST'&&u.pathname==='/api/payments'){
    const p=await body(req); const id=p.transactionId||`TX-${Date.now()}`;
    if(p.simulate==='error'){log('PAYMENT_UPSTREAM_FAILURE',{transactionId:id,reason:'demo injected failure',correlationId:ctx.correlation}); rejected++; return json(res,503,{transactionId:id,status:'FAILED',error:'PAYMENT_UPSTREAM_FAILURE'});}
    if(p.simulate==='latency') await sleep(3500);
    const cache=await cacheProbe();
    const fraud=await call(process.env.FRAUD_API_URL,'/api/fraud/score',{...p,transactionId:id},ctx.correlation);
    const compliance=await call(process.env.COMPLIANCE_API_URL,'/api/compliance/check',p,ctx.correlation);
    const status=fraud.decision==='BLOCK'||compliance.decision==='HOLD'?'REJECTED':fraud.decision==='CHALLENGE'?'PENDING_CHALLENGE':'ACCEPTED';
    status==='ACCEPTED'?accepted++:rejected++;
    const rec={transactionId:id,status,amount:p.amount,currency:p.currency||'BRL',customerId:p.customerId,beneficiaryName:p.beneficiaryName,fraud,compliance,cache,createdAt:new Date().toISOString()}; payments.set(id,rec);
    log('payment_decision',{transactionId:id,status,fraudScore:fraud.score,complianceDecision:compliance.decision,correlationId:ctx.correlation}); return json(res,status==='REJECTED'?422:201,rec);
  }
  if(req.method==='GET'&&u.pathname==='/api/cache-status') return json(res,200,await cacheProbe());
  if(req.method==='GET'&&u.pathname==='/api/payments') return json(res,200,{payments:[...payments.values()].slice(-20).reverse()});
  const m=u.pathname.match(/^\/api\/payments\/([^/]+)$/); if(req.method==='GET'&&m) return payments.has(m[1])?json(res,200,payments.get(m[1])):json(res,404,{error:'payment_not_found'});
  return false;
}});
