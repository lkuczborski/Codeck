import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const bundle=await build({stdin:{contents:`export {EditorState} from '@codemirror/state';export {markdown} from '@codemirror/lang-markdown';export * from './web/editor-operations.ts';`,resolveDir:process.cwd()},bundle:true,outfile:'build/editor-test-bundle.mjs',format:'esm',platform:'node'});
const {EditorState,markdown,activeFormatting,formatEdit,insertionEdit}=await import(pathToFileURL(path.resolve('build/editor-test-bundle.mjs')).href);
const state=(doc,anchor,head=anchor)=>EditorState.create({doc,selection:{anchor,head},extensions:[markdown()]});
test('format controls follow parsed caret styles and toggle them off',()=>{
  let current=state('**Hello** and *world*',4);
  assert.ok(activeFormatting(current).has('bold'));
  current=current.update(formatEdit(current,'bold')).state;
  assert.equal(current.doc.toString(),'Hello and *world*');
  assert.equal(activeFormatting(current).has('bold'),false);
  const link=state('[Hello](https://example.com)',3);
  assert.ok(activeFormatting(link).has('link'));
  assert.equal(link.update(formatEdit(link,'link')).state.doc.toString(),'Hello');
});
test('fenced code does not activate fake formatting; Unicode words and selections wrap',()=>{
  assert.equal(activeFormatting(state('```swift\n**fake**\n```',12)).size,0);
  assert.equal(state('żółw walks',2).update(formatEdit(state('żółw walks',2),'bold')).state.doc.toString(),'**żółw** walks');
  const current=state('hello world',0,5);
  const next=current.update(formatEdit(current,'italic')).state;
  assert.equal(next.doc.toString(),'*hello* world');
  assert.equal(next.sliceDoc(next.selection.main.from,next.selection.main.to),'hello');
});
test('block insertions preserve surrounding paragraphs and select placeholders',()=>{
  const current=state('beforeafter',6);
  const next=current.update(insertionEdit(current,'codeBlock')).state;
  assert.equal(next.doc.toString(),'before\n\n```swift\nlet value = "Hello"\n```\n\nafter');
  assert.equal(next.sliceDoc(next.selection.main.from,next.selection.main.to),'let value = "Hello"');
  const source='```codex id=demo-1\nPrompt\n```\n\n';
  const existing=state(source,source.length);
  assert.match(existing.update(insertionEdit(existing,'codexSession')).state.doc.toString(),/id=demo-2/);
});
