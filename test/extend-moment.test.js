const test = require('node:test');
const assert = require('node:assert/strict');
const { loadMoment } = require('./harness');

const moment = loadMoment();
const day = (iso) => moment(iso, 'YYYY-MM-DD');
const fmt = (m) => m.format('YYYY-MM-DD ddd');

// Plain day-by-day counting, to check the closed-form math against.
function countWeekdays(start, end) {
  let n = 0;
  for (const d = moment(start); d < end; d.add(1, 'day')) if (d.isoWeekday() < 6) n++;
  return n;
}
function stepWeekdays(start, count) {
  const d = moment(start);
  for (let left = Math.abs(count); left; ) {
    d.add(Math.sign(count), 'day');
    if (d.isoWeekday() < 6) left--;
  }
  return d;
}

test('end.weekDays(start) counts weekdays from start up to, not including, end', () => {
  assert.equal(day('2026-11-03').weekDays(day('2026-11-01')), 1); // Sun, Mon
  assert.equal(day('2026-12-01').weekDays(day('2026-11-01')), 21); // all of Nov 2026
  assert.equal(day('2026-11-09').weekDays(day('2026-11-02')), 5); // Mon..Sun
  assert.equal(day('2026-11-03').weekDays(day('2026-11-03')), 0);
});

test('weekDays matches day-by-day counting for every start date and span in 2026', () => {
  for (const start = day('2026-01-01'); start.year() === 2026; start.add(1, 'day')) {
    for (let span = 0; span <= 45; span++) {
      const end = moment(start).add(span, 'days');
      assert.equal(end.weekDays(start), countWeekdays(start, end), `${fmt(start)} + ${span} days`);
    }
  }
});

test('weekendDays counts Saturdays and Sundays in the same range', () => {
  assert.equal(day('2026-11-09').weekendDays(day('2026-11-02')), 2);
  assert.equal(day('2026-12-01').weekendDays(day('2026-11-01')), 9);
});

test('addWeekDays and subtractWeekDays skip weekends', () => {
  assert.equal(fmt(day('2026-11-06').addWeekDays(1)), '2026-11-09 Mon'); // Fri + 1
  assert.equal(fmt(day('2026-11-07').addWeekDays(1)), '2026-11-09 Mon'); // Sat + 1
  assert.equal(fmt(day('2026-11-02').addWeekDays(5)), '2026-11-09 Mon');
  assert.equal(fmt(day('2026-11-09').subtractWeekDays(1)), '2026-11-06 Fri');
  assert.equal(fmt(day('2026-11-04').addWeekDays(0)), '2026-11-04 Wed');

  for (const start = day('2026-01-01'); start.year() === 2026; start.add(1, 'day')) {
    for (let n = -12; n <= 12; n++) {
      assert.equal(fmt(moment(start).addWeekDays(n)), fmt(stepWeekdays(start, n)), `${fmt(start)} ${n}`);
    }
  }
});

test('isWeekDay and isWeekendDay', () => {
  assert.deepEqual(
    ['2026-11-06', '2026-11-07', '2026-11-08', '2026-11-09'].map((d) => [day(d).isWeekDay(), day(d).isWeekendDay()]),
    [[true, false], [false, true], [false, true], [true, false]],
  );
});
