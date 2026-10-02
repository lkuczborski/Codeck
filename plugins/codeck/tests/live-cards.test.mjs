import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {MCPClient} from '../scripts/mcp-client.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
test('live card runs through the shared runtime with default and fence settings, without the Codeck app',async t=>{
 const directory=await mkdtemp(path.join(tmpdir(),'codeck-runs-'));
 t.after(()=>rm(directory,{recursive:true,force:true}));
 const fake=path.join(directory,'codex');
 const log=path.join(directory,'requests.jsonl');
 await writeFile(fake,`#!/usr/bin/env node
const readline=require('node:readline');const fs=require('node:fs');
const send=x=>process.stdout.write(JSON.stringify(x)+'\\n');
process.stderr.write(JSON.stringify({protocolDiagnostic:'must not render'})+'\\n');
readline.createInterface({input:process.stdin}).on('line',line=>{
 const x=JSON.parse(line);fs.appendFileSync(${JSON.stringify(log)},line+'\\n');
 if(x.method==='initialize')send({id:x.id,result:{}});
 if(x.method==='thread/start')send({id:x.id,result:{thread:{id:'thread'}}});
 if(x.method==='turn/start'){
  send({id:x.id,result:{turn:{id:'turn'}}});
  send({method:'item/agentMessage/delta',params:{threadId:'thread',turnId:'turn',delta:'Card result'}});
  setTimeout(()=>send({method:'turn/completed',params:{threadId:'thread',turn:{id:'turn',status:'completed'}}}),100);
 }
});`,{mode:0o755});
 const client=new MCPClient(process.env.CODECK_MCP_EXECUTABLE||path.join(root,'.build/debug/codeck-mcp'),{cwd:directory,env:{CODECK_MCP_ALLOWED_ROOTS:directory,CODECK_CODEX_EXECUTABLE:fake}});
 t.after(()=>client.close());await client.initialize();
 const tool=(name,args)=>client.request('tools/call',{name,arguments:args});
 const markdown='# Live\n\n```codex id=default\nSay hello.\n```\n\n```codex id=override model=gpt-6-astra reasoning=ultra\nSay goodbye.\n```';
 const state=(await tool('open_workspace',{markdown})).structuredContent;
 for(const block_id of ['default','override']){
  const begun=await tool('begin_codex_run',{workspace_id:state.id,revision:state.revision,slide_index:0,block_id});
  assert.notEqual(begun.isError,true);
  let results;
  for(let attempt=0;attempt<50;attempt++){
   results=await tool('poll_codex_runs',{workspace_id:state.id});
   if(results.structuredContent.runs.find(run=>run.blockID===block_id)?.status==='completed')break;
   await new Promise(resolve=>setTimeout(resolve,100));
  }
  const run=results.structuredContent.runs.find(run=>run.blockID===block_id);
  assert.equal(run.status,'completed');assert.equal(run.output,'Card result');
  assert.match(results._meta.preview.slides[0].html,/Card result/);
 }
 const requests=(await readFile(log,'utf8')).trim().split('\n').map(JSON.parse);
 const turns=requests.filter(x=>x.method==='turn/start').map(x=>x.params);
 assert.equal(turns[0].model,'gpt-6.1-sol');assert.equal(turns[0].effort,'low');
 assert.equal(turns[1].model,'gpt-6-astra');assert.equal(turns[1].effort,'ultra');
 assert.equal((await tool('read_workspace',{workspace_id:state.id})).structuredContent.markdown,markdown);
 assert.equal((await tool('begin_codex_run',{workspace_id:state.id,revision:state.revision,slide_index:0,block_id:'not-a-card'})).isError,true);
});
