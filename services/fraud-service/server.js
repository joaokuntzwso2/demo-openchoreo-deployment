const {start,json,body,log,sleep,metricLine} = require('../lib/http');
let scored=0, highRisk=0;
const knownDevices=new Set(['device-maria-1','device-daniel-1']);
function score(tx){
  let s=8; const reasons=[];
  if((tx.amount||0)>10000){s+=35;reasons.push('HIGH_AMOUNT');}
  if((tx.amount||0)>50000){s+=25;reasons.push('VERY_HIGH_AMOUNT');}
  if(tx.destinationCountry && !['BR','MX','US','PT','ES'].includes(tx.destinationCountry)){s+=20;reasons.push('UNUSUAL_DESTINATION');}
  if(tx.deviceId && !knownDevices.has(tx.deviceId)){s+=15;reasons.push('NEW_DEVICE');}
  if(tx.channel==='API' && (tx.amount||0)>15000){s+=10;reasons.push('API_HIGH_VALUE');}
  s=Math.min(99,s); return {score:s,decision:s>=70?'BLOCK':s>=45?'CHALLENGE':'ALLOW',reasons};
}
start({name:'fraud-service',metrics:()=>[metricLine('platform_demo_fraud_scores_total',{},scored),metricLine('platform_demo_fraud_high_risk_total',{},highRisk)],routes:async(req,res,u,ctx)=>{
  if(req.method==='POST'&&u.pathname==='/api/fraud/score'){
    const tx=await body(req); scored++;
    if(tx.simulateLatencyMs) await sleep(Math.min(Number(tx.simulateLatencyMs),8000));
    const result=score(tx); if(result.score>=70) highRisk++;
    log('fraud_score',{transactionId:tx.transactionId,customerId:tx.customerId,...result,correlationId:ctx.correlation});
    return json(res,200,{transactionId:tx.transactionId||'T-UNKNOWN',model:'rules-demo-v3',...result});
  }
  if(req.method==='GET'&&u.pathname==='/api/fraud/signals') return json(res,200,{signals:[{type:'NEW_DEVICE',count:12,severity:'MEDIUM'},{type:'HIGH_VALUE_TRANSFER',count:4,severity:'HIGH'},{type:'VELOCITY',count:2,severity:'HIGH'}]});
  return false;
}});
