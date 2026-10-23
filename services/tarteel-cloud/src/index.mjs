import {createDatabase} from './database.mjs';
import {createHandler} from './handler.mjs';
// TARTEEL_DATABASE_URL is a server-only override for runtimes whose automatically
// injected URL omits role credentials. It is never a Flutter build variable.
const handler=createHandler(createDatabase(process.env.TARTEEL_DATABASE_URL ?? process.env.DATABASE_URL));
export default {fetch:handler};
