// Checks page templates: the dates planners go on by, and what's on each page.
// Usage (from the plugin directory): node tests/templates.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Templates = load("Templates.js");
const Blocks = load("Blocks.js");
const Library = load("Library.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

// Dates formatted the way Qt.formatDate would, for the patterns templates use.
const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
function fmt(iso, pattern) {
  const [y, m, d] = iso.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  const out = {
    "dddd, d MMMM": `${DAYS[date.getDay()]}, ${d} ${MONTHS[m - 1]}`,
    "dddd d": `${DAYS[date.getDay()]} ${d}`,
    "ddd d": `${DAYS[date.getDay()].slice(0, 3)} ${d}`,
    "d MMM": `${d} ${MONTHS[m - 1].slice(0, 3)}`,
    "MMMM yyyy": `${MONTHS[m - 1]} ${y}`,
    "ddd d MMM": `${DAYS[date.getDay()].slice(0, 3)} ${d} ${MONTHS[m - 1].slice(0, 3)}`,
    "d": `${d}`,
  }[pattern];
  assert.ok(out, `a pattern templates use: ${pattern}`);
  return out;
}

check("dates", () => {
  assert.equal(Templates.addDays("2026-09-30", 1), "2026-10-01");
  assert.equal(Templates.addDays("2026-12-31", 1), "2027-01-01");
  assert.equal(Templates.addDays("2026-03-01", -1), "2026-02-28");
  assert.equal(Templates.addDays("2026-03-28", 2), "2026-03-30", "across the clocks changing");
  assert.equal(Templates.addMonths("2026-12-15", 1), "2027-01-01");
  assert.equal(Templates.mondayOf("2026-09-30"), "2026-09-28");
  assert.equal(Templates.mondayOf("2026-10-04"), "2026-09-28", "Sunday is the week's last day");
  assert.equal(Templates.mondayOf("2026-09-28"), "2026-09-28");
  assert.equal(Templates.firstOfMonth("2026-09-30"), "2026-09-01");
  for (const bad of ["2026-02-30", "2026-13-01", "26-09-30", "", null, "2026-9-3"]) assert.equal(Templates.isIsoDate(bad), false, String(bad));
  assert.equal(Templates.isIsoDate("2028-02-29"), true);
});

check("week numbers are ISO 8601's", () => {
  const cases = { "2026-09-30": 40, "2026-01-01": 1, "2021-01-03": 53, "2021-01-04": 1, "2024-12-30": 1, "2020-12-31": 53, "2027-01-03": 53, "2026-12-28": 53 };
  for (const [day, week] of Object.entries(cases)) assert.equal(Templates.isoWeek(day), week, day);
});

check("a planner goes on day by day, but never into the past", () => {
  const today = "2026-09-30";
  assert.equal(Templates.nextDay("daily", "", today), today, "the first page is today's");
  assert.equal(Templates.nextDay("daily", "2026-09-30", today), "2026-10-01");
  assert.equal(Templates.nextDay("daily", "2026-10-03", today), "2026-10-04", "planning ahead");
  assert.equal(Templates.nextDay("daily", "2026-09-12", today), today, "skipped days aren't filled in");
  assert.equal(Templates.nextDay("weekly", "", today), "2026-09-28");
  assert.equal(Templates.nextDay("weekly", "2026-09-28", today), "2026-10-05");
  assert.equal(Templates.nextDay("habits", "2026-10-06", today), "2026-10-12", "from any day of a week");
  assert.equal(Templates.nextDay("monthly", "", today), "2026-09-01");
  assert.equal(Templates.nextDay("monthly", "2026-12-01", today), "2027-01-01");
  assert.equal(Templates.nextDay("meeting", "2026-10-09", today), today, "meetings are today's");
  assert.equal(Templates.nextDay("journal", "2026-09-30", today), today);
  assert.equal(Templates.nextDay("todo", "2026-09-30", today), "", "lists have no date");
  assert.equal(Templates.nextDay("nonsense", "", today), "");
});

check("every template makes a page that survives being read back", () => {
  for (const t of plain(Templates.TEMPLATES)) {
    const page = plain(Templates.build(t.id, "2026-09-30", fmt));
    assert.ok(page.blocks.length > 0, t.id);
    const clean = plain(Blocks.cleanList(page.blocks));
    assert.equal(clean.length, page.blocks.length, `${t.id}: every block is a real one`);
    page.blocks.forEach((b, i) => {
      assert.equal(clean[i].type, b.type, `${t.id} block ${i}`);
      if (b.hint) assert.equal(clean[i].hint, b.hint);
      if (b.label) assert.equal(clean[i].label, b.label);
    });
    const saved = plain(Library.cleanPage(Object.assign({ id: "x", created: "2026-09-30T10:00:00Z" }, page), "20260930-100000-abcd"));
    assert.equal(saved.template, t.id === "blank" ? "" : t.id);
    assert.equal(saved.day, t.date ? page.day : "", `${t.id} is dated only if it should be`);
    assert.ok(t.label && t.hint && t.icon, `${t.id} has a label, a hint and an icon`);
  }
  for (const kind of plain(Templates.PAGE_KINDS)) assert.ok(Templates.isTemplate(kind), kind);
});

check("the daily planner", () => {
  const page = plain(Templates.build("daily", "2026-09-30", fmt));
  assert.equal(page.title, "Wednesday, 30 September");
  assert.equal(page.day, "2026-09-30");
  const times = page.blocks.filter((b) => b.type === "time").map((b) => b.label);
  assert.equal(times[0], "07:00");
  assert.equal(times[times.length - 1], "20:00");
  assert.equal(times.length, 14);
  assert.equal(page.blocks[0].type, "h2");
});

check("the weekly and monthly planners and the habit tracker", () => {
  const week = plain(Templates.build("weekly", "2026-10-01", fmt));
  assert.equal(week.day, "2026-09-28", "dated by its Monday");
  assert.equal(week.title, "Week 40 \u00b7 28 Sep \u2013 4 Oct");
  const days = week.blocks.filter((b) => b.type === "h2").map((b) => b.html);
  assert.deepEqual(days.slice(0, 7), ["Monday 28", "Tuesday 29", "Wednesday 30", "Thursday 1", "Friday 2", "Saturday 3", "Sunday 4"]);
  assert.equal(week.blocks[0].hint, "This week's focus");
  assert.equal(week.blocks.filter((b) => b.type === "habit").length, 4);

  const month = plain(Templates.build("monthly", "2026-02-17", fmt));
  assert.equal(month.day, "2026-02-01");
  assert.equal(month.title, "February 2026");
  assert.deepEqual([month.blocks[0].type, month.blocks[0].month], ["calendar", "2026-02"]);
  const log = month.blocks.filter((b) => b.type === "time");
  assert.equal(log.length, 28, "a line for each day of the month");
  assert.equal(log[0].label, "Sun 1");

  const habits = plain(Templates.build("habits", "2026-09-30", fmt));
  assert.equal(habits.title, "Habits \u00b7 week 40");
  assert.equal(habits.blocks.filter((b) => b.type === "habit" && b.days === "0000000").length, 8);
});

check("pages that are named by you", () => {
  const meeting = plain(Templates.build("meeting", "2026-09-30", fmt));
  assert.equal(meeting.title, "", "you name the meeting");
  assert.equal(meeting.day, "2026-09-30");
  assert.equal(Templates.titleHint("meeting"), "What's the meeting?");
  assert.equal(Templates.titleHint("reading"), "Reading log");
  assert.equal(Templates.titleHint("blank"), "");
  assert.equal(Library.pageTitle({ title: "", template: "meeting", blocks: meeting.blocks }), "Meeting notes");
  assert.equal(Library.pageTitle({ title: "Standup", template: "meeting", blocks: [] }), "Standup");
  const packing = plain(Templates.build("packing", "", fmt));
  assert.equal(packing.day, "");
  assert.ok(packing.blocks.some((b) => b.html === "Passport or ID"));
  assert.equal(plain(Templates.build("nonsense", "", fmt)).template, "", "anything else is a blank page");
});

check("templates in Pages", () => {
  const W = load("Workspace.js");
  const Html = load("Html.js");
  const text = (b) => Html.plainText(b.html || "");
  for (const t of plain(Templates.TEMPLATES)) {
    if (t.id === "blank") continue;
    const page = plain(Templates.forPages(t.id, "2026-09-30", fmt));
    assert.ok(page.icon, `${t.id} has an icon`);
    assert.ok(page.title || page.hint, `${t.id} has a title, or says what to call it`);
    for (const b of page.blocks) assert.ok(W.isKind(b.type), `${t.id}: ${b.type} is a block Pages has`);
    // Laid out as Pages keeps it: columns that stay columns, blocks inside blocks that can hold them.
    const list = page.blocks.map((b) => Object.assign({ uid: W.uuid4() }, b));
    assert.equal(W.fixColumns(list), null, `${t.id}: its columns are whole`);
    const again = plain(W.flatten(Object.assign({ id: "p" }, W.unflatten(list, "p"))));
    assert.deepEqual(again.map((b) => [b.type, b.indent, b.hint || "", b.collapsed === true]), page.blocks.map((b) => [b.type, b.indent, b.hint || "", b.collapsed === true]), `${t.id} is saved as it is`);
    // Every empty line says what goes on it (but the one at the end).
    page.blocks.slice(0, -1).forEach((b, i) => {
      if (["p", "check", "bullet", "number", "quote", "callout", "habit"].includes(b.type) && !text(b)) assert.ok(b.hint, `${t.id} block ${i} (${b.type}) says what it's for`);
    });
    const last = page.blocks[page.blocks.length - 1];
    assert.deepEqual([last.type, last.indent, text(last)], ["p", 0, ""], `${t.id} ends with a line to write on`);
  }
  const daily = plain(Templates.forPages("daily", "2026-09-30", fmt));
  assert.equal(daily.title, "Wednesday, 30 September");
  assert.equal(daily.blocks[0].type, "callout");
  const times = daily.blocks.filter((b) => b.type === "p" && /^\d\d:00 $/.test(text(b)));
  assert.equal(times.length, 14, "the day hour by hour");
  assert.ok(times.every((b) => b.indent === 2), "in two columns");
  const weekly = plain(Templates.forPages("weekly", "2026-09-30", fmt));
  assert.equal(weekly.title, "Week 40 \u00b7 28 Sep \u2013 4 Oct");
  assert.deepEqual(weekly.blocks.filter((b) => b.type === "h3").slice(0, 7).map(text), ["Mon 28", "Tue 29", "Wed 30", "Thu 1", "Fri 2", "Sat 3", "Sun 4"]);
  assert.equal(weekly.blocks.filter((b) => b.type === "habit").length, 4);
  const monthly = plain(Templates.forPages("monthly", "2026-09-30", fmt));
  assert.equal(monthly.title, "September 2026");
  assert.equal(monthly.blocks.find((b) => b.type === "calendar").month, "2026-09");
  const weeks = monthly.blocks.filter((b) => b.type === "toggle");
  assert.deepEqual(weeks.map(text), ["Week 36 \u00b7 1 \u2013 6 Sep", "Week 37 \u00b7 7 \u2013 13 Sep", "Week 38 \u00b7 14 \u2013 20 Sep", "Week 39 \u00b7 21 \u2013 27 Sep", "Week 40 \u00b7 28 \u2013 30 Sep"]);
  assert.deepEqual(weeks.map((b) => b.collapsed === true), [true, true, true, true, false], "this week open");
  assert.equal(monthly.blocks.filter((b) => b.type === "p" && b.indent === 1).length, 30, "a line for each day");
  assert.equal(plain(Templates.forPages("habits", "2026-09-30", fmt)).blocks.filter((b) => b.type === "habit").length, 8);
  const meeting = plain(Templates.forPages("meeting", "2026-09-30", fmt));
  assert.deepEqual([meeting.title, meeting.hint], ["", "What's the meeting?"], "you name the meeting");
  assert.equal(meeting.blocks[0].html, '<a href="omanote://date/2026-09-30">@Wed 30 Sep</a> ', "on today's date");
  assert.equal(plain(Templates.forPages("todo", "", fmt)).title, "To do");
  assert.equal(plain(Templates.forPages("reading", "", fmt)).title, "Reading log");
  const packing = plain(Templates.forPages("packing", "", fmt));
  assert.ok(packing.blocks.some((b) => text(b) === "Passport or ID"));
});

console.log(`templates: ${passed} checks passed`);
