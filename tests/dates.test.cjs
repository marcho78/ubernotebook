// Checks dates typed after "@" in Pages, and how they're written down.
// Usage (from the plugin directory): node tests/dates.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Dates = load("Dates.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

// Wednesday 30 September 2026, 14:20.
const now = new Date(2026, 8, 30, 14, 20);
function read(text) {
  const d = Dates.parse(text, now);
  return d ? Dates.iso(d.at, d.time) : null;
}

check("days", () => {
  assert.equal(read("today"), "2026-09-30");
  assert.equal(read("tomorrow"), "2026-10-01");
  assert.equal(read("yesterday"), "2026-09-29");
  assert.equal(read("fri"), "2026-10-02");
  assert.equal(read("wednesday"), "2026-09-30", "a weekday can mean today");
  assert.equal(read("wednesday 3pm"), "2026-09-30T15:00", "today when its time is still to come");
  assert.equal(read("wednesday 1pm"), "2026-10-07T13:00", "next week when its time has gone by");
  assert.equal(read("next monday"), "2026-10-05");
  assert.equal(read("next wednesday"), "2026-10-07");
  assert.equal(read("this wednesday 1pm"), "2026-09-30T13:00", "this Wednesday stays today");
  assert.equal(read("this friday"), "2026-10-02");
  assert.equal(read("next week"), "2026-10-05", "next week starts on Monday");
  assert.equal(read("next month"), "2026-10-01");
  assert.equal(read("in 3 days"), "2026-10-03");
  assert.equal(read("in 2 weeks"), "2026-10-14");
  const names = ["sunday", "sun", "monday", "mon", "tuesday", "tue", "tues", "wednesday", "wed", "weds",
    "thursday", "thu", "thur", "thurs", "friday", "fri", "saturday", "sat"];
  for (const name of names) assert.notEqual(Dates.dayIndex(name), -1, name);
  for (const name of ["Frida", "Mona", "Sunny", "Wedge"]) assert.equal(Dates.dayIndex(name), -1, name + " stays a name");
  assert.equal(read("tom 3pm"), null, "Tom stays a name");
  assert.equal(read("tmrw 3pm"), "2026-10-01T15:00", "tmrw is tomorrow");
});

check("dates", () => {
  assert.equal(read("oct 3"), "2026-10-03");
  assert.equal(read("3 october"), "2026-10-03");
  assert.equal(read("October 3rd"), "2026-10-03");
  assert.equal(read("sep 1"), "2027-09-01", "a date gone by this year is next year's");
  assert.equal(read("march 5 2028"), "2028-03-05");
  assert.equal(read("2026-12-24"), "2026-12-24");
  assert.equal(read("feb 30"), null);
  assert.equal(read("2026-02-30"), null);
});

check("times", () => {
  Dates.setTwelveHour(true);
  assert.equal(Dates.parseTime("1"), 13 * 60, "a bare early hour is in the afternoon");
  assert.equal(Dates.parseTime("6"), 18 * 60);
  assert.equal(Dates.parseTime("7"), 7 * 60);
  assert.equal(Dates.parseTime("12"), 12 * 60);
  assert.equal(Dates.parseTime("01"), 1 * 60, "a leading zero says 24-hour time");
  assert.equal(Dates.parseTime("06:30"), 6 * 60 + 30);
  assert.equal(Dates.parseTime("13:00"), 13 * 60);
  assert.equal(Dates.parseTime("3:30"), 15 * 60 + 30, "minutes follow a 12-hour clock");
  Dates.setTwelveHour(false);
  assert.equal(Dates.parseTime("3:30"), 3 * 60 + 30, "minutes follow a 24-hour clock when selected");
  Dates.setTwelveHour(true);
  assert.equal(read("tomorrow 9am"), "2026-10-01T09:00");
  assert.equal(read("tomorrow at 9:30pm"), "2026-10-01T21:30");
  assert.equal(read("fri noon"), "2026-10-02T12:00");
  assert.equal(read("oct 3 18:45"), "2026-10-03T18:45");
  assert.equal(read("tonight"), "2026-09-30T20:00");
  assert.equal(read("5pm"), "2026-09-30T17:00", "a time alone is today's");
  assert.equal(read("9am"), "2026-10-01T09:00", "or tomorrow's once it's gone by");
  assert.equal(read("in 2 hours"), "2026-09-30T16:20");
  assert.equal(read("in 30 min"), "2026-09-30T14:50");
  assert.equal(read("tomorrow 25:00"), null);
  assert.equal(read("tomorrow 13pm"), null);
  for (const nope of ["", "banana", "in five days", "next banana", "tomorrow banana"]) assert.equal(read(nope), null, nope);
});

check("written on the page, and in links", () => {
  assert.equal(Dates.label(new Date(2026, 9, 1), false, now), "Thu 1 Oct");
  assert.equal(Dates.label(new Date(2026, 9, 1, 9, 5), true, now), "Thu 1 Oct 9:05");
  assert.equal(Dates.label(new Date(2027, 0, 4), false, now), "Mon 4 Jan 2027", "another year says so");
  assert.equal(Dates.href(new Date(2026, 9, 1, 9, 30), true, true), "uber-notebook://remind/2026-10-01T09:30");
  const back = plain(Dates.fromHref("uber-notebook://date/2026-10-01"));
  assert.equal(back.remind, false);
  assert.equal(back.time, false);
  assert.equal(Dates.fromHref("uber-notebook://remind/2026-13-01T09:00"), null);
  assert.equal(Dates.fromHref("https://example.com"), null);
  const r = Dates.remindAt(new Date(2026, 9, 1), false);
  assert.equal(Dates.iso(r, true), "2026-10-01T09:00", "a reminder on a day comes at 9 in the morning");
});

check("the @ menu", () => {
  const first = plain(Dates.suggestions("", now));
  assert.equal(first[0].label, "Wed 30 Sep");
  assert.equal(first[1].label, "Thu 1 Oct");
  assert.ok(first.some((s) => s.remind), "and reminders");
  const typed = plain(Dates.suggestions("fri 3pm", now));
  assert.deepEqual(typed.map((s) => s.label), ["Fri 2 Oct 15:00", "Remind me Fri 2 Oct 15:00"]);
  assert.equal(typed[1].remind, true);
  assert.deepEqual(plain(Dates.suggestions("banana", now)), []);
});

console.log(`dates: ${passed} checks passed`);
