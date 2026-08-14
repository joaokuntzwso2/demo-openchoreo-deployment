const {body,json,log}=require('./http'); const {randomUUID}=require('crypto');
function createMcpRoutes({name,tools}){const session=randomUUID();return async(req,res,u)=>{
  if(u.pathname!='/mcp')return false;
  if(req.method==='GET'){res.writeHead(405,{'allow':'POST'});res.end();return true;}
  if(req.method!=='POST')return false;
  const m=await body(req); if(!m.id && m.method==='notifications/initialized'){res.writeHead(202);res.end();return true;}
  const reply=(result)=>json(res,200,{jsonrpc:'2.0',id:m.id,result},{'mcp-session-id':session});
  if(m.method==='initialize')return reply({protocolVersion:'2025-06-18',capabilities:{tools:{listChanged:false}},serverInfo:{name,version:'1.0.0'}});
  if(m.method==='ping')return reply({});
  if(m.method==='tools/list')return reply({tools:Object.values(tools).map(t=>({name:t.name,description:t.description,inputSchema:t.inputSchema}))});
  if(m.method==='tools/call'){
    const t=tools[m.params?.name]; if(!t)return json(res,200,{jsonrpc:'2.0',id:m.id,error:{code:-32601,message:`Unknown tool ${m.params?.name}`}});
    try{const value=await t.handler(m.params?.arguments||{},req);log('mcp_tool_call',{server:name,tool:t.name});return reply({content:[{type:'text',text:JSON.stringify(value,null,2)}],structuredContent:value});}
    catch(e){return reply({isError:true,content:[{type:'text',text:e.message}]});}
  }
  return json(res,200,{jsonrpc:'2.0',id:m.id,error:{code:-32601,message:`Unknown method ${m.method}`}});
};}
module.exports={createMcpRoutes};
