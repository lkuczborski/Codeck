import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, copyFile, symlink, rm, realpath } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { MCPClient } from '../scripts/mcp-client.mjs';

const pluginRoot = fileURLToPath(new URL('..', import.meta.url));
const repositoryRoot = path.resolve(pluginRoot, '../..');

test('declared plugin transport starts from a path with spaces and keeps drafts outside the package', async t => {
  const directory = await mkdtemp(path.join(tmpdir(), 'codeck-launch-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const installed = path.join(directory, 'plugin package');
  const presentations = path.join(directory, 'presentation files');
  await Promise.all([
    mkdir(path.join(installed, 'scripts'), { recursive: true }),
    mkdir(path.join(installed, 'build/Codeck Workspace.app/Contents/MacOS'), { recursive: true }),
    mkdir(presentations),
  ]);
  await copyFile(path.join(pluginRoot, 'scripts/run-server.sh'), path.join(installed, 'scripts/run-server.sh'));
  await symlink(process.env.CODECK_MCP_EXECUTABLE || path.join(repositoryRoot, '.build/debug/codeck-mcp'), path.join(installed, 'build/codeck-mcp'));
  await symlink(process.env.CODECK_MCP_EXECUTABLE || path.join(repositoryRoot, '.build/debug/codeck-mcp'), path.join(installed, 'build/Codeck Workspace.app/Contents/MacOS/codeck-mcp'));
  await symlink(path.join(pluginRoot, 'build/workspace.html'), path.join(installed, 'build/workspace.html'));
  const manifest = JSON.parse(await readFile(path.join(pluginRoot, '.mcp.json'), 'utf8'));
  const server = manifest.mcpServers['codeck-workspace'];
  const client = new MCPClient(server.command, {
    args: server.args,
    cwd: path.resolve(installed, server.cwd),
    env: { CODECK_MCP_ALLOWED_ROOTS: presentations, CODECK_MCP_WORKING_DIRECTORY: presentations },
  });
  t.after(() => client.close());
  await client.initialize();
  const tools = (await client.request('tools/list')).tools;
  const open = tools.find(tool => tool.name === 'open_workspace');
  assert.deepEqual(open._meta['openai/ui'].entrypoints, [{ type: 'global' }, { type: 'thread' }]);
  const library = await client.request('tools/call', { name: 'open_workspace', arguments: {} });
  assert.notEqual(library.isError, true);
  assert.deepEqual(await Promise.all(library.structuredContent.allowedRoots.map(root => realpath(root))), [await realpath(presentations)]);
  const draft = await client.request('tools/call', { name: 'open_workspace', arguments: { markdown: '# Portable launcher' } });
  assert.notEqual(draft.isError, true);
  const stored = JSON.parse(await readFile(path.join(presentations, '.codeck-workspaces', `${draft.structuredContent.id}.json`), 'utf8'));
  assert.equal(stored.markdown, '# Portable launcher');
  const resource = await client.request('resources/read', { uri: open._meta.ui.resourceUri });
  assert.match(resource.contents[0].text, /Deck Markdown/);
});
