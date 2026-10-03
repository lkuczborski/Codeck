import { basicSetup, EditorView } from 'codemirror';
import { EditorState, Compartment } from '@codemirror/state';
import { markdown, markdownLanguage } from '@codemirror/lang-markdown';
import { yamlFrontmatter } from '@codemirror/lang-yaml';
import { languages } from '@codemirror/language-data';
import { LanguageDescription, syntaxHighlighting, defaultHighlightStyle } from '@codemirror/language';
import { oneDark } from '@codemirror/theme-one-dark';
import { createIcons, FolderOpen, Save, CopyPlus, Play, Plus, Copy, Trash2, Code, Columns2, PanelTop, FileCode2, Monitor, ChevronLeft, ChevronRight, Maximize, Minimize, X, Presentation, ArrowLeft, Bold, Italic, Strikethrough, Link, ChevronDown } from 'lucide';
import { app, call } from './bridge';
import { applyDocumentTheme, applyHostStyleVariables, type McpUiHostContext } from '@modelcontextprotocol/ext-apps';
import { slideRanges, replaceSlides, workspaceContext, fittedSlideSize } from './document.mjs';
import { activeFormatting, formatEdit, insertionEdit, insertions, type Format } from './editor-operations';
import './style.css';

type Slide = { index: number; title: string; markdown: string; html?: string; blocks?: { id: string; title: string }[] };
type Workspace = { id: string; title: string; markdown: string; path?: string; revision: number; dirty: boolean; diskConflict: boolean; diskAccessRequired?: boolean; slides: Slide[]; theme: string };
type Preview = { theme: string; slides: Slide[] };
type Recent = { id: string; title: string; path?: string; dirty: boolean };
type ToolResult = { structuredContent?: Record<string, unknown>; _meta?: Record<string, unknown> };

function $(id: 'theme'): HTMLSelectElement;
function $(id: 'dialog-input'): HTMLInputElement;
function $(id: 'dialog'): HTMLDialogElement;
function $(id: 'dialog-submit'): HTMLButtonElement;
function $(id: string): HTMLElement;
function $(id: string) { return document.getElementById(id)!; }
const icons = { FolderOpen, Save, CopyPlus, Play, Plus, Copy, Trash2, Code, Columns2, PanelTop, FileCode2, Monitor, ChevronLeft, ChevronRight, Maximize, Minimize, X, Presentation, ArrowLeft, Bold, Italic, Strikethrough, Link, ChevronDown };
const refreshIcons = () => createIcons({ icons, attrs: { 'aria-hidden': 'true' } });
let state: Workspace | null = null;
let preview: Preview | null = null;
let selected = 0;
let sourceChanged = false;
let applying = false;
let conflict = false;
let desktopPending = false;
let runVersion = -1;
let runPollPending = false;
let cardRuns: {id:string;blockID:string;status:string}[] = [];
let previewSequence = 0;
let saveTimer: ReturnType<typeof setTimeout> | undefined;
let renderTimer: ReturnType<typeof setTimeout> | undefined;
let contextTimer: ReturnType<typeof setTimeout> | undefined;
let queue: Promise<unknown> = Promise.resolve();
let dialogSubmit: (() => Promise<void>) | undefined;
const wrapping = new Compartment();
const editorAppearance = new Compartment();

const editor = new EditorView({
  parent: $('markdown-editor'),
  state: EditorState.create({ extensions: [basicSetup, editorAppearance.of([syntaxHighlighting(defaultHighlightStyle), EditorView.theme({}, { dark: false })]), wrapping.of(EditorView.lineWrapping),
    yamlFrontmatter({ content: markdown({ base: markdownLanguage, codeLanguages: info => {
      const language = info.replace(/^\{?\.?/, '').split(/[\s}]/)[0].replace(/^(language-|lang-)/, '').toLowerCase();
      const aliases: Record<string, string> = { js: 'javascript', ts: 'typescript', py: 'python', sh: 'shell', zsh: 'shell', fish: 'shell', cs: 'csharp', 'c#': 'csharp', 'c++': 'cpp', objc: 'objective-c', yml: 'yaml', toml: 'toml', md: 'markdown', rb: 'ruby', golang: 'go', codex: 'yaml' };
      return LanguageDescription.matchLanguageName(languages, aliases[language] ?? language, true);
    } }) }),
    EditorView.contentAttributes.of({ 'aria-label': 'Deck Markdown', 'spellcheck': 'false' }),
    EditorView.updateListener.of(update => {
      if (update.docChanged && !applying) {
        sourceChanged = true;
        status('Editing · keeping draft…');
        clearTimeout(saveTimer);
        if (!conflict) saveTimer = setTimeout(() => void flushDraft().catch(showError), 650);
        clearTimeout(renderTimer);
        renderTimer = setTimeout(() => void renderDraft().catch(showError), 160);
      }
      if (update.selectionSet || update.docChanged) {
        updateFormatButtons(update.state);
        const head = update.state.selection.main.head;
        const line = update.state.doc.lineAt(head);
        $('cursor-status').textContent = `Ln ${line.number}, Col ${head - line.from + 1}`;
        const ranges = slideRanges(update.state.doc.toString()).ranges;
        const index = ranges.findLastIndex(range => range.from <= head);
        if (index >= 0 && index !== selected) { selected = index; renderSelection(); }
      }
    })] }),
});

function serial<T>(operation: () => Promise<T>): Promise<T> {
  const next = queue.then(operation);
  queue = next.catch(() => undefined);
  return next;
}

function status(message?: string, error = false) {
  $('sync-status').textContent = message ?? (state?.diskAccessRequired ? 'Draft preserved · reopen the file to restore disk access' : state?.diskConflict ? 'Disk changed · save a copy or reload' : sourceChanged ? 'Local edits pending' : 'Draft kept automatically');
  $('sync-dot').classList.toggle('error', error || !!state?.diskConflict);
  $('deck-status').textContent = !state ? '' : state.diskAccessRequired ? `Draft · ${state.path?.split('/').pop()}` : state.diskConflict ? 'Disk conflict · draft preserved' : state.path ? `${state.dirty || sourceChanged ? 'Unsaved changes · ' : 'Saved · '}${state.path.split('/').pop()}` : 'Unsaved draft';
  document.querySelector<HTMLButtonElement>('[data-action="reload-disk"]')!.disabled = !state?.path || !!state.diskAccessRequired;
}

function toast(message: string, error = false) {
  $('toast').textContent = message;
  $('toast').classList.remove('hidden');
  $('toast').classList.toggle('error', error);
  setTimeout(() => $('toast').classList.add('hidden'), error ? 12000 : 4000);
}
function showError(error: unknown) { toast(error instanceof Error ? error.message : String(error), true); }

function setSource(source: string) {
  if (editor.state.doc.toString() === source) return;
  applying = true;
  editor.dispatch({ changes: { from: 0, to: editor.state.doc.length, insert: source }, selection: { anchor: Math.min(editor.state.selection.main.head, source.length) } });
  applying = false;
}

function accept(result: ToolResult, preserveSource = false) {
  const data = result.structuredContent;
  if (data && typeof data.id === 'string' && typeof data.markdown === 'string') {
    const next = data as unknown as Workspace;
    if (state?.id === next.id && next.revision < state.revision) return;
    if (state?.id !== next.id) { runVersion = -1; cardRuns = []; }
    state = next;
    if (!preserveSource) { sourceChanged = false; setSource(next.markdown); }
    if (result._meta?.preview && !preserveSource) preview = result._meta.preview as Preview;
    $('deck-title').textContent = next.title;
    document.querySelectorAll<HTMLButtonElement>('.toolbar [data-action="save"],.toolbar [data-action="save-as"],.toolbar [data-action="present"]').forEach(button => { button.disabled = false; });
    $('library').classList.add('hidden');
    $('editor-workspace').classList.remove('hidden');
    $('toolbar').classList.remove('hidden');
    $('connection-status').classList.add('hidden');
    status();
    renderNavigator();
    renderSelection();
    scheduleContext();
  } else if (data && Array.isArray(data.recent)) {
    state = null; preview = null; clearTimeout(contextTimer);
    if (app.getHostCapabilities()?.updateModelContext) void app.updateModelContext({ structuredContent: {} }).catch(() => undefined);
    $('toolbar').classList.add('hidden');
    $('connection-status').classList.add('hidden');
    $('library').classList.remove('hidden');
    $('editor-workspace').classList.add('hidden');
    document.querySelectorAll<HTMLButtonElement>('.toolbar [data-action="save"],.toolbar [data-action="save-as"],.toolbar [data-action="present"]').forEach(button => { button.disabled = true; });
    const recent = $('recent');
    recent.replaceChildren();
    for (const item of data.recent as Recent[]) {
      const card = document.createElement('button');
      card.className = 'recent-deck';
      card.innerHTML = '<i data-lucide="presentation"></i><strong></strong><span></span>';
      card.querySelector('strong')!.textContent = item.title;
      card.querySelector('span')!.textContent = item.path ? `${item.dirty ? 'Unsaved changes · ' : ''}${item.path}` : 'Unsaved draft';
      card.onclick = () => void openWorkspace({ workspace_id: item.id }).catch(showError);
      recent.append(card);
    }
    if (!recent.childElementCount) recent.textContent = 'No presentations yet.';
    $('roots').textContent = `Folders: ${(data.allowedRoots as string[] ?? []).join(', ')}.`;
    refreshIcons();
  }
}

async function openWorkspace(args: Record<string, unknown>) {
  await flushDraft();
  clearTimeout(renderTimer);
  ++previewSequence;
  const result = await serial(() => call('open_workspace', args));
  state = null;
  runVersion = -1; cardRuns = [];
  selected = 0;
  sourceChanged = false;
  conflict = false;
  $('conflict-banner').classList.add('hidden');
  accept(result);
}

async function flushDraft() {
  clearTimeout(saveTimer);
  if (!state || !sourceChanged) return;
  if (conflict) throw new Error('Review the concurrent edit first. Your Markdown is preserved in the editor.');
  await serial(async () => {
    if (!state || !sourceChanged) return;
    const source = editor.state.doc.toString();
    try {
      const result = await call('update_workspace', { workspace_id: state.id, revision: state.revision, markdown: source });
      const editedAgain = editor.state.doc.toString() !== source;
      sourceChanged = editedAgain;
      accept(result, editedAgain);
    } catch (error) {
      if (/workspace changed/i.test(String(error))) {
        conflict = true;
        $('conflict-banner').classList.remove('hidden');
      }
      status('Draft not persisted · editor text preserved', true);
      throw error;
    }
  });
}

async function renderDraft() {
  if (!state) return;
  const workspaceID = state.id;
  const sequence = ++previewSequence;
  const result = await call('render_markdown', { workspace_id: state.id, markdown: editor.state.doc.toString(), ...(state.path ? { path: state.path } : {}) });
  if (sequence !== previewSequence || state?.id !== workspaceID) return;
  preview = result._meta?.preview as Preview;
  renderNavigator();
  renderSelection();
}

// Native renderer HTML stays isolated in a ShadowRoot. Only presentation elements and
// styles are adopted. Card controls are built here from server-validated IDs; renderer scripts and handlers never run.
function mountSlide(target: HTMLElement, html: string, blocks: Slide['blocks'] = [], interactive = false) {
  const parsed = new DOMParser().parseFromString(html, 'text/html');
  parsed.querySelectorAll('script,iframe,object,embed,link,meta,base,form,input,button,textarea,select').forEach(node => node.remove());
  parsed.querySelectorAll('*').forEach(node => {
    for (const attribute of [...node.attributes]) {
      if (/^on/i.test(attribute.name) || ['srcdoc', 'formaction'].includes(attribute.name)) node.removeAttribute(attribute.name);
    }
    if (node.hasAttribute('href')) node.removeAttribute('href');
    if (node.hasAttribute('src')) {
      const value = node.getAttribute('src') ?? '';
      if (!/^data:image\/(png|jpeg|gif|webp);base64,/i.test(value)) {
        node.removeAttribute('src');
        node.setAttribute('alt', `${node.getAttribute('alt') ?? 'Image'} · use a local image within allowed folders`);
      }
    }
  });
  const shadow = target.shadowRoot ?? target.attachShadow({ mode: 'open' });
  const style = document.createElement('style');
  style.textContent = [...parsed.querySelectorAll('style')].map(node => node.textContent?.replace(/:root/g, ':host').replace(/\bhtml\b/g, ':host').replace(/\bbody\b/g, '.document')).join('\n') +
    '\n:host{display:block;width:1600px;height:900px;font:24px/1.45 -apple-system,BlinkMacSystemFont,sans-serif;color:var(--fg);background:var(--bg)}' +
    '.document{width:1600px;height:900px;display:block;overflow:hidden}.slide{width:1600px;min-height:900px;padding:88px;}h1{font-size:82px}h2{font-size:60px}h3{font-size:44px}img{max-height:558px}.slide-actions{display:none}';
  parsed.querySelectorAll('style').forEach(node => node.remove());
  const content = document.createElement('div');
  content.className = 'document';
  content.append(...parsed.body.childNodes);
  shadow.replaceChildren(style, content);
  if (interactive) for (const card of shadow.querySelectorAll<HTMLElement>('.codex-card')) {
    const id = card.dataset.codexId;
    if (!id || !blocks?.some(block => block.id === id)) continue;
    const running = card.classList.contains('state-running');
    const button = document.createElement('button');
    button.className = `icon-button codex-action ${running ? 'stop' : 'run'}`;
    button.type = 'button';
    button.setAttribute('aria-label', `${running ? 'Stop' : 'Run'} Codex session`);
    button.title = `${running ? 'Stop' : 'Run'} Codex session`;
    button.innerHTML = `<span class="${running ? 'stop-icon' : 'play-icon'}" aria-hidden="true"></span>`;
    button.onclick = () => void runCard(id,running).catch(showError);
    card.querySelector('.codex-card-heading')?.append(button);
  }
}

function renderNavigator() {
  if (!preview) return;
  selected = Math.min(selected, preview.slides.length - 1);
  $('slide-count').textContent = String(preview.slides.length);
  const list = $('slide-list');
  const scroll = list.scrollTop;
  list.replaceChildren();
  preview.slides.forEach((slide, index) => {
    const row = document.createElement('button');
    row.className = `slide-row${index === selected ? ' selected' : ''}`;
    row.setAttribute('aria-label', `Slide ${index + 1}: ${slide.title}`);
    row.setAttribute('aria-current', String(index === selected));
    row.draggable = true;
    row.dataset.index = String(index);
    row.innerHTML = '<div class="thumbnail"><div class="thumbnail-content"></div></div><div class="slide-row-label"><span class="number"></span><span class="title"></span></div>';
    row.querySelector('.number')!.textContent = String(index + 1).padStart(2, '0');
    row.querySelector('.title')!.textContent = slide.title;
    if (slide.html) mountSlide(row.querySelector('.thumbnail-content')!, slide.html);
    row.onclick = () => selectSlide(index, true);
    row.ondragstart = event => event.dataTransfer?.setData('text/codeck-slide', String(index));
    row.ondragover = event => event.preventDefault();
    row.ondrop = event => {
      event.preventDefault();
      const from = Number(event.dataTransfer?.getData('text/codeck-slide'));
      const slides = slideRanges(editor.state.doc.toString()).ranges.map(range => range.markdown);
      if (!Number.isInteger(from) || from < 0 || from >= slides.length) return;
      const [slide] = slides.splice(from, 1);
      slides.splice(index, 0, slide);
      editSource(replaceSlides(editor.state.doc.toString(), slides));
      selected = index;
    };
    list.append(row);
  });
  list.scrollTop = scroll;
  scaleSlides();
}

function selectSlide(index: number, moveCursor = false) {
  if (!preview) return;
  selected = Math.max(0, Math.min(index, preview.slides.length - 1));
  if (moveCursor) {
    const range = slideRanges(editor.state.doc.toString()).ranges[selected];
    if (range) editor.dispatch({ selection: { anchor: range.from }, effects: EditorView.scrollIntoView(range.from, { y: 'start' }) });
  }
  renderSelection();
}

function renderSelection() {
  if (!preview) return;
  const slide = preview.slides[selected];
  if (!slide) return;
  $('slide-label').textContent = `Slide ${String(selected + 1).padStart(2, '0')}`;
  $('slide-title').textContent = slide.title;
  for (const row of document.querySelectorAll<HTMLElement>('.slide-row')) {
    row.classList.toggle('selected', Number(row.dataset.index) === selected);
    row.setAttribute('aria-current', String(Number(row.dataset.index) === selected));
  }
  $('preview-position').textContent = `${selected + 1} / ${preview.slides.length}`;
  $('theme').value = preview.theme;
  if (slide.html) {
    mountSlide($('slide-surface'), slide.html,slide.blocks,true);
  }
  scaleSlides();
}

function scaleSlides() {
  const canvas = document.querySelector<HTMLElement>('.preview-canvas')!;
  const padding = getComputedStyle(canvas);
  const controls = document.querySelector<HTMLElement>('.preview-controls')!;
  const width = canvas.clientWidth - parseFloat(padding.paddingLeft) - parseFloat(padding.paddingRight);
  const height = canvas.clientHeight - parseFloat(padding.paddingTop) - parseFloat(padding.paddingBottom) - controls.offsetHeight - 12;
  if (width > 0 && height > 0) {
    const fit = fittedSlideSize(width,height);
    $('preview-stage').style.width = `${fit.width}px`;
    $('preview-stage').style.height = `${fit.height}px`;
    $('slide-surface').style.transform = `scale(${fit.scale})`;
  }
  document.querySelectorAll<HTMLElement>('.thumbnail-content').forEach(node => { node.style.transform = `scale(${node.parentElement!.clientWidth / 1600})`; });

}
new ResizeObserver(scaleSlides).observe(document.querySelector('.preview-canvas')!);
window.addEventListener('resize', scaleSlides);

async function mutate(name: string, args: Record<string, unknown> = {}) {
  await flushDraft();
  return serial(async () => {
    if (!state) return;
    const result = await call(name, { workspace_id: state.id, revision: state.revision, ...args });
    const localPending = sourceChanged;
    accept(result, localPending);
    return result;
  });
}
function editSource(source: string) { editor.dispatch({ changes: { from: 0, to: editor.state.doc.length, insert: source } }); }

function dialog(title: string, description: string, label: string, value: string, submit: string, operation: () => Promise<void>) {
  $('dialog-title').textContent = title;
  $('dialog-description').textContent = description;
  $('dialog-label').textContent = label;
  $('dialog-input').value = value;
  $('dialog-input').classList.remove('hidden');
  $('dialog-extra').replaceChildren();
  $('dialog-submit').textContent = submit;
  dialogSubmit = operation;
  $('dialog').showModal();
  setTimeout(() => $('dialog-input').focus(), 0);
}
$('dialog-form').onsubmit = async event => {
  event.preventDefault();
  $('dialog-submit').disabled = true;
  try { await dialogSubmit?.(); $('dialog').close(); }
  catch (error) { showError(error); }
  finally { $('dialog-submit').disabled = false; }
};

async function openDialog() {
  await flushDraft();
  desktopPending = true;
  let result;
  try { result = await serial(() => call('choose_open_workspace')); } finally { desktopPending = false; }
  if (!result.structuredContent?.cancelled) {
    state = null; selected = 0; sourceChanged = false; conflict = false; runVersion = -1;
    $('conflict-banner').classList.add('hidden'); accept(result);
  }
}
async function saveDialog() {
  desktopPending = true;
  let result;
  try { result = await mutate('choose_save_workspace'); } finally { desktopPending = false; }
  if (!result?.structuredContent?.cancelled) toast('Presentation saved to disk.');
}
async function present() {
  if (!state) return;
  await mutate('present_workspace',{slide_index:selected});
}
async function runCard(id: string, stop: boolean) {
  if (!state) return;
  await flushDraft();
  if (stop) {
    const run = cardRuns.findLast(run => run.blockID === id && run.status === 'running');
    if (run) await call('stop_codex_run',{run_id:run.id});
  } else await mutate('begin_codex_run',{slide_index:selected,block_id:id});
  await pollRuns();
}
async function pollRuns() {
  if (!state || runPollPending || desktopPending) return;
  const workspaceID = state.id;
  runPollPending = true;
  try {
    const result = await call('poll_codex_runs',{workspace_id:workspaceID,known_version:runVersion});
    if (state?.id !== workspaceID || result.structuredContent?.unchanged) return;
    runVersion = Number(result.structuredContent?.version ?? -1);
    cardRuns = result.structuredContent?.runs as typeof cardRuns ?? [];
    if (sourceChanged) await renderDraft();
    else if (result._meta?.preview) { preview = result._meta.preview as Preview; renderNavigator(); renderSelection(); }
  } finally { runPollPending = false; }
}
setInterval(() => void pollRuns().catch(showError),750);

function updateFormatButtons(editorState = editor.state) {
  const active = activeFormatting(editorState);
  for (const button of document.querySelectorAll<HTMLButtonElement>('[data-format]')) {
    const pressed = active.has(button.dataset.format as Format);
    button.classList.toggle('active',pressed); button.setAttribute('aria-pressed',String(pressed));
  }
}
const insertMenu = $('insert-options');
for (const [key,title] of insertions) {
  const button = document.createElement('button'); button.type='button'; button.dataset.insert=key; button.textContent=title;
  insertMenu.append(button);
}
document.addEventListener('pointerdown',event=>{
  if((event.target as HTMLElement).closest('[data-format],[data-insert]')) event.preventDefault();
});
document.addEventListener('click',event=>{
  const target = (event.target as HTMLElement).closest<HTMLElement>('[data-format],[data-insert]');
  if (!target) return;
  editor.dispatch(target.dataset.format ? formatEdit(editor.state,target.dataset.format as Format) : insertionEdit(editor.state,target.dataset.insert!));
  (document.querySelector('.insert-menu') as HTMLDetailsElement).open=false;
  editor.focus();
});

function scheduleContext() {
  clearTimeout(contextTimer);
  contextTimer = setTimeout(() => {
    if (!state || !app.getHostCapabilities()?.updateModelContext) return;
    void app.updateModelContext({ structuredContent: workspaceContext(state) }).catch(() => undefined);
  }, 450);
}

async function action(name: string) {
  switch (name) {
    case 'library': await openWorkspace({}); break;
    case 'new': await openWorkspace({ markdown: '---\nformat: codeck.mdeck\nversion: 1\ntheme: studio\n---\n\n# Untitled\n', title: 'Untitled deck' }); break;
    case 'open': await openDialog(); break;
    case 'save': if (state?.path && !state.diskConflict && !state.diskAccessRequired) { await mutate('save_workspace'); toast('Presentation saved to disk.'); } else await saveDialog(); break;
    case 'save-as': await saveDialog(); break;
    case 'present': await present(); break;
    case 'previous': selectSlide(selected - 1); break;
    case 'next': selectSlide(selected + 1); break;
    case 'close-dialog': $('dialog').close(); break;
    case 'recover-draft': {
      const local = editor.state.doc.toString();
      const result = await call('open_workspace', { markdown: local, title: `${state?.title ?? 'Deck'} · recovered draft` });
      conflict = false; state = null; sourceChanged = false; $('conflict-banner').classList.add('hidden'); accept(result);
      break;
    }
    case 'load-latest': {
      dialog('Load the latest draft?', 'This discards your local editor text. Use Keep as new draft to preserve it first.', '', '', 'Load latest', async () => {
        if (!state) return;
        const result = await call('read_workspace', { workspace_id: state.id });
        conflict = false; sourceChanged = false; $('conflict-banner').classList.add('hidden'); accept(result);
      });
      $('dialog-input').classList.add('hidden'); break;
    }
    case 'reload-disk': {
      dialog('Reload from disk?', 'This discards the current draft and replaces it with the file on disk.', '', '', 'Discard draft and reload', async () => {
        await mutate('reload_workspace');
      });
      $('dialog-input').classList.add('hidden'); break;
    }
    case 'add-slide': case 'duplicate-slide': case 'delete-slide': {
      const source = editor.state.doc.toString();
      const slides = slideRanges(source).ranges.map(range => range.markdown);
      if (name === 'delete-slide') { if (slides.length <= 1) return; slides.splice(selected,1); selected = Math.max(0,selected-1); }
      else { slides.splice(selected+1,0,name === 'duplicate-slide' ? slides[selected] : `# Slide ${slides.length + 1}\n`); selected++; }
      editSource(replaceSlides(source,slides));
      break;
    }
  }
}
document.addEventListener('click', event => {
  const button = (event.target as HTMLElement).closest<HTMLElement>('[data-action]');
  if (button) void action(button.dataset.action!).catch(showError);
  const mode = (event.target as HTMLElement).closest<HTMLElement>('[data-mode]');
  if (mode?.tagName === 'BUTTON') {
    $('split').dataset.mode = mode.dataset.mode;
    document.querySelectorAll('.view-switch button').forEach(button => button.classList.toggle('selected', button === mode));
    requestAnimationFrame(scaleSlides);
  }
});
$('theme').onchange = () => {
  let source = editor.state.doc.toString();
  const { header } = slideRanges(source);
  if (/^theme:/m.test(header)) source = source.replace(/^theme:.*$/m, `theme: ${$('theme').value}`);
  else if (header.trim().startsWith('---')) source = source.replace(/---[\t ]*\r?\n/, `---\ntheme: ${$('theme').value}\n`);
  else source = `---\nformat: codeck.mdeck\nversion: 1\ntheme: ${$('theme').value}\n---\n\n${source}`;
  editSource(source);
};
const handle = $('split-handle');
function setSplit(value: number) { value = Math.max(25,Math.min(75,value)); document.documentElement.style.setProperty('--editor-width',`${value}%`); handle.setAttribute('aria-valuenow',String(Math.round(value))); }
handle.onpointerdown = event => { handle.setPointerCapture(event.pointerId); };
handle.onpointermove = event => {
  if (!handle.hasPointerCapture(event.pointerId)) return;
  const bounds = $('split').getBoundingClientRect();
  setSplit((event.clientX - bounds.left) / bounds.width * 100);
};
handle.onkeydown = event => { if (['ArrowLeft','ArrowRight'].includes(event.key)) { event.preventDefault(); setSplit(Number(handle.getAttribute('aria-valuenow')) + (event.key === 'ArrowRight' ? 3 : -3)); } };
document.addEventListener('keydown', event => {
  if ((event.metaKey || event.ctrlKey) && editor.hasFocus && !event.altKey) {
    const format = ({b:'bold',i:'italic',k:'link'} as Record<string,Format>)[event.key.toLowerCase()];
    if (format) { event.preventDefault(); editor.dispatch(formatEdit(editor.state,format)); return; }
  }
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 's') { event.preventDefault(); void action('save').catch(showError); }
  if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') { event.preventDefault(); void present(); }
});

app.ontoolresult = result => {
  if (result.isError) {
    const message = result.content?.filter(item => item.type === 'text').map(item => item.text).join('\n') || 'Unable to open the presentation.';
    $('connection-status').textContent = message;
    showError(new Error(message));
    return;
  }
  const data = result.structuredContent as Record<string, unknown> | undefined;
  if (state && data?.id && data.id !== state.id) return;
  if (sourceChanged && data && data.id === state?.id && Number(data.revision) > (state?.revision ?? -1)) {
    conflict = true;
    clearTimeout(saveTimer);
    $('conflict-banner').classList.remove('hidden');
    status('Codex changed the draft · review your pending edits',true);
    return;
  }
  accept({ ...result, structuredContent: data });
};
function applyHostAppearance(context: Partial<McpUiHostContext>) {
  if (context.styles?.variables) applyHostStyleVariables(context.styles.variables);
  const theme = context.theme ?? app.getHostContext()?.theme ?? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  applyDocumentTheme(theme);
  editor.dispatch({ effects: editorAppearance.reconfigure(theme === 'dark' ? oneDark : [syntaxHighlighting(defaultHighlightStyle), EditorView.theme({}, { dark: false })]) });
  const height = context.containerDimensions && 'height' in context.containerDimensions ? context.containerDimensions.height : undefined;
  if (height) document.documentElement.style.setProperty('--host-height', `${height}px`);
  document.documentElement.dataset.displayMode = context.displayMode ?? app.getHostContext()?.displayMode ?? 'inline';
  scaleSlides();
}
app.onhostcontextchanged = applyHostAppearance;
applyHostAppearance({});
refreshIcons();
void app.connect().then(() => applyHostAppearance(app.getHostContext() ?? {})).catch(error => { $('connection-status').textContent = 'Unable to connect to Codex'; showError(error); });

setInterval(() => {
  if (!state || sourceChanged || conflict || desktopPending || document.hidden || $('dialog').open) return;
  void serial(async () => {
    if (!state || sourceChanged) return;
    const result = await call('read_workspace',{workspace_id:state.id,known_revision:state.revision});
    if (sourceChanged) return;
    if (result.structuredContent?.revision !== state.revision) accept(result);
    else if (state.diskAccessRequired !== result.structuredContent?.diskAccessRequired) {
      state.diskAccessRequired = Boolean(result.structuredContent?.diskAccessRequired);
      status();
    }
  }).catch(showError);
},3000);
