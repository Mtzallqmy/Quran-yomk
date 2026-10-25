import {database} from './database.mjs';
import {handler} from './handler.mjs';
import {admin} from './admin.mjs';
const pool=database(process.env.TARTEEL_DATABASE_URL??process.env.DATABASE_URL);
const read=handler(pool),write=admin(pool,process.env.SYNC_TOKEN);
export default {fetch:request=>new URL(request.url).pathname.startsWith('/admin/')?write(request):read(request)};
