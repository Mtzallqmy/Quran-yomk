const secretPattern = /password|secret|token|authorization|credential|api.?key|signed_?url/i;

export class Logger {
  constructor(private readonly service='radio-engine') {}
  info(event:string,fields:Record<string,unknown>={}):void { this.write('INFO',event,fields); }
  warn(event:string,fields:Record<string,unknown>={}):void { this.write('WARN',event,fields); }
  error(event:string,error:unknown,fields:Record<string,unknown>={}):void {
    this.write('ERROR',event,{...fields,error_type:error instanceof TypeError?'TypeError':'Error'});
  }
  private write(level:string,event:string,fields:Record<string,unknown>):void {
    const clean=JSON.parse(JSON.stringify(fields,(key,value)=>secretPattern.test(key)?'[REDACTED]':value));
    process.stdout.write(`${JSON.stringify({timestamp:new Date().toISOString(),service:this.service,level,event,...clean})}\n`);
  }
}
