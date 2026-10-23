import { createHash, randomBytes, randomUUID } from 'node:crypto';

export class ApiError extends Error {
  constructor(status, code) { super(code); this.status = status; this.code = code; }
}
export function validatePayload(value) {
  if (!value || Array.isArray(value) || typeof value !== 'object' ||
      Object.keys(value).sort().join(',') !== 'reciters,stations,tracks') {
    throw new ApiError(422, 'INVALID_BACKUP');
  }
  for (const key of ['stations', 'reciters', 'tracks']) {
    const rows = value[key];
    if (!Array.isArray(rows) || rows.length > 500 || rows.some(id =>
      typeof id !== 'string' || id.length < 1 || id.length > 200 || /[\x00-\x1f]/.test(id))) {
      throw new ApiError(422, 'INVALID_BACKUP');
    }
  }
  if (Buffer.byteLength(JSON.stringify(value)) > 60000) throw new ApiError(413, 'BACKUP_TOO_LARGE');
  return Object.fromEntries(['stations','reciters','tracks'].map(key => [key, [...new Set(value[key])]]));
}
export async function readJson(request) {
  if (request.headers.get('content-type')?.split(';')[0] !== 'application/json') throw new ApiError(415, 'JSON_REQUIRED');
  const reader = request.body?.getReader();
  if (!reader) throw new ApiError(422, 'INVALID_JSON');
  let size=0; const chunks=[];
  try {
    while (true) {
      const {done,value}=await reader.read(); if (done) break;
      size+=value.byteLength;
      if (size>65536) { await reader.cancel(); throw new ApiError(413,'BODY_TOO_LARGE'); }
      chunks.push(value);
    }
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch(error) { if(error instanceof ApiError) throw error; throw new ApiError(422,'INVALID_JSON'); }
  finally { reader.releaseLock(); }
}
export function bearer(request) {
  const match=/^Bearer ([A-Za-z0-9_-]{43})$/.exec(request.headers.get('authorization') ?? '');
  if (!match) throw new ApiError(401,'AUTH_REQUIRED');
  return createHash('sha256').update(match[1]).digest('hex');
}
const response=(data,status=200)=>Response.json(data,{status,headers:{'cache-control':'no-store','x-content-type-options':'nosniff'}});

// db owns parameterized queries, persistent quotas and authorization scope.
export function createHandler(db) {
  let radioCache;
  let radioLoading;
  const catalog=async()=>{
    if(radioCache && radioCache.expires>Date.now()) return radioCache.data;
    radioLoading ??= db.radioCatalog().then(data=>{
      radioCache={data,expires:Date.now()+60000};return data;
    }).finally(()=>{radioLoading=undefined;});
    return radioLoading;
  };
  return async request => {
    try {
      const path=new URL(request.url).pathname.replace(/\/$/,'');
      if (path==='/health' && request.method==='GET') return response({service:'tarteel-optional-cloud',ok:true});
      // Deliberately public GET metadata. No anonymous mutation or stream proxy.
      if (path==='/v1/radio/stations') {
        if(request.method!=='GET') throw new ApiError(405,'METHOD_NOT_ALLOWED');
        return Response.json({data:await catalog()},{headers:{
          'cache-control':'public, max-age=60, stale-if-error=86400',
          'x-content-type-options':'nosniff'}});
      }
      if (path==='/v1/devices' && request.method==='POST') {
        await db.budget('registration',20);
        const body=await readJson(request);
        if (body.consent !== 'favorites-backup-v1') throw new ApiError(422,'CONSENT_REQUIRED');
        const token=randomBytes(32).toString('base64url');
        const id=randomUUID();
        await db.register(id,createHash('sha256').update(token).digest('hex'));
        return response({device_id:id,token},201);
      }
      if (path!=='/v1/library-backup' && path!=='/v1/device') throw new ApiError(404,'NOT_FOUND');
      const id=await db.authenticate(bearer(request));
      if (!id) throw new ApiError(401,'INVALID_CREDENTIAL');
      await db.budget(id,60);
      if(path==='/v1/device' && request.method==='DELETE') { await db.revoke(id); return response({revoked:true}); }
      if (path==='/v1/library-backup' && request.method==='GET') return response({data:await db.get(id)});
      if (path==='/v1/library-backup' && request.method==='PUT') {
        const body=await readJson(request);
        if (!Number.isSafeInteger(body.revision) || body.revision<0) throw new ApiError(422,'INVALID_REVISION');
        const payload=validatePayload(body.payload);
        const data=await db.put(id,body.revision,payload);
        if(!data) throw new ApiError(409,'REVISION_CONFLICT');
        return response({data});
      }
      throw new ApiError(405,'METHOD_NOT_ALLOWED');
    } catch(error) {
      if (error instanceof ApiError) {
        const result=response({error:error.code},error.status);
        if(error.status===429) result.headers.set('retry-after','60');
        return result;
      }
      // Never log query parameters, bearer credentials, payloads or DB URLs.
      const code=typeof error?.code==='string' && /^[A-Z0-9_]{1,30}$/.test(error.code) ? error.code : 'UNKNOWN';
      const type=error instanceof Error ? error.name : 'Unknown';
      const message=String(error?.message??'');
      const classification=[['password must be a string','INVALID_PASSWORD_TYPE'],['Connection terminated due to connection timeout','CONNECTION_TIMEOUT'],['Dynamic require of','BUNDLE_REQUIRE'],['Cannot find module','MODULE_MISSING'],['SASL','SASL'],['SSL','TLS'],['timeout','TIMEOUT'],['not defined','UNDEFINED']].find(([text])=>message.includes(text))?.[1]??'UNCLASSIFIED';
      console.error(`TARTEEL_CLOUD_REQUEST_FAILED:${type}:${code}:${classification}`);
      return response({error:'CLOUD_UNAVAILABLE'},503);
    }
  };
}
