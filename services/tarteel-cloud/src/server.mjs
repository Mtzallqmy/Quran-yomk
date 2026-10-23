import { createServer } from 'node:http';
import app from './index.mjs';
createServer(async (incoming,outgoing)=>{
  try {
    const request=new Request(`http://localhost${incoming.url}`,{
      method:incoming.method,headers:incoming.headers,
      ...(!['GET','HEAD'].includes(incoming.method)?{body:incoming,duplex:'half'}:{}),
    });
    const result=await app.fetch(request);
    outgoing.writeHead(result.status,Object.fromEntries(result.headers));
    outgoing.end(Buffer.from(await result.arrayBuffer()));
  } catch {outgoing.writeHead(500);outgoing.end('Request failed');}
}).listen(Number(process.env.PORT??3000),'127.0.0.1');
