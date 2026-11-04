const test = require('node:test');
const assert = require('node:assert/strict');
const { loadMoment } = require('./harness');

const moment = loadMoment();
const holiday = (iso) => moment(iso, 'YYYY-MM-DD').holiday();

test('names the holidays of 2026', () => {
  const expected = {
    '2026-01-01': "New Year's Day",
    '2026-01-19': 'Martin Luther King Jr. Day',
    '2026-02-16': "Washington's Birthday",
    '2026-04-03': 'Good Friday',
    '2026-04-05': 'Easter',
    '2026-05-25': 'Memorial Day',
    '2026-07-04': 'Independence Day',
    '2026-09-07': 'Labor Day',
    '2026-10-12': 'Columbus Day',
    '2026-11-11': "Veteran's Day",
    '2026-11-26': 'Thanksgiving Day',
    '2026-12-24': 'Christmas Eve',
    '2026-12-25': 'Christmas Day',
    '2026-12-31': "New Year's Eve",
  };
  for (const [iso, name] of Object.entries(expected)) assert.equal(holiday(iso), name, iso);
});

test('ordinary days are not holidays', () => {
  for (const iso of ['2026-11-03', '2026-05-18', '2026-01-12', '2027-03-29']) assert.equal(holiday(iso), undefined, iso);
});

test('Easter and Good Friday move with the year', () => {
  assert.equal(holiday('2025-04-20'), 'Easter');
  assert.equal(holiday('2025-04-18'), 'Good Friday');
  assert.equal(holiday('2027-03-28'), 'Easter');
  assert.equal(holiday('2027-03-26'), 'Good Friday');
});

test('Memorial Day is the last Monday in May, even when May has five Mondays', { todo: 'May 24, 2027 is also labeled Memorial Day' }, () => {
  assert.equal(holiday('2027-05-31'), 'Memorial Day');
  assert.equal(holiday('2027-05-24'), undefined);
});

test('Thanksgiving and the day after follow the fourth Thursday', { todo: 'Nov 28/29 are hardcoded from 2013' }, () => {
  assert.equal(holiday('2026-11-27'), 'Day after Thanksgiving');
  assert.equal(holiday('2026-11-28'), undefined);
  assert.equal(holiday('2026-11-29'), undefined);
  assert.equal(holiday('2025-11-27'), 'Thanksgiving Day');
  assert.equal(holiday('2025-11-28'), 'Day after Thanksgiving');
});
