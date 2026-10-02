import { build } from 'esbuild';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { packageVersion } from './package-version.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'build');
await mkdir(output, { recursive: true });
await build({ entryPoints: [path.join(root, 'web/main.ts')], bundle: true, format: 'iife', target: 'es2022', minify: true,
  outfile: path.join(output, 'workspace.js'), legalComments: 'external',
  define: { CODECK_PLUGIN_VERSION: JSON.stringify(await packageVersion()) } });
const [template, script, style] = await Promise.all(['web/index.html','build/workspace.js','build/workspace.css'].map(file => readFile(path.join(root,file),'utf8')));
const html = template.replace('</head>', () => `<style>${style}</style></head>`).replace('</body>', () => `<script>${script.replace(/<\/script/gi,'<\\/script')}</script></body>`);
await writeFile(path.join(output, 'workspace.html'), html);
console.log(`Built self-contained workspace (${Math.round(Buffer.byteLength(html) / 1024)} KiB).`);
