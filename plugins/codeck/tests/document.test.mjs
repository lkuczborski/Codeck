import test from 'node:test';
import assert from 'node:assert/strict';
import { slideRanges, replaceSlides, workspaceContext } from '../web/document.mjs';

test('source ranges preserve YAML, CRLF, and separators in differently sized fences', () => {
  const source = '---\r\nformat: codeck.mdeck\r\ncustom: preserve\r\n---\r\n\r\n# First\r\n\r\n````swift\r\n---\r\n```\r\n````\r\n\r\n---\r\n\r\n# Second';
  const { header, ranges } = slideRanges(source);
  assert.match(header, /custom: preserve/);
  assert.equal(ranges.length, 2);
  assert.match(ranges[0].markdown, /---/);
  assert.equal(source.slice(ranges[1].from, ranges[1].to), '# Second');
  assert.ok(replaceSlides(source, ['# New', '# Second']).startsWith(header));
});
test('tilde fences and legacy theme headers do not turn code into slides', () => {
  const source = '<!-- codeck-theme: midnight -->\n# One\n~~~python\n---\n~~~\n---\n# Two';
  assert.equal(slideRanges(source).ranges.length, 2);
  assert.match(slideRanges(source).header, /midnight/);
});
test('native composer context contains only the active deck identity and revision', () => {
  const state = { id: 'deck-id', revision: 7, path: '/decks/talk.mdeck', selected: 1,
    markdown: '# Private source', annotations: [{ text: 'Old note' }] };
  assert.deepEqual(workspaceContext(state), { workspace_id: 'deck-id', revision: 7, path: '/decks/talk.mdeck' });
  assert.deepEqual(workspaceContext({ id: 'draft', revision: 0 }), { workspace_id: 'draft', revision: 0 });
});

test('whole slide fits wide short and narrow tall previews', async () => {
  const {fittedSlideSize}=await import('../web/document.mjs');
  for(const [width,height] of [[1600,200],[300,900],[800,450]]) {
    const fit=fittedSlideSize(width,height);
    assert.ok(fit.width<=width && fit.height<=height);
    assert.equal(fit.width/fit.height,16/9);
  }
});
