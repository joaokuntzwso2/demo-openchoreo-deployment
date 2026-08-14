const {start,json}=require('../lib/http');
async function fetchText(url){const r=await fetch(url,{signal:AbortSignal.timeout(5000)});if(!r.ok)throw new Error(`legacy billing HTTP ${r.status}`);return r.text();}
function tag(xml,n){return (xml.match(new RegExp(`<${n}[^>]*>([^<]+)</${n}>`))||[])[1]||'';}
start({name:'telco-bss-facade',routes:async(req,res,u)=>{
 const m=u.pathname.match(/^\/api\/billing\/([^/]+)$/); if(req.method==='GET'&&m){const xml=await fetchText(`${process.env.LEGACY_BILLING_URL}/soap/billing/${m[1]}`);const bal=(xml.match(/<Balance[^>]*>([^<]+)/)||[])[1];return json(res,200,{subscriberId:tag(xml,'SubscriberId'),balance:Number(bal),currency:(xml.match(/currency="([^"]+)/)||[])[1]||'BRL',status:tag(xml,'Status'),source:tag(xml,'LegacySystem'),mediation:'SOAP/XML → REST/JSON'});}
 return false;
}});
