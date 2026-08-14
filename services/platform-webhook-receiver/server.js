const http=require('http');
const fs=require('fs');
const path=require('path');
const port=Number(process.env.PORT||18081);
const out=process.env.ALERT_LOG||'/data/alerts.ndjson';
fs.mkdirSync(path.dirname(out),{recursive:true});
http.createServer(async(req,res)=>{
  if(req.method==='GET'&&req.url==='/health'){
    res.writeHead(200,{'content-type':'application/json'});
    return res.end(JSON.stringify({status:'UP',service:'platform-webhook-receiver'}));
  }
  const chunks=[]; for await(const c of req) chunks.push(c);
  const raw=Buffer.concat(chunks).toString(); let body=raw;
  try{body=JSON.parse(raw)}catch{}
  const event={receivedAt:new Date().toISOString(),method:req.method,url:req.url,headers:req.headers,body};
  fs.appendFileSync(out,JSON.stringify(event)+'\n');
  console.log(JSON.stringify({event:'alert_received',url:req.url,body}));
  res.writeHead(200,{'content-type':'application/json'});
  res.end(JSON.stringify({accepted:true}));
}).listen(port,'0.0.0.0',()=>console.log(`Platform application alert receiver listening on ${port}`));
