import test from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, mkdir, readFile, writeFile, rm, chmod, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { packageVersion } from '../scripts/package-version.mjs';

const run = promisify(execFile);
const publisher = fileURLToPath(new URL('../../../script/publish_plugin.sh', import.meta.url));

test('CI package versions distinguish builds without changing source metadata', async () => {
  const source = JSON.parse(await readFile(new URL('../.codex-plugin/plugin.json', import.meta.url), 'utf8'));
  assert.equal(await packageVersion('12'), `${source.version}-build.12`);
  assert.equal(await packageVersion('13'), `${source.version}-build.13`);
  assert.equal(await packageVersion(undefined), process.env.CODECK_PLUGIN_BUILD_NUMBER ?
    `${source.version}-build.${process.env.CODECK_PLUGIN_BUILD_NUMBER}` : source.version);
  for (const invalid of ['', '0', '1/2', '-1', '1; command']) {
    await assert.rejects(packageVersion(invalid), /positive integer/);
  }
  assert.equal(JSON.parse(await readFile(new URL('../.codex-plugin/plugin.json', import.meta.url), 'utf8')).version, source.version);
});

test('publication bootstraps a separate branch, removes stale package files, and rejects stale source runs', async t => {
  const directory = await mkdtemp(path.join(tmpdir(), 'codeck-release-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const remote = path.join(directory, 'remote.git');
  const source = path.join(directory, 'source');
  const pack = path.join(directory, 'package');
  const git = (args, cwd = source) => run('git', args, { cwd, env: { ...process.env, GH_TOKEN: '' } });
  await run('git', ['init', '--bare', '-q', remote]);
  await run('git', ['init', '-q', '-b', 'main', source]);
  await git(['config', 'user.name', 'Codeck release test']);
  await git(['config', 'user.email', 'test@example.invalid']);
  await writeFile(path.join(source, 'source.txt'), 'Source must remain on main.\n');
  await git(['add', '.']);
  await git(['commit', '-q', '-m', 'Source']);
  await git(['remote', 'add', 'origin', remote]);
  await git(['push', '-q', 'origin', 'main']);
  const sha = (await git(['rev-parse', 'HEAD'])).stdout.trim();
  await mkdir(path.join(pack, 'codeck-plugin/scripts'), { recursive: true });
  await mkdir(path.join(pack, '.agents/plugins'), { recursive: true });
  await writeFile(path.join(pack, 'codeck-plugin/scripts/run-server.sh'), '#!/bin/bash\nexit 0\n');
  await chmod(path.join(pack, 'codeck-plugin/scripts/run-server.sh'), 0o755);
  await writeFile(path.join(pack, 'codeck-plugin/obsolete.txt'), 'old package file');
  await writeFile(path.join(pack, '.agents/plugins/marketplace.json'), JSON.stringify({
    name: 'codeck-local', interface: { displayName: 'Codeck Local' },
    plugins: [{ name: 'codeck', source: { source: 'local', path: './codeck-plugin' } }],
  }));
  const publish = commit => run('bash', [publisher, pack, remote, commit], { env: { ...process.env, GH_TOKEN: '' } });
  await publish(sha);
  const tip = async () => (await git(['ls-remote', 'origin', 'refs/heads/codex/plugin-distribution'])).stdout.trim().split(/\s/)[0];
  const first = await tip();
  assert.equal((await git(['show', 'main:source.txt'])).stdout, 'Source must remain on main.\n');
  const installed = path.join(directory, 'installed');
  await run('git', ['clone', '-q', '--branch', 'codex/plugin-distribution', remote, installed]);
  const catalog = JSON.parse(await readFile(path.join(installed, '.agents/plugins/marketplace.json'), 'utf8'));
  assert.equal(catalog.name, 'codeck-plugins');
  assert.equal(catalog.plugins[0].source.path, './codeck-plugin');
  assert.ok((await stat(path.join(installed, 'codeck-plugin/scripts/run-server.sh'))).mode & 0o111);
  await assert.rejects(readFile(path.join(installed, 'source.txt')), { code: 'ENOENT' });
  await publish(sha);
  assert.equal(await tip(), first, 'identical packages do not create duplicate commits');
  await rm(path.join(pack, 'codeck-plugin/obsolete.txt'));
  await writeFile(path.join(source, 'source.txt'), 'Updated source\n');
  await git(['add', '.']);
  await git(['commit', '-q', '-m', 'Update']);
  await git(['push', '-q', 'origin', 'main']);
  const nextSHA = (await git(['rev-parse', 'HEAD'])).stdout.trim();
  assert.match((await publish(sha)).stdout, /Skipping publication/);
  assert.equal(await tip(), first);
  await publish(nextSHA);
  assert.notEqual(await tip(), first);
  await git(['pull', '-q', '--ff-only'], installed);
  await assert.rejects(readFile(path.join(installed, 'codeck-plugin/obsolete.txt')), { code: 'ENOENT' });
  assert.equal((await readFile(path.join(installed, 'SOURCE_COMMIT'), 'utf8')).trim(), nextSHA);
});
