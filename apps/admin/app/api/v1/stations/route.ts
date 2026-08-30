import { fail, json, requestId } from '@/lib/http';
import { listPublicStations } from '@/lib/public-catalog';
export const runtime='nodejs';
export async function GET(request:Request){const id=requestId(request);try{return json(await listPublicStations(request),200,{'x-request-id':id,'cache-control':'public, max-age=30, s-maxage=300, stale-while-revalidate=900'});}catch(error){return fail(error,id);}}
