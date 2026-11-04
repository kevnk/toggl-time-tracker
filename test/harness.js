// Loads the real index.html and its scripts in jsdom with a fixed clock and a
// fake Toggl API. Nothing here reaches the network: jsdom fetches no
// subresources, XMLHttpRequest is removed, and $.ajax is replaced before
// main.js runs.
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM, VirtualConsole } = require('jsdom');

const ROOT = path.join(__dirname, '..');
const URL = 'https://www.kevnk.com/toggl-time-tracker/';
const read = (file) => fs.readFileSync(path.join(ROOT, file), 'utf8');
const INDEX = read('index.html');
const PAGE_SCRIPTS = [...INDEX.matchAll(/^\s*<script src="([^"]+)"/gm)].map((m) => m[1]);
const MOMENT_SCRIPTS = PAGE_SCRIPTS.filter((src) => /moment|extend-moment/.test(src));

function createWindow({ html = '', url = URL, now, query = '' }) {
  const errors = [];
  const virtualConsole = new VirtualConsole();
  virtualConsole.on('jsdomError', (e) => errors.push(e.message));
  const { window } = new JSDOM(html, { url: url + query, runScripts: 'outside-only', virtualConsole });
  window.XMLHttpRequest = undefined;
  if (now) {
    window.eval(`Date = class extends Date {
      constructor(...a) { super(...(a.length ? a : [${now.getTime()}])); }
      static now() { return ${now.getTime()}; }
    };`);
  }
  return { window, errors };
}

const run = (window, src) => window.eval(`${read(src)}\n//# sourceURL=${src}`);

// A window with moment and the repo's moment plugins, for unit tests.
function loadMoment(now) {
  const { window } = createWindow({ now });
  MOMENT_SCRIPTS.forEach((src) => run(window, src));
  return window.moment;
}

// The full page. `toggl` is { totalHours, todayHours } or null for a failed request.
function loadPage({ now, storage = {}, query = '', answers = [], toggl = null }) {
  const { window, errors } = createWindow({ html: INDEX, now, query });
  Object.entries(storage).forEach(([k, v]) => window.localStorage.setItem(k, v));
  const prompts = [];
  window.prompt = (question) => {
    prompts.push(question);
    return answers.length ? answers.shift() : null;
  };
  window.ZeroClipboard = function () { this.on = () => {}; };

  const requests = [];
  for (const src of PAGE_SCRIPTS) {
    if (src.includes('zeroclipboard')) continue;
    run(window, src);
    if (window.jQuery && !requests.stubbed) {
      requests.stubbed = true;
      window.jQuery.fx.off = true;
      window.jQuery.ajax = (opts) => {
        const headers = {};
        opts.beforeSend({ setRequestHeader: (k, v) => { headers[k] = v; } });
        requests.push({ url: opts.url, headers });
        const deferred = window.jQuery.Deferred();
        if (!toggl) return deferred.reject().promise();
        const hours = opts.url.includes('summary.json') ? toggl.todayHours : toggl.totalHours;
        const body = { total_grand: hours * 60 * 60 * 1000 };
        opts.success(body);
        return deferred.resolve(body).promise();
      };
    }
  }

  const $ = window.jQuery;
  return {
    window,
    $,
    errors,
    prompts,
    requests,
    text: (selector) => $(selector).first().text(),
    storage: () => ({ ...window.localStorage }),
  };
}

module.exports = { createWindow, loadMoment, loadPage, read };
