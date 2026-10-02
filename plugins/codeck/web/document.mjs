/** Source ranges follow CodeckCore: front matter and --- outside fenced blocks. */
export function slideRanges(source) {
  const lines = [...source.matchAll(/[^\n]*(?:\n|$)/g)].filter(match => match[0]);
  let first = 0;
  while (first < lines.length && !lines[first][0].trim()) first++;
  let bodyStart = 0;
  if (lines[first]?.[0].trim() === '---') {
    const end = lines.findIndex((line, index) => index > first && line[0].trim() === '---');
    if (end >= 0) bodyStart = lines[end].index + lines[end][0].length;
  } else if (/^<!-- codeck-theme:.*-->$/.test(lines[first]?.[0].trim() ?? '')) {
    bodyStart = lines[first].index + lines[first][0].length;
  }
  const ranges = [];
  let start = bodyStart;
  let fence = null;
  const append = end => {
    const text = source.slice(start, end);
    const markdown = text.trim();
    if (markdown) ranges.push({ from: start + text.indexOf(markdown), to: start + text.indexOf(markdown) + markdown.length, markdown });
  };
  for (const line of lines) {
    if (line.index < bodyStart) continue;
    const text = line[0].trim();
    if (fence) {
      if (new RegExp(`^${fence[0]}{${fence.length},}\\s*$`).test(text)) fence = null;
    } else {
      const opening = text.match(/^(`{3,}|~{3,})/);
      if (opening) fence = opening[1];
      else if (text === '---') {
        append(line.index);
        start = line.index + line[0].length;
      }
    }
  }
  append(source.length);
  return { header: source.slice(0, bodyStart), ranges: ranges.length ? ranges : [{ from: bodyStart, to: source.length, markdown: '# ' }] };
}

export function replaceSlides(source, slides) {
  return slideRanges(source).header + '\n' + slides.join('\n\n---\n\n') + '\n';
}

/** Invisible deck identity for the native Codex composer; never captures clicks or selections. */
export function workspaceContext(state) {
  return { workspace_id: state.id, revision: state.revision, ...(state.path ? { path: state.path } : {}) };
}

export function fittedSlideSize(width,height) {
  const scale=Math.max(0,Math.min(width/1600,height/900));
  return {width:1600*scale,height:900*scale,scale};
}
