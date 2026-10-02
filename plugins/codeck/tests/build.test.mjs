import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { Script } from 'node:vm';

test('self-contained HTML preserves the bundle, including replacement metacharacters', async () => {
  const html = await readFile(new URL('../build/workspace.html', import.meta.url), 'utf8');
  const original = await readFile(new URL('../build/workspace.js', import.meta.url), 'utf8');
  const script = html.slice(html.indexOf('<script>') + 8, html.lastIndexOf('</script>'));
  assert.equal(script, original.replace(/<\/script/gi, '<\\/script'));
  assert.doesNotThrow(() => new Script(script));
  assert.doesNotMatch(html, /<script[^>]+src=/);
});
