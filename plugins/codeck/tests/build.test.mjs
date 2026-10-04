import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { Script } from 'node:vm';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';

const run = promisify(execFile);

test('native helper records the current SDK while preserving macOS 14 compatibility', { skip: process.platform !== 'darwin' }, async () => {
  const { stdout: sdk } = await run('xcrun', ['--sdk', 'macosx', '--show-sdk-version']);
  for (const relative of ['../build/codeck-mcp', '../build/Codeck Workspace.app/Contents/MacOS/codeck-mcp']) {
    const binary = fileURLToPath(new URL(relative, import.meta.url));
    const { stdout: build } = await run('xcrun', ['vtool', '-show-build', binary]);
    const minimums = [...build.matchAll(/^\s+minos\s+(\S+)/gm)].map(match => match[1]);
    const sdks = [...build.matchAll(/^\s+sdk\s+(\S+)/gm)].map(match => match[1]);
    assert.ok(minimums.length > 0, `${relative} has no macOS deployment target`);
    assert.ok(sdks.length > 0, `${relative} has no recorded SDK`);
    assert.ok(minimums.every(value => value === '14.0'), `${relative} raised the deployment target`);
    assert.ok(sdks.every(value => value === sdk.trim()), `${relative} does not record the build SDK`);
  }
  const plist = fileURLToPath(new URL('../build/Codeck Workspace.app/Contents/Info.plist', import.meta.url));
  const { stdout: minimum } = await run('plutil', ['-extract', 'LSMinimumSystemVersion', 'raw', plist]);
  assert.equal(minimum.trim(), '14.0');
});

test('self-contained HTML preserves the bundle, including replacement metacharacters', async () => {
  const html = await readFile(new URL('../build/workspace.html', import.meta.url), 'utf8');
  const original = await readFile(new URL('../build/workspace.js', import.meta.url), 'utf8');
  const script = html.slice(html.indexOf('<script>') + 8, html.lastIndexOf('</script>'));
  assert.equal(script, original.replace(/<\/script/gi, '<\\/script'));
  assert.doesNotThrow(() => new Script(script));
  assert.doesNotMatch(html, /<script[^>]+src=/);
});
