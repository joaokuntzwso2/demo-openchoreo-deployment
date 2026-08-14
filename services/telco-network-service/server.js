const {start,json,body,metricLine,sleep}=require('../lib/http');
let qod=0; const outages=[
 {id:'OUT-SP-5G-01',region:'SP',country:'BR',technology:'5G',severity:'MAJOR',status:'INVESTIGATING',affectedSubscribers:18342,startedAt:'2026-08-14T11:45:00Z'},
 {id:'OUT-CDMX-IP-02',region:'CDMX',country:'MX',technology:'IP',severity:'MINOR',status:'MONITORING',affectedSubscribers:812,startedAt:'2026-08-14T12:20:00Z'}
];
start({name:'telco-network-service',metrics:()=>[metricLine('platform_telco_qod_requests_total',{},qod)],routes:async(req,res,u)=>{
 if(req.method==='GET'&&u.pathname==='/api/outages'){const region=u.searchParams.get('region');return json(res,200,{outages:region?outages.filter(x=>x.region===region):outages});}
 if(req.method==='GET'&&u.pathname==='/api/network/summary')return json(res,200,{availability:'99.982%',activeOutages:outages.length,regions:['BR-SP','BR-RJ','MX-CDMX'],qodSessions:qod});
 if(req.method==='POST'&&u.pathname==='/api/qod/sessions'){qod++;const p=await body(req);if(p.simulate==='latency')await sleep(1200);const allowed=Number(p.durationSeconds||900)<=3600;return json(res,allowed?201:422,{sessionId:`QOD-${Date.now()}`,subscriberId:p.subscriberId,profile:p.profile||'QOS_E',durationSeconds:Number(p.durationSeconds||900),status:allowed?'ACTIVE':'REJECTED',edgeRegion:p.country==='MX'?'mx-central':'br-southeast',reason:allowed?null:'DURATION_EXCEEDS_POLICY'});}
 return false;
}});
