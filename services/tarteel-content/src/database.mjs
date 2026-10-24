import pg from 'pg';
export function database(url){const u=new URL(url);u.searchParams.delete('sslmode');u.searchParams.delete('channel_binding');return new pg.Pool({connectionString:u.toString(),ssl:{rejectUnauthorized:true},max:3,connectionTimeoutMillis:10000,query_timeout:12000});}
