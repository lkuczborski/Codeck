import { App } from '@modelcontextprotocol/ext-apps';

declare const CODECK_PLUGIN_VERSION: string;
export const app = new App({ name: 'Codeck', version: CODECK_PLUGIN_VERSION }, { availableDisplayModes: ['inline', 'fullscreen'] }, { autoResize: false });

export async function call(name: string, args: Record<string, unknown> = {}) {
  const result = await app.callServerTool({ name, arguments: args }, { timeout: name.startsWith('choose_') ? 600000 : 30000 });
  if (result.isError) throw new Error(result.content?.filter(item => item.type === 'text').map(item => item.text).join('\n') || 'The operation failed.');
  return { ...result, structuredContent: result.structuredContent && typeof result.structuredContent === 'object'
    ? result.structuredContent as Record<string, unknown> : undefined };
}
