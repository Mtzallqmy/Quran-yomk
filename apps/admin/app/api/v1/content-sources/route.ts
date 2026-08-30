import { fail, json, requestId } from '@/lib/http';
import { publicContentSources } from '@/lib/public-catalog';
export const runtime='nodejs';
export async function GET(request:Request){const id=requestId(request);try{return json(await publicContentSources(),200,{'x-request-id':id,'cache-control':'public, max-age=300, s-maxage=3600'});}catch(error){return fail(error,id);}}
