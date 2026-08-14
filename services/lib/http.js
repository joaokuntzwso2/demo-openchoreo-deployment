const http = require('http');
const { randomUUID } = require('crypto');

function json(res, status, payload, headers = {}) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, { 'content-type': 'application/json', 'cache-control': 'no-store', ...headers });
  res.end(body);
}
function text(res, status, payload, type='text/plain; charset=utf-8') {
  res.writeHead(status, { 'content-type': type, 'cache-control': 'no-store' });
  res.end(payload);
}
async function body(req) {
  const chunks=[]; for await (const c of req) chunks.push(c);
  if (!chunks.length) return {};
  const raw=Buffer.concat(chunks).toString('utf8');
  try { return JSON.parse(raw); } catch { return { raw }; }
}
function log(event, data={}) {
  console.log(JSON.stringify({ ts:new Date().toISOString(), event, ...data }));
}
function sleep(ms){ return new Promise(r=>setTimeout(r,ms)); }
function metricLine(name, labels, value) {
  const labelText = Object.entries(labels||{}).map(([k,v])=>`${k}="${String(v).replaceAll('"','\\"')}"`).join(',');
  return `${name}${labelText?`{${labelText}}`:''} ${value}`;
}
function start({name, port=8080, routes, metrics}) {
  port=Number(process.env.PORT||port);
  let requests=0, errors=0;
  const server=http.createServer(async (req,res)=>{
    const started=Date.now(); const correlation=req.headers['x-correlation-id'] || randomUUID();
    res.setHeader('x-correlation-id', correlation);
    requests++;
    try {
      const u=new URL(req.url, `http://${req.headers.host||'localhost'}`);
      if(u.pathname==='/health' || u.pathname==='/ready') return json(res,200,{status:'UP',service:name,ts:new Date().toISOString()});
      if(u.pathname==='/metrics') {
        const extra=metrics?metrics():[];
        return text(res,200,[metricLine('platform_demo_http_requests_total',{service:name},requests),metricLine('platform_demo_http_errors_total',{service:name},errors),...extra].join('\n')+'\n','text/plain; version=0.0.4');
      }
      const handled=await routes(req,res,u,{correlation});
      if(handled===false) json(res,404,{error:'not_found',service:name,path:u.pathname,correlationId:correlation});
    } catch(err) {
      errors++; log('unhandled_error',{service:name,error:err.message,stack:err.stack,correlationId:correlation});
      if(!res.headersSent) json(res,500,{error:'internal_error',message:err.message,correlationId:correlation}); else res.end();
    } finally {
      log('request_complete',{service:name,method:req.method,path:req.url,status:res.statusCode,durationMs:Date.now()-started,correlationId:correlation});
    }
  });
  server.listen(port,'0.0.0.0',()=>log('service_started',{service:name,port}));
  return server;
}
module.exports={json,text,body,log,sleep,start,metricLine};
