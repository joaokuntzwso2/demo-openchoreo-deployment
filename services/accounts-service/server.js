const {start,json} = require('../lib/http');
const customers={
  'C001':{id:'C001',name:'Maria Silva',segment:'Private Banking',riskTier:'LOW',kyc:'VERIFIED',country:'BR'},
  'C002':{id:'C002',name:'Daniel Ortiz',segment:'Retail',riskTier:'MEDIUM',kyc:'VERIFIED',country:'MX'},
  'C003':{id:'C003',name:'Ana Costa',segment:'SME',riskTier:'LOW',kyc:'REVIEW',country:'BR'}
};
const accounts={
  'C001':[{id:'CHK-001',type:'CHECKING',currency:'BRL',balance:128450.22,available:126000.22},{id:'INV-001',type:'INVESTMENT',currency:'BRL',balance:840500.10,available:840500.10}],
  'C002':[{id:'CHK-002',type:'CHECKING',currency:'MXN',balance:87540.00,available:84440.00}],
  'C003':[{id:'BUS-003',type:'BUSINESS',currency:'BRL',balance:349810.77,available:320100.50}]
};
start({name:'accounts-service',routes:async(req,res,u)=>{
  if(req.method==='GET'&&u.pathname==='/api/customers') return json(res,200,Object.values(customers));
  let m=u.pathname.match(/^\/api\/customers\/([^/]+)$/); if(req.method==='GET'&&m) return customers[m[1]]?json(res,200,customers[m[1]]):json(res,404,{error:'customer_not_found'});
  m=u.pathname.match(/^\/api\/customers\/([^/]+)\/accounts$/); if(req.method==='GET'&&m) return json(res,200,{customerId:m[1],accounts:accounts[m[1]]||[]});
  m=u.pathname.match(/^\/api\/accounts\/([^/]+)$/); if(req.method==='GET'&&m){const a=Object.values(accounts).flat().find(x=>x.id===m[1]); return a?json(res,200,a):json(res,404,{error:'account_not_found'});}
  return false;
}});
