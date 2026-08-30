#!/usr/bin/env python3
import json
from pathlib import Path
import external_radio_audit

error=None
try:
    external_radio_audit.main()
except BaseException as exc:  # Preserve release-gate failure after emitting evidence.
    error=exc
finally:
    evidence=Path(__file__).resolve().parents[1]/'release/external-radio/audit.json'
    if evidence.exists():
        for row in json.loads(evidence.read_text(encoding='utf-8')):
            fields={key:row.get(key) for key in ('provider','category','slug','external_key','url','seeded','health_status','http_status','final_url','redirect_count','redirect_chain','content_type','http_ttfb_ms','detected_stream_type','codec','format','first_audio_ms','checked_at','aliases')}
            print('TARTEEL_AUDIT_RESULT '+json.dumps(fields,ensure_ascii=False,separators=(',',':')),flush=True)
if error is not None:
    raise error
