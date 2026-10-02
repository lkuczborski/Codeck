// Development-only MCP Apps host. Requests use the real Swift server. Prompts are
// recorded for verification, not sent to a model; actual iteration lives in Codex.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { randomBytes } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { MCPClient } from './mcp-client.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const port = Number(process.env.CODECK_PREVIEW_PORT || 4179);
const token = randomBytes(24).toString('hex');
const client = new MCPClient(process.env.CODECK_MCP_EXECUTABLE || path.join(root,'.build/debug/codeck-mcp'), {
  cwd: root, env: { CODECK_MCP_ALLOWED_ROOTS: process.env.CODECK_MCP_ALLOWED_ROOTS || root,
    ...(process.env.CODECK_WORKSPACE_STORAGE ? { CODECK_WORKSPACE_STORAGE: process.env.CODECK_WORKSPACE_STORAGE } : {}) },
});
await client.initialize();
const tools = new Set((await client.request('tools/list')).tools.map(tool => tool.name));
const server = createServer(async (request, response) => {
  if (request.headers.host !== `127.0.0.1:${port}`) { response.writeHead(403).end(); return; }
  const url = new URL(request.url,`http://127.0.0.1:${port}`);
  try {
    if (url.pathname === '/workspace') {
      response.setHeader('Content-Type','text/html; charset=utf-8');
      response.end(await readFile(path.join(root,'plugins/codeck/build/workspace.html')));
    } else if (url.pathname === '/api' && request.method === 'POST') {
      if (request.headers['x-codeck-preview'] !== token || request.headers.origin !== `http://127.0.0.1:${port}`) { response.writeHead(403).end(); return; }
      let body = '';
      for await (const chunk of request) { body += chunk; if (body.length > 3_000_000) throw new Error('Request too large.'); }
      const { method, params } = JSON.parse(body);
      if (method !== 'tools/call' || !tools.has(params?.name)) { response.writeHead(403).end(); return; }
      const result = await client.request(method,params);
      response.setHeader('Content-Type','application/json');
      response.end(JSON.stringify(result));
    } else if (url.pathname === '/') {
      const deck = url.searchParams.get('deck');
      const theme = url.searchParams.get('theme') === 'light' ? 'light' : 'dark';
      response.setHeader('Content-Type','text/html; charset=utf-8');
      response.end(`<!doctype html><html><head><title>Codeck workspace preview</title><style>body{margin:0;background:#eee;font:12px system-ui}header{height:30px;display:flex;align-items:center;padding:0 12px;gap:8px;color:#202124}select{font:inherit}iframe{display:block;width:100vw;height:calc(100vh - 30px);border:0}</style></head><body><header><label for="host-theme">Preview host appearance</label><select id="host-theme"><option value="light">Light</option><option value="dark">Dark</option></select><output id="events" style="margin-left:auto">Context updates: 0 · Messages: 0</output></header><iframe id="workspace" src="/workspace" allow="fullscreen; clipboard-write"></iframe><script>
        const frame=document.getElementById('workspace');
        const appearance=document.getElementById('host-theme');
        appearance.value=${JSON.stringify(theme)};
        function hostContext(){const dark=appearance.value==='dark';return {theme:appearance.value,displayMode:'fullscreen',availableDisplayModes:['inline','fullscreen'],styles:{variables:{'--color-background-primary':dark?'#181a1c':'#ffffff','--color-background-secondary':dark?'#202224':'#f6f6f6','--color-background-tertiary':dark?'#2b2d30':'#ececec','--color-text-primary':dark?'#ededee':'#202124','--color-text-secondary':dark?'#acb0b5':'#606468','--color-border-primary':dark?'#3e4145':'#d7d9dc','--color-background-inverse':dark?'#ededee':'#202124','--color-text-inverse':dark?'#181a1c':'#ffffff'}}};}
        appearance.onchange=()=>frame.contentWindow.postMessage({jsonrpc:'2.0',method:'ui/notifications/host-context-changed',params:hostContext()},location.origin);

        window.codeckMessages=[];window.codeckContext=null;let contextUpdates=0;const events=document.getElementById('events');function showEvents(){events.textContent='Context updates: '+contextUpdates+' · Messages: '+window.codeckMessages.length;events.dataset.context=JSON.stringify(window.codeckContext);}
        const token=${JSON.stringify(token)};
        const initialArgs=${JSON.stringify(deck ? { path: deck } : {}).replace(/</g,'\\u003c')};
        async function tool(params){const response=await fetch('/api',{method:'POST',headers:{'Content-Type':'application/json','X-Codeck-Preview':token},body:JSON.stringify({method:'tools/call',params})});if(!response.ok)throw new Error('Preview request failed');return response.json();}
        window.codeckTool=tool;
        window.addEventListener('message',async event=>{
          if(event.source!==frame.contentWindow||event.origin!==location.origin)return;
          const message=event.data;if(message?.jsonrpc!=='2.0')return;
          const reply=result=>frame.contentWindow.postMessage({jsonrpc:'2.0',id:message.id,result},location.origin);
          try {
            if(message.method==='ui/initialize')reply({protocolVersion:message.params.protocolVersion,hostInfo:{name:'Codeck Preview',version:'0.1.0'},hostCapabilities:{serverTools:{},message:{text:{}},updateModelContext:{text:{},structuredContent:{}},experimental:{'openai/message':{}}},hostContext:hostContext()});
            else if(message.method==='ui/notifications/initialized'){frame.contentWindow.postMessage({jsonrpc:'2.0',method:'ui/notifications/tool-result',params:await tool({name:'open_workspace',arguments:initialArgs})},location.origin);}
            else if(message.method==='tools/call')reply(await tool(message.params));
            else if(message.method==='ui/message'){window.codeckMessages.push(message.params);showEvents();reply({});}
            else if(message.method==='ui/update-model-context'){window.codeckContext=message.params;contextUpdates++;showEvents();reply({});}
            else if(message.method==='ui/request-display-mode')reply({mode:message.params.mode});
            else if(message.id!==undefined)reply({});
          } catch(error){if(message.id!==undefined)frame.contentWindow.postMessage({jsonrpc:'2.0',id:message.id,error:{code:-32000,message:error.message}},location.origin);}
        });
      </script></body></html>`);
    } else { response.writeHead(404).end(); }
  } catch(error) { response.writeHead(500,{'Content-Type':'application/json'}).end(JSON.stringify({error:error.message})); }
});
server.listen(port,'127.0.0.1',()=>console.log(`Codeck preview: http://127.0.0.1:${port}`));
function stop(){server.close();client.close();}
process.on('SIGINT',stop);process.on('SIGTERM',stop);
