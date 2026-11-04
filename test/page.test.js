const test = require('node:test');
const assert = require('node:assert/strict');
const { loadPage, createWindow, read } = require('./harness');

const SETTINGS = { earnings: '8000', wage: '50', userId: '111', workspaceId: '222', apiKey: 'dG9rZW46YXBpX3Rva2Vu' };
// $8000 at $50/h is a 160-hour month. November 2026 has 21 weekdays, December 23.
const at = (y, m, d, h = 10) => new Date(y, m - 1, d, h, 0);
const open = (opts) => loadPage({ storage: SETTINGS, ...opts });
const shown = (page, name) => page.text(`.display.${name}-display, .${name}-display`);
const numbers = (page) => Object.fromEntries(
  ['target-today', 'clock-out', 'target-avg-today', 'target-avg', 'current-avg', 'total-hours', 'target-hours', 'vacation-days']
    .map((name) => [name, shown(page, name)]),
);

// Tue Nov 3: 8h on Mon Nov 2, 2h so far today. 20 weekdays left including today.
const NOV_3 = { now: at(2026, 11, 3), toggl: { totalHours: 10, todayHours: 2 } };

test('shows the day\'s targets from the month\'s logged hours', () => {
  const page = open(NOV_3);
  const { 'current-avg': _, ...rest } = numbers(page);
  assert.deepEqual(rest, {
    'target-today': '5.6', // 7.6 - 2 logged today
    'clock-out': '3:36pm', // 10:00am + 5.6h
    'target-avg-today': '7.6', // (160 - 8) / 20
    'target-avg': '7.9', // (160 - 10) / 19
    'total-hours': '10',
    'target-hours': '160',
    'vacation-days': '0',
  });
  assert.equal(page.window.document.title, '(5.6) Toggl Time Tracker');
});

test('Current AVG is hours before today divided by weekdays before today', { todo: 'weekDays() is called with its arguments reversed' }, () => {
  assert.equal(shown(open(NOV_3), 'current-avg'), '8'); // 8h over 1 weekday
});

test('asks Toggl for this month and for today, with the saved credentials', () => {
  const page = open(NOV_3);
  const [details, summary] = page.requests;
  assert.equal(page.requests.length, 2);
  assert.match(details.url, /^https:\/\/toggl\.com\/reports\/api\/v2\/details\?/);
  assert.match(details.url, /&user_ids=111&.*&since=2026-11-01&until=2026-11-30&workspace_id=222&/);
  assert.match(summary.url, /^https:\/\/toggl\.com\/reports\/api\/v2\/summary\.json\?/);
  assert.match(summary.url, /&user_ids=111&.*&workspace_id=222&.*&since=2026-11-03&until=2026-11-03&/);
  assert.deepEqual(summary.headers, { Authorization: 'Basic dG9rZW46YXBpX3Rva2Vu', 'X-Requested-With': 'XMLHttpRequest' });
});

test('first visit prompts for each setting and saves the answers', () => {
  const page = loadPage({ ...NOV_3, answers: ['8000', '50', 'dG9rZW46YXBpX3Rva2Vu', '222', '111'] });
  assert.deepEqual(page.prompts, [
    'Enter your target earnings',
    'Enter your hourly wage',
    'Enter your toggl auth token',
    'Enter your toggl workspaceId',
    'Enter your toggl userId',
  ]);
  assert.deepEqual(page.storage(), SETTINGS);
  assert.equal(shown(page, 'target-today'), '5.6');
});

test('a share link fills in the settings, then reloads without the query string', () => {
  const page = loadPage({ ...NOV_3, query: '?e=9000&w=60&u=5&s=6&a=abc' });
  assert.deepEqual(page.prompts, []);
  assert.deepEqual(page.storage(), { earnings: '9000', wage: '60', userId: '5', workspaceId: '6', apiKey: 'abc' });
  assert.equal(shown(page, 'target-hours'), '150');
  assert.match(page.errors.join('\n'), /navigation/); // jsdom's note that the page tried to navigate
});

test('Copy Share Url builds a link with every setting, including the auth token', () => {
  const page = open(NOV_3);
  const button = page.$('.menu .btn-link').trigger('mousedown');
  assert.equal(
    button.attr('data-clipboard-text'),
    'https://www.kevnk.com/toggl-time-tracker/?e=8000&w=50&u=111&s=222&a=dG9rZW46YXBpX3Rva2Vu',
  );
});

test('a failed Toggl request shows an error and a link to reset/', () => {
  const page = open({ now: at(2026, 11, 3), toggl: null });
  assert.equal(page.$('.error .label-danger').text(), 'Error! Wrong credentials!');
  assert.equal(page.$('.error a').attr('href'), 'reset/');
});

test('reset/ clears the saved settings', () => {
  const { window } = createWindow({ url: 'https://www.kevnk.com/toggl-time-tracker/reset/' });
  Object.entries(SETTINGS).forEach(([k, v]) => window.localStorage.setItem(k, v));
  window.eval(read('reset/index.html').match(/<script>([\s\S]*?)<\/script>/)[1]);
  assert.equal(window.localStorage.length, 0);
});

test('lists this month\'s weekday holidays as vacation checkboxes', () => {
  const page = open(NOV_3);
  const labels = Array.from(page.$('#holidays form label'), (el) => el.textContent.trim().replace(/\s+/g, ' '));
  assert.deepEqual(labels, [
    "Veteran's Day Wed, Nov 11th",
    'Thanksgiving Day Thu, Nov 26th',
    'Day after Thanksgiving Fri, Nov 27th',
  ]);
});

test('checking an upcoming holiday spreads the target over one fewer day', () => {
  const page = open(NOV_3);
  page.$('#holidays input[data-name="Thanksgiving Day"]').prop('checked', true).trigger('change');
  assert.equal(page.storage().vacations, 'Thanksgiving Day');
  assert.equal(shown(page, 'vacation-days'), '1');
  assert.equal(shown(page, 'target-avg-today'), '8'); // 152 / 19
  assert.equal(shown(page, 'target-today'), '6');
  assert.equal(shown(page, 'target-avg'), '8.3'); // 150 / 18
});

test('+ Vacation Day adds a day off and - Vacation Day takes it back', () => {
  const page = open(NOV_3);
  const minus = page.$('#minus_vacation_day');
  assert.ok(minus.hasClass('hide'));

  page.$('#plus_vacation_day').trigger('click');
  assert.equal(page.storage().vacations, '20261103100000');
  assert.equal(shown(page, 'vacation-days'), '1');
  assert.equal(shown(page, 'target-avg-today'), '8');
  assert.ok(!minus.hasClass('hide'));

  minus.trigger('click');
  assert.equal(page.storage().vacations, '');
  assert.equal(shown(page, 'vacation-days'), '0');
  assert.equal(shown(page, 'target-avg-today'), '7.6');
});

// Wed Nov 11 is Veteran's Day. 56h logged over the 7 weekdays before it.
test('a vacation day already taken is not counted as a day left', { todo: 'past vacation days are added back to days left' }, () => {
  const page = open({ now: at(2026, 11, 12), storage: { ...SETTINGS, vacations: "Veteran's Day" }, toggl: { totalHours: 56, todayHours: 0 } });
  assert.equal(shown(page, 'current-avg'), '8'); // 56 / 7
  assert.equal(shown(page, 'target-avg-today'), '8'); // 104 / 13
  assert.equal(shown(page, 'target-avg'), '8.7'); // 104 / 12
});

test('on a vacation day, today is neither a day worked nor a day left', { todo: 'today\'s vacation is subtracted from days already worked' }, () => {
  const page = open({ now: at(2026, 11, 11), storage: { ...SETTINGS, vacations: "Veteran's Day" }, toggl: { totalHours: 56, todayHours: 0 } });
  assert.equal(shown(page, 'current-avg'), '8'); // 56 / 7
  assert.equal(shown(page, 'target-avg-today'), '8'); // 104 / 13
  assert.equal(shown(page, 'target-avg'), '8'); // 104 / 13
});

test('a holiday checked last month is not a vacation day this month', { todo: 'stale holiday names count as manual vacation days' }, () => {
  const page = open({ now: at(2026, 12, 3), storage: { ...SETTINGS, vacations: 'Thanksgiving Day' }, toggl: { totalHours: 16, todayHours: 0 } });
  assert.equal(shown(page, 'vacation-days'), '0');
  assert.equal(shown(page, 'target-avg-today'), '6.9'); // 144 / 21
});

test('on the first of the month, Current AVG is today\'s hours', () => {
  const page = open({ now: at(2026, 12, 1), toggl: { totalHours: 3, todayHours: 3 } });
  assert.equal(shown(page, 'current-avg'), '3');
  assert.equal(shown(page, 'target-avg'), '7.1'); // 157 / 22
});

test('on the first of the month, today\'s target counts today\'s hours once', { todo: 'first-of-month branch subtracts today\'s hours twice' }, () => {
  const page = open({ now: at(2026, 12, 1), toggl: { totalHours: 3, todayHours: 3 } });
  assert.equal(shown(page, 'target-avg-today'), '7'); // 160 / 23
  assert.equal(shown(page, 'target-today'), '4');
});

test('on the last day of the month, today\'s target covers what is left', () => {
  const page = open({ now: at(2026, 11, 30), toggl: { totalHours: 150, todayHours: 8 } });
  assert.equal(shown(page, 'target-avg-today'), '18'); // 160 - 142
  assert.equal(shown(page, 'target-today'), '10');
});

test('on the last day of the month, Target Tomorrow spreads next month over all its weekdays', { todo: 'divides by next month\'s weekdays minus one' }, () => {
  const page = open({ now: at(2026, 11, 30), toggl: { totalHours: 150, todayHours: 8 } });
  assert.equal(shown(page, 'target-avg'), '7'); // 160 / 23
});
