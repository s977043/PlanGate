import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

// Local Chrome DevTools protocol only: no external browser-testing dependency.
const [browser, htmlPath, downloads] = process.argv.slice(2);
if (!browser || !htmlPath || !downloads) throw new Error('browser, HTML and downloads path required');
const profile = mkdtempSync(path.join(tmpdir(), 'plangate-cdp-'));
const args = ['--headless', '--disable-gpu', '--disable-dev-shm-usage',
  '--disable-background-networking', '--no-first-run',
  '--remote-debugging-port=0', '--user-data-dir=' + profile, 'about:blank'];
if (process.getuid?.() === 0 || process.env.PLANGATE_CHROME_NO_SANDBOX === '1') {
  args.splice(1, 0, '--no-sandbox');
}
const processChrome = spawn(browser, args, { stdio: ['ignore', 'ignore', 'pipe'] });
let chromeStderr = '';
let chromeExit = null;
processChrome.stderr.on('data', chunk => {
  chromeStderr = (chromeStderr + String(chunk)).slice(-4000);
});
processChrome.on('exit', (code, signal) => { chromeExit = { code, signal }; });
async function waitUntil(fn, label, timeout = 20000) {
  const until = Date.now() + timeout;
  while (Date.now() < until) {
    try {
      const result = await fn();
      if (result) return result;
    } catch { /* not ready */ }
    await sleep(80);
  }
  throw new Error('timeout: ' + label + ' chromeExit=' + JSON.stringify(chromeExit) +
    ' chromiumStderr=' + chromeStderr.slice(-2500));
}
class Cdp {
  constructor(url) {
    assert.match(url, /^ws:\/\/(127\.0\.0\.1|localhost):\d+\//);
    this.ws = new WebSocket(url);
    this.id = 0;
    this.pending = new Map();
    this.ws.addEventListener('message', ({ data }) => {
      const msg = JSON.parse(data);
      const pending = this.pending.get(msg.id);
      if (!pending) return;
      this.pending.delete(msg.id);
      if (msg.error) pending.reject(new Error(JSON.stringify(msg.error)));
      else pending.resolve(msg.result);
    });
  }
  async open() { await waitUntil(() => this.ws.readyState === WebSocket.OPEN, 'CDP open'); }
  call(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++this.id;
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  close() { this.ws.close(); }
}
let controller, page;
try {
  const port = await waitUntil(() => {
    const f = path.join(profile, 'DevToolsActivePort');
    return existsSync(f) ? Number(readFileSync(f, 'utf8').split('\n')[0]) : 0;
  }, 'CDP port');
  const endpoint = 'http://127.0.0.1:' + port;
  const version = await (await fetch(endpoint + '/json/version')).json();
  const pages = await (await fetch(endpoint + '/json/list')).json();
  const target = pages.find(x => x.type === 'page');
  assert.ok(target, 'missing page');
  controller = new Cdp(version.webSocketDebuggerUrl);
  page = new Cdp(target.webSocketDebuggerUrl);
  await Promise.all([controller.open(), page.open()]);
  await controller.call('Browser.setDownloadBehavior', {
    behavior: 'allow', downloadPath: downloads, eventsEnabled: true,
  });
  const tree = await page.call('Page.getFrameTree');
  // Prevent runner URL policies from blocking file:// or loopback navigation.
  await page.call('Page.setDocumentContent', {
    frameId: tree.frameTree.frame.id,
    html: readFileSync(htmlPath, 'utf8'),
  });
  await waitUntil(async () => {
    const r = await page.call('Runtime.evaluate', {
      expression: 'document.querySelectorAll("[data-question-id]").length >= 2',
      returnByValue: true,
    });
    return r.result?.value;
  }, 'question DOM');
  await page.call('Runtime.evaluate', {
    expression: 'document.querySelector("[data-state]").focus()',
  });
  await page.call('Input.dispatchKeyEvent', {
    type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9,
  });
  await page.call('Input.dispatchKeyEvent', {
    type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9,
  });
  const focus = await page.call('Runtime.evaluate', {
    expression: 'document.activeElement?.hasAttribute("data-response")',
    returnByValue: true,
  });
  assert.equal(focus.result?.value, true, 'Tab focus order');
  const expression = [
    '(() => {',
    ' const rows = document.querySelectorAll("[data-question-id]");',
    ' rows[0].querySelector("[data-state]").value = "answered";',
    ' rows[0].querySelector("[data-response]").value = "Canary";',
    ' rows[1].querySelector("[data-state]").value = "deferred";',
    ' rows[1].querySelector("[data-note]").value = "Need evidence";',
    ' document.querySelector("[data-export]").click();',
    '})()',
  ].join('\n');
  await page.call('Runtime.evaluate', { expression });
  const filename = 'TASK-0001-review-feedback.json';
  const filepath = path.join(downloads, filename);
  const result = await waitUntil(() => {
    if (!existsSync(filepath)) return null;
    try { return JSON.parse(readFileSync(filepath, 'utf8')); }
    catch { return null; }
  }, 'JSON saved on disk');
  assert.equal(result.kind, 'plan-review-feedback');
  assert.equal(result.feedback_only, true);
  assert.equal(result.approval_granted, false);
  assert.equal(result.answers[0].response, 'Canary');
  assert.equal(result.answers[1].status, 'deferred');
  assert.equal(result.answers[1].note, 'Need evidence');
  assert.match(result.source.plan.sha256, /^[0-9a-f]{64}$/);
  assert.match(result.source.questions.sha256, /^[0-9a-f]{64}$/);
  console.log(JSON.stringify({ persisted: true, tabFocus: true,
    filename, approval_granted: false }));
} finally {
  page?.close();
  controller?.close();
  processChrome.kill('SIGTERM');
  await Promise.race([
    new Promise(resolve => processChrome.once('exit', resolve)),
    sleep(1200),
  ]);
  try { rmSync(profile, { recursive: true, force: true, maxRetries: 6, retryDelay: 120 }); }
  catch { /* temporary runner profile; do not hide test results */ }
}
