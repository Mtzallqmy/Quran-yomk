import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const source=readFileSync('docs/legal/documents.json','utf8');
assert.equal(readFileSync('apps/mobile/assets/legal/documents.json','utf8'),source,'Bundled legal text must match reviewed source');
const documents=JSON.parse(source);
assert.deepEqual(documents.map(d=>d.id),['privacy','terms']);
for(const d of documents){
 assert.match(d.updated,/^\d{4}-\d{2}-\d{2}$/);
 assert.ok(d.sections.length>=5);
 const markdown='# '+d.title+'\n\nآخر تحديث: '+d.updated+'\n\n'+d.sections.map(s=>'## '+s.title+'\n\n'+s.body).join('\n\n')+'\n';
 assert.equal(readFileSync(`docs/legal/${d.id}.ar.md`,'utf8'),markdown);
}
console.log('Legal source, Markdown and offline assets are consistent.');
