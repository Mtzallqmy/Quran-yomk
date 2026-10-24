'use client';

export class ClientApiError extends Error {
  constructor(public status:number, public code:string, message:string, public requestId?:string){super(message);}
}

export async function clientApi<T=any>(path:string, init:RequestInit={}):Promise<T>{
  const headers=new Headers(init.headers);
  if(init.body && !(init.body instanceof FormData) && !headers.has('content-type')) headers.set('content-type','application/json');
  const response=await fetch(path,{...init,headers,credentials:'include',cache:'no-store'});
  const payload=await response.json().catch(()=>({}));
  if(!response.ok){
    const error=payload?.error??{};
    throw new ClientApiError(response.status,error.code??'HTTP_ERROR',error.message??`HTTP ${response.status}`,error.request_id??response.headers.get('x-request-id')??undefined);
  }
  return payload as T;
}

export function idempotencyKey(prefix:string){return `${prefix}:${crypto.randomUUID()}`;}
