import { EditorSelection, type EditorState, type TransactionSpec } from '@codemirror/state';
import { ensureSyntaxTree, syntaxTree } from '@codemirror/language';
import type { SyntaxNode } from '@lezer/common';

export type Format = 'bold' | 'italic' | 'inlineCode' | 'strikethrough' | 'link';
const nodeNames: Record<Format,string> = { bold: 'StrongEmphasis', italic: 'Emphasis', inlineCode: 'InlineCode', strikethrough: 'Strikethrough', link: 'Link' };
const markers: Record<Format,string> = { bold: '**', italic: '*', inlineCode: '`', strikethrough: '~~', link: '' };

function formattingNode(state: EditorState, style: Format): SyntaxNode | null {
  const { from, to } = state.selection.main;
  const tree = ensureSyntaxTree(state, to, 50) ?? syntaxTree(state);
  let node: SyntaxNode | null = tree.resolveInner(from, 1);
  let found: SyntaxNode | null = null;
  while (node) {
    if (['FencedCode','CodeBlock','YAMLFrontmatter'].includes(node.name)) return null;
    if (node.name === nodeNames[style] && to <= node.to) found ??= node;
    node = node.parent;
  }
  return found;
}
export function activeFormatting(state: EditorState): Set<Format> {
  return new Set((Object.keys(nodeNames) as Format[]).filter(style => formattingNode(state,style)));
}
function wordRange(state: EditorState) {
  const {from,to} = state.selection.main;
  if (from !== to) return {from,to};
  const source = state.doc.toString();
  for (const match of source.matchAll(/[\p{L}\p{N}_-]+/gu)) {
    if (match.index! <= from && match.index! + match[0].length >= from) return {from:match.index!,to:match.index!+match[0].length};
  }
  return {from,to};
}
export function formatEdit(state: EditorState, style: Format): TransactionSpec {
  const node = formattingNode(state,style);
  if (node) {
    const text = state.sliceDoc(node.from,node.to);
    let inner: string;
    if (style === 'link') {
      const marks = node.getChildren('LinkMark');
      const opening = marks.find(mark => state.sliceDoc(mark.from,mark.to) === '[');
      const closing = marks.find(mark => state.sliceDoc(mark.from,mark.to).startsWith(']'));
      if (!opening || !closing) return {};
      inner = state.sliceDoc(opening.to,closing.from);
    } else {
      const marker = style === 'inlineCode' ? text.match(/^`+/)![0] : text.startsWith('_') ? markers[style].replace(/\*/g,'_') : markers[style];
      inner = text.slice(marker.length,-marker.length);
    }
    return { changes:{from:node.from,to:node.to,insert:inner}, selection:EditorSelection.range(node.from,node.from+inner.length), userEvent:'input.format' };
  }
  const {from,to} = wordRange(state);
  const text = state.sliceDoc(from,to) || (style === 'inlineCode' ? 'code' : style === 'link' ? 'Link text' : 'text');
  if (style === 'link') {
    const url='https://example.com'; const insert=`[${text}](${url})`; const start=from+text.length+3;
    return {changes:{from,to,insert},selection:EditorSelection.range(start,start+url.length),userEvent:'input.format'};
  }
  let marker = markers[style];
  if (style === 'inlineCode') {
    const longest = Math.max(0,...[...text.matchAll(/`+/g)].map(match=>match[0].length)); marker='`'.repeat(longest+1);
  }
  const insert=marker+text+marker;
  return {changes:{from,to,insert},selection:EditorSelection.range(from+marker.length,from+marker.length+text.length),userEvent:'input.format'};
}
export const insertions = [
  ['heading1','Heading 1','# Heading','Heading'], ['heading2','Heading 2','## Heading','Heading'], ['heading3','Heading 3','### Heading','Heading'],
  ['paragraph','Paragraph','Paragraph text','Paragraph text'], ['bulletedList','Bulleted list','- First item\n- Second item','First item'],
  ['numberedList','Numbered list','1. First item\n2. Second item','First item'], ['blockquote','Quote','> Quote text','Quote text'],
  ['link','Link','[Link text](https://example.com)','Link text'], ['image','Image','![Alt text](Images/example.png)','Alt text'],
  ['codeBlock','Code block','```swift\nlet value = "Hello"\n```','let value = "Hello"'],
  ['table','Table','| Header | Header |\n| --- | --- |\n| Cell | Cell |','Header'], ['horizontalRule','Divider','***',''],
  ['codexSession','Codex session','', 'Describe the goal for this prompt'],
] as const;
export function insertionEdit(state: EditorState, key: string): TransactionSpec {
  const item = insertions.find(item=>item[0]===key); if(!item) return {};
  const {from,to}=state.selection.main; const source=state.doc.toString();
  let template: string=item[2];
  if(key==='codexSession') {
    let number=1;while(new RegExp(`\\bid=demo-${number}(?:\\s|$)`).test(source)) number++;
    template=`\`\`\`codex id=demo-${number}\ntitle: Describe the goal for this prompt\n\nExplain this concept with one concrete example.\n\`\`\``;
  }
  const before=source.slice(0,from),after=source.slice(to);
  const prefix=key==='link'||!before||before.endsWith('\n\n')?'':before.endsWith('\n')?'\n':'\n\n';
  const suffix=key==='link'||!after||after.startsWith('\n\n')?'':after.startsWith('\n')?'\n':'\n\n';
  const placeholder=item[3];const start=from+prefix.length+(placeholder?template.indexOf(placeholder):template.length);
  return {changes:{from,to,insert:prefix+template+suffix},selection:EditorSelection.range(start,start+placeholder.length),userEvent:'input.insert'};
}
