import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { packageVersion } from '../plugins/codeck/scripts/package-version.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.join(root, 'plugins/codeck');
const destination = path.join(root, 'dist/codeck-plugin');
const manifest = JSON.parse(await readFile(path.join(source, '.codex-plugin/plugin.json'), 'utf8'));
manifest.version = await packageVersion();
await rm(destination, { recursive: true, force: true });
await mkdir(path.join(destination, '.codex-plugin'), { recursive: true });
await writeFile(path.join(destination, '.codex-plugin/plugin.json'), JSON.stringify(manifest, null, 2) + '\n');
for (const file of ['.mcp.json', 'README.md', 'scripts/run-server.sh', 'assets', 'skills',
  'build/codeck-mcp', 'build/workspace.html', 'build/workspace.js.LEGAL.txt', 'build/Codeck Workspace.app']) {
  const target = path.join(destination, file);
  await mkdir(path.dirname(target), { recursive: true });
  await cp(path.join(source, file), target, { recursive: true });
}
await cp(path.join(root, 'LICENSE'), path.join(destination, 'LICENSE'));
const marketplace = {
  name: 'codeck-local', interface: { displayName: 'Codeck Local' },
  plugins: [{ name: 'codeck', source: { source: 'local', path: './codeck-plugin' },
    policy: { installation: 'AVAILABLE', authentication: 'ON_INSTALL' }, category: 'Productivity' }],
};
const catalog = path.join(root, 'dist/.agents/plugins');
await mkdir(catalog, { recursive: true });
await writeFile(path.join(catalog, 'marketplace.json'), JSON.stringify(marketplace, null, 2) + '\n');
console.log(`Staged Codeck ${manifest.version} at ${destination}`);
