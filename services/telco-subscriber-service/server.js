const {start,json,body,metricLine}=require('../lib/http');
const subscribers={
 '5511999999999':{subscriberId:'5511999999999',name:'Ana Costa',country:'BR',segment:'PREMIUM',serviceStatus:'ACTIVE',accessNetwork:'5G',voice:'AVAILABLE',data:'AVAILABLE',roaming:'DISABLED',plan:'Platinum 5G',simSwapAgeHours:240,consent:'ACTIVE'},
 '525511223344':{subscriberId:'525511223344',name:'Carlos Mendoza',country:'MX',segment:'BUSINESS',serviceStatus:'ACTIVE',accessNetwork:'5G',voice:'AVAILABLE',data:'DEGRADED',roaming:'ENABLED',plan:'Enterprise Max',simSwapAgeHours:8,consent:'ACTIVE'},
 '5511888877777':{subscriberId:'5511888877777',name:'Luisa Prado',country:'BR',segment:'STANDARD',serviceStatus:'SUSPENDED',accessNetwork:'4G',voice:'BARRED',data:'BARRED',roaming:'DISABLED',plan:'Essencial',simSwapAgeHours:720,consent:'EXPIRED'}
};
let lookups=0;
start({name:'telco-subscriber-service',metrics:()=>[metricLine('platform_telco_subscriber_lookups_total',{},lookups)],routes:async(req,res,u)=>{
 if(req.method==='GET'&&u.pathname==='/api/subscribers') return json(res,200,{subscribers:Object.values(subscribers)});
 let m=u.pathname.match(/^\/api\/subscribers\/([^/]+)\/status$/); if(req.method==='GET'&&m){lookups++;const s=subscribers[m[1]];return s?json(res,200,s):json(res,404,{error:'subscriber_not_found'});}
 m=u.pathname.match(/^\/api\/subscribers\/([^/]+)\/sim-swap$/); if(req.method==='GET'&&m){const s=subscribers[m[1]];return s?json(res,200,{subscriberId:s.subscriberId,simSwapAgeHours:s.simSwapAgeHours,risk:s.simSwapAgeHours<24?'HIGH':s.simSwapAgeHours<72?'MEDIUM':'LOW'}):json(res,404,{error:'subscriber_not_found'});}
 if(req.method==='POST'&&u.pathname==='/api/subscribers/consent/check'){const p=await body(req);const s=subscribers[p.subscriberId];return json(res,s?200:404,s?{subscriberId:s.subscriberId,purpose:p.purpose||'SERVICE_ASSURANCE',consent:s.consent,allowed:s.consent==='ACTIVE'}:{error:'subscriber_not_found'});}
 return false;
}});
