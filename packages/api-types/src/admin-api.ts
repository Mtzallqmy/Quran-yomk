export type AdminRole='SUPER_ADMIN'|'RADIO_MANAGER'|'CONTENT_EDITOR'|'VIEWER';
export type RadioCommand='PLAY_NOW'|'PLAY_NEXT'|'SKIP'|'STOP_AFTER_CURRENT'|'RESUME_AUTO';
export type ScheduleType='ONE_TIME'|'DAILY'|'WEEKLY';
export type InterruptPolicy='FINISH_CURRENT'|'INTERRUPT'|'PLAY_NEXT';
export type Priority='LOW'|'NORMAL'|'HIGH'|'EMERGENCY'|'LIVE';
export interface AdminSession {user_id:string;email?:string;display_name:string;roles:AdminRole[];permissions:string[]}
export interface RadioCommandResource {id:string;station_id:string;command_type:RadioCommand;status:'PENDING'|'PROCESSING'|'COMPLETED'|'FAILED'|'CANCELLED';created_at:string;executed_at:string|null;error_code:string|null}
export interface UploadIntentResource {intent_id:string;media_id:string;bucket:string;object_key:string;token:string;upload_url:string|null;expires_at:string}
export interface ScheduleInput {station_id:string;name:string;schedule_type:ScheduleType;content_type:'MEDIA'|'PLAYLIST';media_id?:string|null;playlist_id?:string|null;start_date:string;end_date?:string|null;start_time:string;days_of_week?:number[];timezone:string;priority:Priority;interrupt_policy:InterruptPolicy;enabled:boolean}
