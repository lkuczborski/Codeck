import { readFile } from 'node:fs/promises';

export async function packageVersion(buildNumber = process.env.CODECK_PLUGIN_BUILD_NUMBER) {
  const manifest = JSON.parse(await readFile(new URL('../.codex-plugin/plugin.json', import.meta.url), 'utf8'));
  if (buildNumber === undefined) return manifest.version;
  if (!/^[1-9][0-9]*$/.test(String(buildNumber))) throw new Error('CODECK_PLUGIN_BUILD_NUMBER must be a positive integer.');
  return `${manifest.version}-build.${buildNumber}`;
}
