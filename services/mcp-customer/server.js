const {start}=require('../lib/http'); const {createMcpRoutes}=require('../lib/mcp-server');
async function get(path){const r=await fetch(process.env.ACCOUNTS_API_URL+path);if(!r.ok)throw new Error(`accounts ${r.status}`);return r.json();}
const tools={
 get_customer_profile:{name:'get_customer_profile',description:'Get financial customer profile, KYC status, segment and risk tier.',inputSchema:{type:'object',properties:{customerId:{type:'string'}},required:['customerId'],additionalProperties:false},handler:({customerId})=>get(`/api/customers/${customerId}`)},
 list_customer_accounts:{name:'list_customer_accounts',description:'List a customer financial accounts and balances.',inputSchema:{type:'object',properties:{customerId:{type:'string'}},required:['customerId'],additionalProperties:false},handler:({customerId})=>get(`/api/customers/${customerId}/accounts`)},
 get_account:{name:'get_account',description:'Get one account by account id.',inputSchema:{type:'object',properties:{accountId:{type:'string'}},required:['accountId'],additionalProperties:false},handler:({accountId})=>get(`/api/accounts/${accountId}`)}
};
start({name:'mcp-customer',routes:createMcpRoutes({name:'financial-customer-mcp',tools})});
