const {start,text,json}=require('../lib/http');
start({name:'telco-legacy-billing',routes:async(req,res,u)=>{
 const m=u.pathname.match(/^\/soap\/billing\/([^/]+)$/); if(req.method==='GET'&&m){const id=m[1];return text(res,200,`<?xml version="1.0"?><BillingAccount><SubscriberId>${id}</SubscriberId><Balance currency="BRL">142.35</Balance><Status>CURRENT</Status><LegacySystem>BSS-SOAP-02</LegacySystem></BillingAccount>`,'application/xml');}
 if(req.method==='GET'&&u.pathname==='/api/legacy/status')return json(res,200,{status:'UP',protocol:'SOAP/XML',system:'BSS-SOAP-02'});
 return false;
}});
