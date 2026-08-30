import { fail, json, requestId } from '@/lib/http';
import { getPublicStation } from '@/lib/public-catalog';
export const runtime='nodejs';
export async function GET(request:Request,context:{params:Promise<{slug:string}>}){const id=requestId(request);try{const {slug}=await context.params;return json(await getPublicStation(slug),200,{'x-request-id':id,'cache-control':'public, max-age=30, s-maxage=300, stale-while-revalidate=900'});}catch(error){return fail(error,id);}}
