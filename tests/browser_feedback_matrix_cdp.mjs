/** Chrome file:// matrix: synthetic task inputs, local-only CDP. */
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

const [browser, documentUrl, evidenceDir] = process.argv.slice(2);
if (!browser || !documentUrl?.startsWith('file://') || !evidenceDir)
  throw new Error('expected browser, file:// HTML, and evidence directory');
const profile = mkdtempSync(path.join(tmpdir(), 'plangate-browser-matrix-'));
const flags = ['--headless', '--disable-gpu', '--disable-background-networking',
  '--disable-dev-shm-usage', '--no-first-run', '--no-default-browser-check',
  '--remote-debugging-port=0', '--user-data-dir=' + profile, 'about:blank'];
if (process.getuid?.() === 0 || process.env.PLANGATE_CHROME_NO_SANDBOX === '1')
  flags.splice(1, 0, '--no-sandbox');
const child = spawn(browser, flags, { stdio: ['ignore', 'ignore', 'pipe'] });
let stderr = '';
child.stderr.on('data', data => { stderr = (stderr + data.toString()).slice(-4000); });
let exitInfo;
child.on('exit', (code, signal) => { exitInfo = { code, signal }; });
async function waitFor(check, label, millis = 20000) {
  const end = Date.now() + millis;
  while (Date.now() < end) {
    try { const result = await check(); if (result) return result; }
    catch { /* Chrome may not be ready. */ }
    await delay(90);
  }
  throw new Error('timeout ' + label + ' browser=' + JSON.stringify(exitInfo) +
    ' stderr=' + stderr.slice(-1500));
}
class Devtools {
  constructor(url) {
    assert.match(url, /^ws:\/\/(127\.0\.0\.1|localhost):\d+\//);
    this.socket = new WebSocket(url);
    this.serial = 0;
    this.waiters = new Map();
    this.events = new Map();
    this.socket.addEventListener('message', ({ data }) => {
      const message = JSON.parse(data);
      if (message.id) {
        const waiter = this.waiters.get(message.id);
        if (!waiter) return;
        this.waiters.delete(message.id);
        if (message.error) waiter.reject(new Error(JSON.stringify(message.error)));
        else waiter.resolve(message.result);
      } else if (message.method) {
        for (const fn of this.events.get(message.method) ?? []) fn(message.params);
      }
    });
  }
  async open() {
    await waitFor(() => this.socket.readyState === WebSocket.OPEN, 'CDP socket');
  }
  call(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++this.serial;
      this.waiters.set(id, { resolve, reject });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }
  on(event, listener) {
    this.events.set(event, [...(this.events.get(event) ?? []), listener]);
  }
  close() { this.socket.close(); }
}
let page;
try {
  const port = await waitFor(() => {
    const p = path.join(profile, 'DevToolsActivePort');
    return existsSync(p) ? Number(readFileSync(p, 'utf8').split('\n')[0]) : 0;
  }, 'DevToolsActivePort');
  const origin = 'http://127.0.0.1:' + port;
  const targets = await (await fetch(origin + '/json/list')).json();
  const target = targets.find(t => t.type === 'page');
  assert.ok(target, 'no Chrome page');
  page = new Devtools(target.webSocketDebuggerUrl);
  await page.open();
  await page.call('Page.enable');
  await page.call('Network.enable');
  const attemptedRequests = [];
  page.on('Network.requestWillBeSent', event => {
    if (/^(https?|wss?):/i.test(event.request.url))
      attemptedRequests.push(event.request.url);
  });
  const navigation = await page.call('Page.navigate', { url: documentUrl });
  assert.ok(!navigation.errorText, navigation.errorText);
  await waitFor(async () => {
    const x = await page.call('Runtime.evaluate', {
      expression: 'document.readyState === "complete" && document.querySelectorAll("[data-question-id]").length === 50',
      returnByValue: true,
    });
    return x.result?.value;
  }, '50-question self-contained file document');

  const inspect = async expression => {
    const r = await page.call('Runtime.evaluate', { expression, returnByValue: true });
    if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails));
    return r.result.value;
  };
  const baseline = await inspect([
    '(() => {',
    'const controls = [...document.querySelectorAll("#pg-plan-feedback select, #pg-plan-feedback textarea")];',
    'const issues = controls.filter(el => !el.id ||',
    '![...document.querySelectorAll("label[for]")].some(l => l.htmlFor === el.id && l.textContent.trim()));',
    'const malicious = !!document.querySelector("img[onerror],script[src],iframe,link[rel=stylesheet]") ||',
    '!!window.pwned || !!window.injected || !!window.hacked;',
    'const button = document.querySelector("[data-export]");',
    'return { count: document.querySelectorAll("[data-question-id]").length,',
    'controlCount: controls.length, unlabeled: issues.length,',
    'buttonName: button?.textContent.trim(), buttonType: button?.type,',
    'liveRegion: document.querySelector("[data-message]")?.getAttribute("aria-live"),',
    'malicious, scheme: location.protocol,',
    'labelCount: document.querySelectorAll("#pg-plan-feedback label[for]").length };',
    '})()',
  ].join('\n'));
  assert.equal(baseline.scheme, 'file:');
  assert.equal(baseline.count, 50);
  assert.equal(baseline.controlCount, 150);
  assert.equal(baseline.unlabeled, 0, 'controls need explicit associated labels');
  assert.equal(baseline.labelCount, 150);
  assert.equal(baseline.buttonName, '回答JSONを保存');
  assert.equal(baseline.buttonType, 'button');
  assert.equal(baseline.liveRegion, 'polite');
  assert.equal(baseline.malicious, false, 'user-originated XSS should be inert');

  const ax = await page.call('Accessibility.getFullAXTree');
  assert.ok(ax.nodes.some(n => n.role?.value === 'button' &&
    n.name?.value === '回答JSONを保存'), 'download button missing from AX tree');

  await page.call('Runtime.evaluate', { expression: 'document.querySelector("[data-state]").focus()' });
  const tab = async () => {
    await page.call('Input.dispatchKeyEvent', {
      type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9,
    });
    await page.call('Input.dispatchKeyEvent', {
      type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9,
    });
  };
  for (const attr of ['data-response', 'data-note', 'data-state']) {
    await tab();
    assert.equal(await inspect('document.activeElement?.hasAttribute("' + attr + '")'), true,
      'keyboard Tab expected next ' + attr);
  }
  mkdirSync(evidenceDir, { recursive: true });
  const responsive = [];
  for (const [name, width, height, mobile] of [
    ['desktop', 1280, 800, false], ['mobile', 375, 812, true],
  ]) {
    await page.call('Emulation.setDeviceMetricsOverride', {
      width, height, deviceScaleFactor: 1, mobile,
    });
    const metrics = await inspect([
      '({ viewport: document.documentElement.clientWidth,',
      'scrollWidth: document.documentElement.scrollWidth,',
      'questionCount: document.querySelectorAll("[data-question-id]").length,',
      'exportVisible: getComputedStyle(document.querySelector("[data-export]")).display !== "none" })',
    ].join('\n'));
    assert.equal(metrics.questionCount, 50);
    assert.equal(metrics.exportVisible, true);
    assert.ok(metrics.scrollWidth <= metrics.viewport + 2,
      name + ' horizontal overflow ' + JSON.stringify(metrics));
    const screenshot = await page.call('Page.captureScreenshot', { format: 'png', fromSurface: true });
    writeFileSync(path.join(evidenceDir, name + '-synthetic.png'),
      Buffer.from(screenshot.data, 'base64'));
    responsive.push({ name, ...metrics });
  }
  await page.call('Emulation.setEmulatedMedia', { media: 'print' });
  assert.equal(await inspect('getComputedStyle(document.querySelector("[data-export]")).display'),
    'none', 'download button must not print');
  await page.call('Emulation.setEmulatedMedia', { media: 'screen' });
  await delay(200);
  assert.deepEqual(attemptedRequests, [], 'offline HTML made a network request');

  const result = {
    sourceIsLocalFile: true, browserAXButton: true,
    keyboardTabThroughThreeControls: true,
    attemptedNetworkRequests: attemptedRequests, printButtonHidden: true,
    ...baseline, responsive,
    screenshots: ['desktop-synthetic.png', 'mobile-synthetic.png'],
  };
  writeFileSync(path.join(evidenceDir, 'matrix-results.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ passed: true, ...result }));
} finally {
  page?.close();
  child.kill('SIGTERM');
  await Promise.race([new Promise(resolve => child.once('exit', resolve)), delay(1000)]);
  try { rmSync(profile, { recursive: true, force: true, maxRetries: 6, retryDelay: 120 }); }
  catch { /* Ephemeral runner profile; do not mask assertions. */ }
}
