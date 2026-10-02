import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { MCPClient } from '../scripts/mcp-client.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const executable=process.env.CODECK_MCP_EXECUTABLE||path.join(root,'.build/debug/codeck-mcp');

test('sidebar registration, resource, drafts, saves, and agent edits use one workspace', async t => {
  const directory=await mkdtemp(path.join(tmpdir(),'codeck-plugin-'));
  t.after(()=>rm(directory,{recursive:true,force:true}));
  const client=new MCPClient(executable,{cwd:directory,env:{CODECK_MCP_ALLOWED_ROOTS:directory,CODECK_WORKSPACE_UI_PATH:path.join(root,'plugins/codeck/build/workspace.html')}});
  t.after(()=>client.close());
  await client.initialize();
  const tools=(await client.request('tools/list')).tools;
  assert.equal(tools.length,24);
  assert.ok(tools.every(tool => !['annotate_workspace','resolve_annotation'].includes(tool.name)));
  for (const item of tools) {
    for (const hint of ['readOnlyHint', 'destructiveHint', 'openWorldHint']) {
      assert.equal(typeof item.annotations[hint], 'boolean', `${item.name}: ${hint}`);
    }
  }
  for (const name of ['read_deck', 'list_slides', 'get_slide', 'validate_deck', 'render_markdown']) {
    assert.deepEqual(tools.find(item => item.name === name).annotations,
      { readOnlyHint: true, destructiveHint: false, openWorldHint: false });
  }
  for (const name of ['update_workspace', 'save_workspace', 'reload_workspace', 'choose_save_workspace', 'delete_slide']) {
    assert.equal(tools.find(item => item.name === name).annotations.destructiveHint, true);
  }
  assert.deepEqual(tools.find(item => item.name === 'begin_codex_run').annotations,
    { readOnlyHint: false, destructiveHint: true, openWorldHint: true });
  const open=tools.find(tool=>tool.name==='open_workspace');
  assert.deepEqual(open._meta['openai/ui'].entrypoints,[{type:'global'},{type:'thread'}]);
  assert.ok(open.icons[0].src.startsWith('data:image/svg+xml;base64,'));
  const sidebarIcon = Buffer.from(open.icons[0].src.split(',')[1], 'base64').toString('utf8');
  assert.equal(sidebarIcon, (await readFile(path.join(root, 'plugins/codeck/assets/icon.svg'), 'utf8')).trim());
  const resource=(await client.request('resources/read',{uri:open._meta.ui.resourceUri})).contents[0];
  assert.equal(resource.mimeType,'text/html;profile=mcp-app');
  assert.match(resource.text,/Deck Markdown/);
  assert.equal(resource._meta['openai/ui'].preferredDisplayMode,'fullscreen');
  async function tool(name,args={}){return client.request('tools/call',{name,arguments:args});}
  const library=await tool('open_workspace');
  assert.deepEqual(library.structuredContent.recent,[]);
  let response=await tool('open_workspace',{markdown:'# Swift\n\n```swift\nlet message = "hello"\n```\n\n---\n\n# Python\n\n```python\nprint("hello")\n```',title:'Languages'});
  let state=response.structuredContent;
  assert.ok(state.id);
  const unchanged=await tool('read_workspace',{workspace_id:state.id,known_revision:state.revision});
  assert.equal(unchanged.structuredContent.unchanged,true);
  assert.equal(unchanged._meta,undefined);
  assert.equal((await tool('update_workspace',{workspace_id:state.id,revision:true,markdown:'# Invalid'})).isError,true);
  assert.equal((await tool('update_workspace',{workspace_id:state.id,revision:0.5,markdown:'# Invalid'})).isError,true);
  assert.match(response._meta.preview.slides[0].html,/syntax-keyword/);
  assert.match(response._meta.preview.slides[1].html,/syntax-string/);
  response=await tool('update_workspace',{workspace_id:state.id,revision:state.revision,markdown:state.markdown+'\n'});
  state=response.structuredContent;
  assert.equal('annotations' in state,false);
  const stale=await tool('update_workspace',{workspace_id:state.id,revision:0,markdown:'# Lost edit'});
  assert.equal(stale.isError,true);
  const saved=await tool('save_workspace',{workspace_id:state.id,revision:state.revision,path:path.join(directory,'lesson.mdeck')});
  state=saved.structuredContent;
  assert.equal(state.dirty,false);
  assert.equal(await readFile(state.path,'utf8'),state.markdown);
  const external=await tool('set_slide_markdown',{path:state.path,index:0,markdown:'# Agent change'});
  assert.equal(external.isError,false);
  const refreshed=await tool('read_workspace',{workspace_id:state.id});
  assert.match(refreshed.structuredContent.markdown,/# Agent change/);
  assert.equal('annotations' in refreshed.structuredContent,false);
  assert.equal(refreshed._meta['openai/outputTemplate'],undefined);
  const reused=await tool('open_workspace',{path:state.path});
  assert.equal(reused.structuredContent.id,state.id);
  assert.equal((await tool('open_workspace',{path:'/etc/passwd'})).isError,true);
  await symlink('/etc',path.join(directory,'outside'));
  assert.equal((await tool('save_workspace',{workspace_id:state.id,revision:refreshed.structuredContent.revision,path:path.join(directory,'outside/deck.mdeck')})).isError,true);
  const image=path.join(directory,'image.png');
  await writeFile(image,Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=','base64'));
  const rendered=await tool('render_markdown',{markdown:'# Image\n\n![Test](image.png)',path:state.path});
  assert.match(rendered._meta.preview.slides[0].html,/data:image\/png;base64/);
  const denied=await tool('render_markdown',{markdown:'![Private](../outside.png)',path:state.path});
  assert.notEqual(denied.isError,true);
  assert.doesNotMatch(denied._meta.preview.slides[0].html,/data:image/);
});
