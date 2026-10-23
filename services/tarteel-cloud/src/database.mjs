import pg from 'pg';
import { ApiError } from './handler.mjs';

export class Database {
  constructor(pool) { this.pool=pool; }
  async budget(principal,limit) {
    const {rows}=await this.pool.query(`INSERT INTO tarteel_cloud.request_budgets AS budget
      (principal,window_start,request_count) VALUES($1,date_trunc('minute',now()),1)
      ON CONFLICT(principal) DO UPDATE SET
      window_start=date_trunc('minute',now()),request_count=CASE
        WHEN budget.window_start=date_trunc('minute',now()) THEN budget.request_count+1 ELSE 1 END
      RETURNING request_count`,[principal]);
    if(rows[0].request_count>limit) throw new ApiError(429,'RATE_LIMITED');
  }
  async register(id,hash) { await this.pool.query('INSERT INTO tarteel_cloud.devices(id,token_hash) VALUES($1,$2)',[id,hash]); }
  async authenticate(hash) {
    const {rows}=await this.pool.query('SELECT id FROM tarteel_cloud.devices WHERE token_hash=$1 AND revoked_at IS NULL',[hash]);
    return rows[0]?.id;
  }
  async scoped(id,operation) {
    const client=await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('SET LOCAL ROLE tarteel_cloud_client');
      await client.query("SELECT set_config('tarteel.device_id',$1,true)",[id]);
      const result=await operation(client);
      await client.query('COMMIT'); return result;
    } catch(error) { await client.query('ROLLBACK'); throw error; }
    finally { client.release(); }
  }
  get(id) { return this.scoped(id,async c=>(await c.query('SELECT revision,payload,updated_at FROM tarteel_cloud.library_backups WHERE device_id=$1',[id])).rows[0] ?? null); }
  put(id,revision,payload) {
    return this.scoped(id,async c=> {
      const result=revision===0
        ? await c.query(`INSERT INTO tarteel_cloud.library_backups(device_id,revision,payload)
          VALUES($1,1,$2::jsonb) ON CONFLICT(device_id) DO NOTHING
          RETURNING revision,payload,updated_at`,[id,JSON.stringify(payload)])
        : await c.query(`UPDATE tarteel_cloud.library_backups SET revision=revision+1,payload=$3::jsonb,updated_at=now()
          WHERE device_id=$1 AND revision=$2::bigint RETURNING revision,payload,updated_at`,[id,revision,JSON.stringify(payload)]);
      return result.rows[0] ?? null;
    });
  }
  async revoke(id) {
    await this.scoped(id,c=>c.query('DELETE FROM tarteel_cloud.library_backups WHERE device_id=$1',[id]));
    await this.pool.query('UPDATE tarteel_cloud.devices SET revoked_at=now() WHERE id=$1',[id]);
  }
}
export function createDatabase(url) {
  if(!url) throw new Error('DATABASE_URL_REQUIRED');
  const pool=new pg.Pool({connectionString:url,max:5,idleTimeoutMillis:20000,connectionTimeoutMillis:10000,statement_timeout:10000});
  pool.on('error',()=>console.error('TARTEEL_CLOUD_POOL_DISCONNECTED'));
  return new Database(pool);
}
