# What a new Omanote starts with

A new Omanote's Pages isn't empty: these example pages show what it can do,
with the people, events and files they mention, and a few templates of your
own. Change them here, then run `dev/starter` (it puts them in
`StarterContent.js`, which `Starter.js` reads; the tests check it's up to
date).

- `pages/*.md`: the example pages, one Markdown file each, named by the key
  other pages use for them (`parent: website-relaunch`).
- `templates/*.md`: templates, in *Templates* at the sidebar's foot.
- `people.json`: who's in People (`{{person:sam}}` on a page names them).
- `calendar.json`: the events (`on`: `"+2"`, `"-1"` or a weekday like
  `"tue"`; no `time`: all day, to `until`; `page`: its notes page).
- `assets/`: the files the pages show (a PDF, a picture, an email, a
  meeting, a sketch). `keyboard-shortcuts.pdf` is made from
  `dev/starter-shortcuts.html` with `dev/starter --pdf`.

A page is Markdown as agents write it (see `skills/omanote/SKILL.md`):
headings, lists, to-dos, tables, callouts, `<details>` toggles, code, and
fenced `mindmap`, `board`, `contact`, `agenda` and `event` blocks. Front
matter: `title`, `icon`, `parent`, `order`, `favorite`, `cover`, and
`status`/`due` for a project. What Markdown can't say is a line starting
with `::` (see `Starter.js`): `::columns 60 40` … `::next` … `::end`,
`::pages`, `::file`, `::image`, `::email`, `::meeting`, `::sketch`,
`::bookmark`, `::button`, `::habit`, `::toc`, `::calendar`.

Dates are for the day Omanote is first opened: `{{date:+2}}` is a date two
days on, `{{day:+2}}` the same as `2026-10-04`, `{{label:-1}}` as
`Thu 1 Oct`, `{{date:tue}}` the next Tuesday. A template's `{{date}}`,
`{{week}}` and the like are filled in when it's used.

People's emails are on `.example` domains and their numbers are 555 ones,
so none of them reaches anyone.
