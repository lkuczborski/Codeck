import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';

export class MCPClient {
  constructor(executable, { cwd, env = {}, args = [] } = {}) {
    this.child = spawn(executable, args, { cwd, env: { ...process.env, ...env }, stdio: ['pipe', 'pipe', 'inherit'] });
    this.pending = new Map();
    this.sequence = 0;
    const lines = createInterface({ input: this.child.stdout });
    lines.on('line', line => {
      let response;
      try { response = JSON.parse(line); } catch { return; }
      const pending = this.pending.get(response.id);
      if (!pending) return;
      this.pending.delete(response.id);
      clearTimeout(pending.timeout);
      if (response.error) pending.reject(new Error(response.error.message));
      else pending.resolve(response.result);
    });
    const fail = error => { for (const pending of this.pending.values()) { clearTimeout(pending.timeout); pending.reject(error); } this.pending.clear(); };
    this.child.on('error', fail);
    this.child.on('exit', code => fail(new Error(`MCP server exited (${code}).`)));
  }
  request(method, params = {}) {
    const id = ++this.sequence;
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => { this.pending.delete(id); reject(new Error(`MCP request timed out: ${method}`)); }, params.name?.startsWith('choose_') ? 600000 : 30000);
      this.pending.set(id, { resolve, reject, timeout });
      this.child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
    });
  }
  async initialize() {
    const result = await this.request('initialize', { protocolVersion: '2025-11-25', clientInfo: { name: 'codeck-preview', version: '0.1.0' }, capabilities: {} });
    this.child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
    return result;
  }
  close() { this.child.stdin.end(); }
}
