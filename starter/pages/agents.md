---
title: Working with your AI agent
icon: 🤖
parent: welcome
order: 3
---
Omanote works with Omarchy's default coding agent (Claude Code, Codex, OpenCode…). Ask it from any page, and its changes show up as it works, each one a step you can undo.

> [!TIP] Press **Ctrl+J**, type `/agent`, or select some words and click *Ask* on the toolbar.

## Things to ask

- [ ] "Turn these notes into to-dos, with who does what"
- [ ] "Summarize this meeting: the decisions and the action items" (on [[Weekly sync]], *Summarize* asks this for you)
- [ ] "Make a mind map of what's on this page"
- [ ] "Plan a three-day trip to Porto, as a page like [[Weekend in Lisbon]]"
- [ ] "Put these tasks on the board, in the right columns"
- [ ] "What did I write about the launch this month?"

## From the terminal

Agents and scripts reach your notes with `omarchy-shell omanote`. The app does every write, so a page shows up in the window as it's added:

```bash
omarchy-shell omanote help                  # every command, as JSON
omarchy-shell omanote find "launch"         # pages with those words
omarchy-shell omanote add "Ideas" ideas.md  # a new page in the Inbox, from Markdown
omarchy-shell omanote events "" ""          # what's on the calendar this week
omarchy-shell omanote contacts "northwind"  # people at Northwind
```

<details>
<summary>What can an agent change?</summary>

Pages and the blocks on them, boards, tags, projects, the calendar and People. It can't record audio or draw. Before it changes a page, Omanote keeps the page as it was in its *Page history*, and a locked page doesn't change at all.

</details>
