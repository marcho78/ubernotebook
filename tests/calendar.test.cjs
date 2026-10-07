// Checks the calendar in Pages: what's kept, repeats (and their odd days),
// what happens between two moments, events side by side, what's typed read
// as an event, one time of a repeat changed, alerts, and .ics.
// Usage (from the plugin directory): node tests/calendar.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const C = load("Calendar.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const D = (y, m, d, h, min) => new Date(y, m - 1, d, h || 0, min || 0);
const ev = (o) => C.cleanEvent(Object.assign({ title: "E", start: "2026-10-05T09:00", end: "2026-10-05T10:00" }, o));
const days = (cal, from, to) => plain(C.occurrences(cal, from, to)).map((o) => o.day);

check("what's kept", () => {
  assert.deepEqual(plain(C.make()), { version: 1, events: [] });
  assert.deepEqual(plain(C.clean(null)), { version: 1, events: [] });
  const e = plain(C.cleanEvent({ title: " Standup\n", start: "2026-10-05T09:30", end: "2026-10-05T09:00", repeat: { freq: "weekly", every: 0, until: "nope" },
    skip: ["2026-10-12", "bad", "2026-10-12"], color: "#FF8800", alert: 7, page: "x", place: "Room 4", detail: "a\r\nb" }));
  assert.equal(e.title, "Standup");
  assert.equal(e.end, "2026-10-05T10:30", "an end before the start: an hour long");
  assert.deepEqual(e.repeat, { freq: "weekly", every: 1, until: "" });
  assert.deepEqual(e.skip, ["2026-10-12"]);
  assert.equal(e.color, "#ff8800");
  assert.equal(e.alert, -1, "only the alerts it has");
  assert.equal(e.page, "");
  assert.equal(e.detail, "a\nb");
  assert.equal(C.cleanEvent({ title: "x", start: "tomorrow" }), null);
  const a = plain(C.cleanEvent({ title: "Trip", allDay: true, start: "2026-10-10T08:00", end: "2026-10-08" }));
  assert.deepEqual([a.start, a.end], ["2026-10-10", "2026-10-10"], "an all-day one: days, its end not before its start");
  const t = plain(C.cleanEvent({ title: "x", start: "2026-10-05" }));
  assert.deepEqual([t.start, t.end], ["2026-10-05T09:00", "2026-10-05T10:00"], "a timed one with no time: 9 to 10");
});

check("repeats", () => {
  const cal = { events: [ev({ repeat: { freq: "daily", every: 2 } })] };
  assert.deepEqual(days(cal, D(2026, 10, 5), D(2026, 10, 12)), ["2026-10-05", "2026-10-07", "2026-10-09", "2026-10-11"]);
  assert.deepEqual(days(cal, D(2027, 1, 1), D(2027, 1, 6)).length, 3, "a long way on");
  const wd = { events: [ev({ start: "2026-10-02T09:00", end: "2026-10-02T09:15", repeat: { freq: "weekdays" } })] };
  assert.deepEqual(days(wd, D(2026, 10, 2), D(2026, 10, 10)), ["2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09"], "not the weekend");
  const wk = { events: [ev({ repeat: { freq: "weekly", every: 2, until: "2026-11-02" }, skip: ["2026-10-19"] })] };
  assert.deepEqual(days(wk, D(2026, 10, 1), D(2026, 12, 1)), ["2026-10-05", "2026-11-02"], "every 2 weeks, one skipped, until a day");
  const mo = { events: [ev({ start: "2026-01-31T09:00", end: "2026-01-31T10:00", repeat: { freq: "monthly" } })] };
  assert.deepEqual(days(mo, D(2026, 1, 1), D(2026, 6, 1)), ["2026-01-31", "2026-03-31", "2026-05-31"], "a month without the 31st, skipped");
  const yr = { events: [ev({ allDay: true, start: "2024-02-29", end: "2024-02-29", repeat: { freq: "yearly" } })] };
  assert.deepEqual(days(yr, D(2024, 1, 1), D(2029, 1, 1)), ["2024-02-29", "2028-02-29"], "the 29th of February, in leap years");
  const one = { events: [ev({})] };
  assert.deepEqual(days(one, D(2026, 10, 1), D(2026, 10, 31)), ["2026-10-05"]);
  assert.deepEqual(days(one, D(2026, 10, 6), D(2026, 10, 31)), []);
});

check("what happens when", () => {
  const cal = { events: [
    ev({ title: "Late", start: "2026-10-05T23:00", end: "2026-10-06T01:00" }),
    ev({ title: "Trip", allDay: true, start: "2026-10-05", end: "2026-10-07" }),
    ev({ title: "Early", start: "2026-10-06T08:00", end: "2026-10-06T09:00" }),
  ] };
  const list = C.occurrences(cal, D(2026, 10, 6), D(2026, 10, 7));
  assert.deepEqual(plain(list).map((o) => o.title), ["Trip", "Late", "Early"], "what goes on into the day too, all-day ones first");
  const six = C.onDay(list, D(2026, 10, 6));
  assert.equal(six.length, 3);
  assert.equal(C.span(list[1], D(2026, 10, 6)), "Until 1:00");
  assert.equal(C.span(list[2], D(2026, 10, 6)), "8:00 \u2013 9:00");
  assert.equal(C.span(list[0], D(2026, 10, 6)), "All day");
  const trip = plain(C.occurrences(cal, D(2026, 10, 7), D(2026, 10, 8)));
  assert.deepEqual(trip.map((o) => o.title), ["Trip"], "its last day");
});

check("side by side", () => {
  const cal = { events: [
    ev({ title: "A", start: "2026-10-05T09:00", end: "2026-10-05T10:00" }),
    ev({ title: "B", start: "2026-10-05T09:30", end: "2026-10-05T11:00" }),
    ev({ title: "C", start: "2026-10-05T10:00", end: "2026-10-05T10:30" }),
    ev({ title: "D", start: "2026-10-05T12:00", end: "2026-10-05T13:00" }),
  ] };
  const cols = plain(C.columns(C.occurrences(cal, D(2026, 10, 5), D(2026, 10, 6))));
  const by = {};
  cols.forEach((c) => (by[c.occ.title] = [c.col, c.cols]));
  assert.deepEqual(by, { A: [0, 2], B: [1, 2], C: [0, 2], D: [0, 1] });
});

check("what's typed", () => {
  const now = D(2026, 10, 2, 8, 0); // a Friday
  assert.deepEqual(plain(C.quick("Lunch with Sam fri 12:30", now)), { title: "Lunch with Sam", start: "2026-10-02T12:30", end: "2026-10-02T13:30", allDay: false }, "this Friday, while lunch is still to come");
  assert.deepEqual(plain(C.quick("Standup tomorrow 9:30-9:45", now)), { title: "Standup", start: "2026-10-03T09:30", end: "2026-10-03T09:45", allDay: false });
  assert.deepEqual(plain(C.quick("Dentist oct 12 3pm for 30 min", now)), { title: "Dentist", start: "2026-10-12T15:00", end: "2026-10-12T15:30", allDay: false });
  assert.deepEqual(plain(C.quick("Review 9-10am", now)), { title: "Review", start: "2026-10-02T09:00", end: "2026-10-02T10:00", allDay: false }, "9-10am: 9 in the morning");
  assert.deepEqual(plain(C.quick("Holiday dec 24", now)), { title: "Holiday", start: "2026-12-24", end: "2026-12-24", allDay: true });
  assert.deepEqual(plain(C.quick("Call mom at 6pm", now)), { title: "Call mom", start: "2026-10-02T18:00", end: "2026-10-02T19:00", allDay: false });
  assert.deepEqual(plain(C.quick("tomorrow Gym", now)), { title: "Gym", start: "2026-10-03", end: "2026-10-03", allDay: true }, "the day first");
  assert.equal(C.quick("Just a title", now), null, "no day: nothing to place");
  assert.equal(C.quick("", now), null);
  // Asked for on a day (a day clicked): a time alone is on it; a day typed still wins.
  const oct20 = D(2026, 10, 20);
  assert.deepEqual(plain(C.quick("Call Sam 17:00", now, oct20)), { title: "Call Sam", start: "2026-10-20T17:00", end: "2026-10-20T18:00", allDay: false });
  assert.deepEqual(plain(C.quick("Review 9-10am", now, oct20)), { title: "Review", start: "2026-10-20T09:00", end: "2026-10-20T10:00", allDay: false });
  assert.equal(plain(C.quick("Dentist oct 12 3pm", now, oct20)).start, "2026-10-12T15:00");
  assert.equal(plain(C.quick("Wake 7:00", now)).start, "2026-10-03T07:00", "no day asked for: today's gone by, tomorrow");

  // A weekday immediately after "with" is a name, not the start of when.
  const wed = D(2026, 10, 7, 12, 39);
  const wedDay = D(2026, 10, 7);
  assert.equal(C.quick("Meeting with Wednesday", wed, wedDay), null, "Quick Add keeps the whole title on the day asked for");
  assert.deepEqual(plain(C.quick("Meeting with Wednesday 1pm", wed, wedDay)),
    { title: "Meeting with Wednesday", start: "2026-10-07T13:00", end: "2026-10-07T14:00", allDay: false });
  assert.equal(C.quick("Meeting with Tom", wed, wedDay), null, "Tom stays in the title");
  assert.deepEqual(plain(C.quick("Meeting with Tom 3pm", wed, wedDay)),
    { title: "Meeting with Tom", start: "2026-10-07T15:00", end: "2026-10-07T16:00", allDay: false });
  assert.equal(C.quick("Lunch with Monday crew", wed, wedDay), null);
  assert.deepEqual(plain(C.quick("Meeting at 1", wed, wedDay)),
    { title: "Meeting", start: "2026-10-07T13:00", end: "2026-10-07T14:00", allDay: false });
  assert.deepEqual(plain(C.quick("Meeting 3", wed, wedDay)),
    { title: "Meeting", start: "2026-10-07T15:00", end: "2026-10-07T16:00", allDay: false });
  assert.deepEqual(plain(C.quick("Breakfast 06:30", wed, wedDay)),
    { title: "Breakfast", start: "2026-10-07T06:30", end: "2026-10-07T07:30", allDay: false });
  assert.deepEqual(plain(C.quick("Sync 13:00", wed, wedDay)),
    { title: "Sync", start: "2026-10-07T13:00", end: "2026-10-07T14:00", allDay: false });
});

check("changing it", () => {
  const rep = ev({ id: "11111111-1111-4111-8111-111111111111", title: "Standup", start: "2026-10-05T09:00", end: "2026-10-05T09:15", repeat: { freq: "daily" } });
  let cal = C.withEvent(C.make(), rep);
  assert.equal(cal.events.length, 1);
  const [c2, id] = plain(C.detach(cal, rep.id, "2026-10-07", { title: "Standup (late)" }));
  assert.ok(c2.events[0].skip.includes("2026-10-07"), "skipped in the repeat");
  const one = c2.events.find((e) => e.id === id);
  assert.deepEqual([one.title, one.start, one.end, one.repeat], ["Standup (late)", "2026-10-07T09:00", "2026-10-07T09:15", null], "an event of its own");
  assert.deepEqual(days(c2, D(2026, 10, 6), D(2026, 10, 9)), ["2026-10-06", "2026-10-07", "2026-10-08"]);
  const c3 = plain(C.endBefore(cal, rep.id, "2026-10-10"));
  assert.equal(c3.events[0].repeat.until, "2026-10-09", "from a day on: gone");
  assert.equal(plain(C.endBefore(cal, rep.id, "2026-10-05")).events.length, 0, "from its first: all of it");
  const m = plain(C.moved(rep, "2026-10-06T14:30"));
  assert.deepEqual([m.start, m.end], ["2026-10-06T14:30", "2026-10-06T14:45"], "moved, as long as it was");
  const trip = ev({ allDay: true, start: "2026-10-05", end: "2026-10-07" });
  const mt = plain(C.moved(trip, "2026-10-10"));
  assert.deepEqual([mt.start, mt.end], ["2026-10-10", "2026-10-12"]);
  assert.equal(plain(C.without(cal, rep.id)).events.length, 0);
});

check("alerts", () => {
  const cal = { events: [
    ev({ title: "Standup", start: "2026-10-05T09:30", end: "2026-10-05T09:45", alert: 10, place: "Room 4" }),
    ev({ title: "Birthday", allDay: true, start: "2026-10-05", end: "2026-10-05", alert: 0 }),
    ev({ title: "Quiet", start: "2026-10-05T11:00", end: "2026-10-05T12:00" }),
  ] };
  const list = plain(C.alerts(cal, D(2026, 10, 5), D(2026, 10, 6)));
  assert.deepEqual(list.map((a) => a.title), ["Birthday", "Standup"]);
  assert.equal(new Date(list[1].at).getHours() * 60 + new Date(list[1].at).getMinutes(), 9 * 60 + 20);
  assert.equal(list[1].text, "In 10 min, 9:30  \u00b7  Room 4");
  assert.equal(new Date(list[0].at).getHours(), 9, "an all-day one's at 9");
  assert.match(list[1].key, /^cal\|/);
});

check("iCalendar", () => {
  const cal = { events: [
    ev({ id: "11111111-1111-4111-8111-111111111111", title: "Standup, daily; quick", start: "2026-10-05T09:30", end: "2026-10-05T09:45",
      repeat: { freq: "weekdays", every: 1, until: "2026-12-31" }, skip: ["2026-10-12"], alert: 10, place: "Room 4", detail: "line one\nline two" }),
    ev({ title: "Trip", allDay: true, start: "2026-10-10", end: "2026-10-12" }),
  ] };
  const ics = C.toIcs(cal, new Date(Date.UTC(2026, 9, 2, 8, 0, 0)));
  assert.match(ics, /^BEGIN:VCALENDAR\r\n/);
  assert.ok(ics.includes("SUMMARY:Standup\\, daily\\; quick\r\n"), "commas and semicolons escaped");
  assert.match(ics, /DTSTART:20261005T093000\r\n/);
  assert.match(ics, /RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=20261231T235959\r\n/);
  assert.match(ics, /EXDATE:20261012T093000\r\n/);
  assert.match(ics, /DESCRIPTION:line one\\nline two\r\n/);
  assert.match(ics, /TRIGGER:-PT10M/);
  assert.match(ics, /DTSTART;VALUE=DATE:20261010\r\nDTEND;VALUE=DATE:20261013\r\n/, "an all-day end the day after, as the format has it");
  assert.ok(ics.split("\r\n").every((l) => l.length <= 75));
});

check("how it's said", () => {
  assert.equal(C.repeatLabel(null), "Doesn't repeat");
  assert.equal(C.repeatLabel({ freq: "weekdays", every: 1, until: "" }), "Every weekday");
  assert.equal(C.repeatLabel({ freq: "weekly", every: 2, until: "2026-12-01" }), "Every 2 weeks, until 1 Dec");
  assert.equal(C.repeatLabel({ freq: "monthly", every: 1, until: "" }), "Every month");
});

check("an .ics file's events: a booking's, an invitation, another calendar's", () => {
  const ics = [
    "BEGIN:VCALENDAR", "VERSION:2.0",
    "BEGIN:VEVENT", "UID:a", "DTSTART:20261011T072500", "DTEND:20261011T104000", "SUMMARY:Flight SK 214 to Lisbon", "END:VEVENT",
    "BEGIN:VEVENT", "UID:b", "DTSTART;VALUE=DATE:20261011", "DTEND;VALUE=DATE:20261014", "SUMMARY:Lisbon\\, at last", "LOCATION:Rua das Flores 28", "END:VEVENT",
    "BEGIN:VEVENT", "UID:c", "DTSTART:20261005T090000Z", "DTEND:20261005T093000Z", "SUMMARY:Standup with a very long title that the file",
    " folds onto the next line", "DESCRIPTION:Line one\\nLine two", "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=20261231T235959Z",
    "EXDATE:20261009T090000Z", "END:VEVENT",
    "BEGIN:VEVENT", "SUMMARY:No start: left out", "END:VEVENT",
    "BEGIN:VEVENT", "DTSTART;TZID=Europe/Lisbon:20261012T200000", "SUMMARY:Dinner", "RRULE:FREQ=MONTHLY;INTERVAL=2", "END:VEVENT",
    "END:VCALENDAR", ""
  ].join("\r\n");
  const list = plain(C.fromIcs(ics));
  assert.equal(list.length, 4);
  assert.deepEqual([list[0].title, list[0].start, list[0].end, list[0].allDay], ["Flight SK 214 to Lisbon", "2026-10-11T07:25", "2026-10-11T10:40", false]);
  assert.deepEqual([list[1].title, list[1].start, list[1].end, list[1].allDay, list[1].place], ["Lisbon, at last", "2026-10-11", "2026-10-13", true, "Rua das Flores 28"], "the end the file gives is the day after");
  const utc = new Date(Date.UTC(2026, 9, 5, 9, 0));
  const local = utc.getFullYear() + "-" + String(utc.getMonth() + 1).padStart(2, "0") + "-" + String(utc.getDate()).padStart(2, "0") + "T" + String(utc.getHours()).padStart(2, "0") + ":" + String(utc.getMinutes()).padStart(2, "0");
  assert.equal(list[2].start, local, "a UTC time, as the computer's own");
  assert.equal(list[2].title, "Standup with a very long title that the filefolds onto the next line");
  assert.equal(list[2].detail, "Line one\nLine two");
  assert.deepEqual([list[2].repeat.freq, list[2].repeat.until], ["weekdays", "2026-12-31"]);
  assert.equal(list[2].skip.length, 1);
  assert.deepEqual([list[3].start, list[3].repeat.freq, list[3].repeat.every], ["2026-10-12T20:00", "monthly", 2], "a time zone's time, as written");
  assert.ok(list.every((e) => /^[0-9a-f-]{36}$/.test(e.id) && e.alert === -1), "new ids; no alerts");
  // Uber Notebook's own export, read back.
  const cal = { events: list };
  const back = plain(C.fromIcs(C.toIcs(cal)));
  assert.deepEqual(back.map((e) => [e.title, e.start, e.end, e.allDay, e.repeat ? e.repeat.freq : ""]), list.map((e) => [e.title, e.start, e.end, e.allDay, e.repeat ? e.repeat.freq : ""]));
  assert.equal(C.hasLike(cal, back[0]), true, "already there: the same title and start");
  assert.equal(C.hasLike(cal, Object.assign({}, back[0], { start: "2026-10-11T08:00" })), false);
  assert.deepEqual(plain(C.fromIcs("not a calendar")), []);
});

console.log(`calendar: ${passed} checks passed`);
