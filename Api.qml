import QtQuick
import "Workspace.js" as Workspace
import "Import.js" as Import
import "Markdown.js" as Markdown
import "Tags.js" as Tags

// Omanote's commands for AI agents and scripts: `omarchy-shell omanote
// <command>` (Service.qml hands them on). They work on the same pages as the
// window, through the same store, so what they add shows up as you watch,
// links and reminders work, and nothing but the app writes its files.
//
// Every command answers at once, in JSON ({ ok: false, error } when it
// can't), except `read`, which gives the page as Markdown. Content comes in
// as a Markdown file, by its path: arguments are short, and agents write
// Markdown well. Commands add, append and put pages in the trash; nothing is
// deleted for good, and a locked page isn't changed.
QtObject {
  id: api

  property var workspace: null
  // Store.qml: reads a file now (readNow), and where home is.
  property var files: null
  // The window, while there is one: the page you're on is written before a
  // command changes pages, and the page open in it takes what's added to it
  // itself, so that's in its Undo.
  property var ui: null
  // The Inbox: where pages go when a command doesn't say (a setting, so it
  // stays the same page when you rename or move it).
  property string inbox: ""
  signal inboxMade(string id)

  readonly property int maxBytes: 2 * 1024 * 1024

  function answer(o) { return JSON.stringify(o) }
  function fail(message) { return JSON.stringify({ ok: false, error: message }) }

  function unready() {
    if (!workspace || !workspace.ready) return "Omanote's pages aren't loaded yet: try again in a moment"
    return ""
  }

  function live(id) {
    var ix = workspace.index
    return Workspace.isUuid(id) && !!ix.pages[id] && !Workspace.inTrash(ix, id)
  }

  function where(id) {
    var d = Workspace.describe(workspace.index, id)
    return d ? (d.path ? d.path + " / " : "") + d.title : ""
  }

  // The page you're on in the window, written first (so it's what's read,
  // and nothing of yours is lost to what a command writes).
  function writeOpen() {
    if (ui && typeof ui.saveNow === "function") ui.saveNow()
  }

  // The page as it is, kept in its history before a command changes it
  // (what's being written in the window too).
  function keep(id) {
    writeOpen()
    workspace.keepVersion(id, "command", true)
  }

  function viewDoes(what, a, b) {
    return ui && typeof ui[what] === "function" ? ui[what](a, b) : false
  }

  // A Markdown file's text: { text } or { error }.
  function readMarkdown(path) {
    var p = String(path || "").trim()
    if (p.indexOf("~/") === 0 && files && files.home) p = files.home + p.slice(1)
    if (!p || p.charAt(0) !== "/") return { error: "give the Markdown file's full path" }
    var text = files ? files.readNow(p, maxBytes) : null
    if (text === null) return { error: "couldn't read " + p + " (is it there, and under 2 MB?)" }
    return { text: text }
  }

  // Markdown as blocks, "[[Page title]]" a link to the page called that.
  function blocksOf(text, titleFromHeading) {
    return Import.fromMarkdown(text, {
      wiki: function(name) { return Workspace.pageNamed(api.workspace.index, name) }
    }, { titleFromHeading: titleFromHeading })
  }

  // ---- the commands ---------------------------------------------------------------------------

  function help() {
    return answer({
      ok: true,
      app: "Omanote (Omarchy's notes app): its Pages, a tree of pages made of blocks",
      run: "omarchy-shell omanote <command> [arguments]",
      commands: [
        { use: "list", does: "every page: id, title, icon, path (the pages it's inside)" },
        { use: "find <words>", does: "pages with all the words in their title or text, best first, with a snippet" },
        { use: "read <id>", does: "the page as Markdown (pages it links to as omanote://page/<id>)" },
        { use: "add <title> <file.md>", does: "a new page in the Inbox from a Markdown file; an empty title takes the file's first # heading" },
        { use: "addTo <page id> <title> <file.md>", does: "a new page inside that page (\"\" for the top of Pages)" },
        { use: "append <id> <file.md>", does: "the Markdown added at the end of a page" },
        { use: "blocks <id>", does: "the page's blocks, in order: id, type, depth (how far inside other blocks), text (Markdown)" },
        { use: "replace <page id> <block id> <file.md>", does: "the Markdown in place of that block and the blocks inside it" },
        { use: "insertAfter <page id> <block id> <file.md>", does: "the Markdown after that block (and the blocks inside it), as deep as it is" },
        { use: "trash <id>", does: "the page (and the pages in it) to the trash, where it can be put back" },
        { use: "tags", does: "every tag: tag, pages, blocks (how many have it)" },
        { use: "tagged <tag>", does: "every block with the tag: page id, page title, block id, type, text (Markdown), checked" },
        { use: "projects", does: "every project (not the archive's): id, title, status, due, progress (to-dos done of all, its pages' too), overdue" },
        { use: "project <id> <status> <due>", does: "makes the page a project, or changes it: status planning, active, paused or done (\"\" keeps it); due a date like 2026-10-12, \"\" for none, \"-\" to keep it; status \"none\" makes it a page again" },
        { use: "archive <id>", does: "puts the page (and the pages in it) away in the archive; unarchive <id> brings it back" },
        { use: "tagColor <tag> <color>", does: "the tag's color: gray, brown, orange, yellow, green, blue, purple, pink, red, a hex like #ff8800, or \"\" for none (a tag with none takes the color of the tag it's in: #work/acme, #work's)" },
        { use: "open <id>", does: "shows the page in Omanote's window" }
      ],
      markdown: "Headings, lists, - [ ] to-dos, code blocks with their language, > [!NOTE] callouts, "
        + "[[Page title]] (a link to that page), #tag (a tag), [@Fri 2 Oct](omanote://date/2026-10-02) (a date) and "
        + "[\u23f0 Fri 2 Oct 9:30](omanote://remind/2026-10-02T09:30) (a reminder: a notification then)"
    })
  }

  function list() {
    var not = unready()
    if (not) return fail(not)
    return answer(Workspace.allPages(workspace.index))
  }

  function find(words) {
    var not = unready()
    if (not) return fail(not)
    var query = String(words || "")
    if (Workspace.terms(query).length === 0) return fail("find needs words to look for")
    var ix = workspace.index
    var found = []
    for (var id in ix.pages) {
      if (Workspace.inTrash(ix, id)) continue
      var e = ix.pages[id]
      var text = workspace.texts[id] || e.title || ""
      var score = Workspace.score(e.title || "Untitled", text, query)
      if (score <= 0) continue
      var d = Workspace.describe(ix, id)
      var s = Workspace.snippet(text.slice(String(e.title || "").length), query)
      d.snippet = s.before + s.match + s.after
      d.score = score
      found.push(d)
    }
    found.sort(function(a, b) { return b.score - a.score || (a.modified < b.modified ? 1 : -1) })
    return answer(found.slice(0, 50).map(function(d) { delete d.score; return d }))
  }

  // ---- projects and the archive ---------------------------------------------------------------

  function projects() {
    var not = unready()
    if (not) return fail(not)
    return answer(Workspace.projectList(workspace.index, new Date()).map(function(p) {
      return { id: p.id, title: p.title || "Untitled", status: p.status, due: p.due, progress: p.progress.done + "/" + p.progress.total, overdue: p.overdue, path: where(p.id) }
    }))
  }

  // A page made a project (or changed, or a page again: status "none").
  function project(id, status, due) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    var st = String(status || "").trim().toLowerCase()
    var d = String(due === undefined ? "-" : due).trim()
    if (st && st !== "none" && !/^(planning|active|paused|done)$/.test(st)) return fail("a status is planning, active, paused or done (or none: not a project)")
    if (d && d !== "-" && !/^\d{4}-\d{2}-\d{2}$/.test(d)) return fail("a due date is like 2026-10-12, \"\" for none, \"-\" to keep it")
    keep(id)
    var page = workspace.readPageNow(id)
    if (!page) return fail("couldn't read that page")
    if (page.format && page.format.locked) return fail("that page is locked: unlock it in Omanote first")
    var had = page.project || { status: "active", due: "" }
    var next = st === "none" ? null : Workspace.cleanProject({ status: st || had.status, due: d === "-" ? had.due : d })
    var took = viewDoes("setProjectOfOpenPage", id, next)
    if (took === "locked") return fail("that page is locked: unlock it in Omanote first")
    if (took !== true) {
      if (next) page.project = next
      else delete page.project
      page.modified = new Date().toISOString()
      workspace.savePage(page)
      workspace.pageChanged(id)
    }
    return answer({ ok: true, id: id, project: next })
  }

  function archive(id, on) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id) && !(on === false && Workspace.isUuid(id) && workspace.index.pages[id])) return fail("there's no page with that id (list or find gives them)")
    workspace.setArchived(id, on !== false)
    return answer({ ok: true, id: id, archived: on !== false })
  }

  // Every tag: [{ tag, pages, blocks }].
  function tags() {
    var not = unready()
    if (not) return fail(not)
    var colors = workspace.index.tagColors || {}
    return answer(Workspace.tagList(workspace.index).map(function(t) {
      var c = Workspace.tagColorOf(colors, t.name)
      var o = { tag: t.label, name: t.name, pages: t.pages, blocks: t.blocks, color: c.color }
      if (c.from && c.from !== t.name) o.colorFrom = "#" + c.from
      return o
    }))
  }

  // A tag's color: one of Pages' ("blue"), one of your own ("#ff8800"), or "" for none.
  function tagColor(tag, color) {
    var not = unready()
    if (not) return fail(not)
    var name = Tags.clean(tag)
    if (!name) return fail("give a tag: tagColor \"#work\" blue")
    var value = String(color || "").trim().toLowerCase()
    var clean = Workspace.cleanTagColor(value)
    if (value && !clean) return fail("a color is gray, brown, orange, yellow, green, blue, purple, pink, red, a hex like #ff8800, or \"\" for none")
    workspace.setTagColor(name, clean)
    return answer({ ok: true, tag: "#" + name, color: clean })
  }

  // Every block with a tag: [{ page, title, block, type, text, checked }].
  function tagged(tag) {
    var not = unready()
    if (not) return fail(not)
    var name = Tags.clean(tag)
    if (!name) return fail("give a tag: tagged \"#idea\" (or tags, for every tag)")
    writeOpen()
    var out = []
    Workspace.pagesTagged(workspace.index, name).forEach(function(id) {
      var page = workspace.readPageNow(id)
      if (!page) return
      Workspace.taggedBlocks(page, name).forEach(function(b) {
        var o = { page: id, title: page.title || "Untitled", block: b.uid, type: b.type, text: Markdown.inline(b.html) }
        if (b.type === "check") o.checked = b.checked
        out.push(o)
      })
    })
    return answer(out)
  }

  function read(id) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail("couldn't read that page")
    return Markdown.fromDocPage(page, function(pid) {
      var e = api.workspace.index.pages[pid]
      return e && !Workspace.inTrash(api.workspace.index, pid) ? { title: e.title || "Untitled", icon: e.icon, file: "omanote://page/" + pid } : null
    })
  }

  // A quick note (Super+Alt+N) as a page in the Inbox: its first line the
  // title, the rest Markdown (Import.quickNote).
  function quickPage(text) {
    var not = unready()
    if (not) return fail(not)
    var q = Import.quickNote(text)
    if (!q) return fail("there's nothing in it")
    var got = blocksOf(q.markdown, false)
    writeOpen()
    var into = inboxPage()
    if (!into) return fail("couldn't make the Inbox")
    var page = workspace.createPage({ parent: into, title: Workspace.cleanTitle(q.title),
      blocks: got.blocks.concat([{ type: "p", html: "", indent: 0 }]) })
    if (!page) return fail("couldn't make the page")
    placeIn(into, page.id)
    return answer({ ok: true, id: page.id, title: page.title || "Untitled", path: where(page.id) })
  }

  function add(title, path) {
    var not = unready()
    if (not) return fail(not)
    return addTo(inboxPage(), title, path)
  }

  function addTo(parent, title, path) {
    var not = unready()
    if (not) return fail(not)
    var into = String(parent || "")
    if (into === "top") into = ""
    if (into && !live(into)) return fail("there's no page with that id to put it in (\"\" is the top of Pages)")
    var md = readMarkdown(path)
    if (md.error) return fail(md.error)
    var name = String(title || "").trim()
    var got = blocksOf(md.text, name === "")
    writeOpen()
    var page = workspace.createPage({ parent: into, title: Workspace.cleanTitle(name || got.title || ""), icon: got.icon || "", project: got.project,
      blocks: got.blocks.length ? got.blocks.concat([{ type: "p", html: "", indent: 0 }]) : undefined })
    if (!page) return fail("couldn't make the page")
    if (into) placeIn(into, page.id)
    return answer({ ok: true, id: page.id, title: page.title || "Untitled", path: where(page.id) })
  }

  function append(id, path) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    var md = readMarkdown(path)
    if (md.error) return fail(md.error)
    var blocks = blocksOf(md.text, false).blocks
    if (blocks.length === 0) return fail("there's nothing in that file to add")
    keep(id)
    // Open in the window: it adds them itself.
    var took = viewDoes("appendToOpenPage", id, blocks)
    if (took === "locked") return fail("that page is locked: unlock it in Omanote first")
    if (took === true) return answer({ ok: true, id: id, added: blocks.length })
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail("couldn't read that page")
    if (page.format && page.format.locked) return fail("that page is locked: unlock it in Omanote first")
    var n = Workspace.appendBlocks(page, blocks)
    page.modified = new Date().toISOString()
    workspace.savePage(page)
    workspace.pageChanged(id)
    return answer({ ok: true, id: id, added: n })
  }

  // A page's blocks, so a block can be changed: [{ id, type, depth, text }].
  function blocks(id) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail("couldn't read that page")
    return answer(Workspace.blockList(page, Markdown.inline, function(pid) {
      var e = api.workspace.index.pages[pid]
      return e ? e.title || "Untitled" : ""
    }))
  }

  function replace(id, block, path) { return changeBlock(id, block, path, "replace") }
  function insertAfter(id, block, path) { return changeBlock(id, block, path, "after") }

  // A block (and the blocks inside it) replaced by the Markdown, or the
  // Markdown put after it, as deep as it is. Not columns (only what's in
  // them), and not a block with pages inside it, which would go with it.
  function changeBlock(id, block, path, how) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    var md = readMarkdown(path)
    if (md.error) return fail(md.error)
    var list = blocksOf(md.text, false).blocks
    if (list.length === 0) return fail("there's nothing in that file to put in")
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail("couldn't read that page")
    if (page.format && page.format.locked) return fail("that page is locked: unlock it in Omanote first")
    var spot = Workspace.locate(page, String(block || ""))
    if (!spot) return fail("there's no block with that id on the page (blocks <page id> gives them)")
    if (Workspace.isStructure(spot.block.type)) return fail("that block holds columns: change the blocks inside them instead")
    if (how === "replace") {
      for (var k = spot.at; k <= spot.end; k++) {
        if (spot.list[k].type === "page") return fail("there's a page inside that block, which would go with it: change the blocks around it instead")
      }
    }
    keep(id)
    // Open in the window: it changes the page itself, as a step you can undo.
    var took = viewDoes(how === "replace" ? "replaceInOpenPage" : "insertInOpenPage", id, { block: spot.block.uid, blocks: list })
    if (took === "locked") return fail("that page is locked: unlock it in Omanote first")
    if (took !== true) {
      if (how === "replace") Workspace.putBlocks(page, spot.at, spot.end - spot.at + 1, list, spot.depth)
      else Workspace.putBlocks(page, spot.end + 1, 0, list, spot.depth)
      page.modified = new Date().toISOString()
      workspace.savePage(page)
      workspace.pageChanged(id)
    }
    return answer({ ok: true, id: id, block: spot.block.uid, added: list.length })
  }

  function trash(id) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    var title = workspace.index.pages[id].title || "Untitled"
    writeOpen()
    if (viewDoes("trashPage", id) !== true) workspace.trashPage(id, false)
    return answer({ ok: true, id: id, title: title, note: "in the trash, where it can be put back" })
  }

  // ---- the Inbox --------------------------------------------------------------------------------

  // The Inbox page's id: made (at the top of Pages) the first time, and
  // again if it's gone or in the trash.
  function inboxPage() {
    if (live(inbox)) return inbox
    var page = workspace.createPage({ parent: "", title: "Inbox", icon: "\u{1f4e5}", blocks: [
      { type: "callout", icon: "\u{1f916}", color: "gray_background", indent: 0,
        html: "Quick notes (Super+Alt+N, when Settings sends them here) and pages that AI agents and scripts add come in here. Move them anywhere." },
      { type: "p", html: "", indent: 0 }
    ] })
    if (!page) return ""
    inbox = page.id
    inboxMade(page.id)
    return page.id
  }

  // A new page's block on the page it's in (the window adds it itself, if
  // that page is open there).
  function placeIn(parentId, childId) {
    if (viewDoes("addPageBlock", parentId, childId) === true) return
    var parent = workspace.readPageNow(parentId)
    if (!parent) return
    Workspace.appendBlocks(parent, [{ type: "page", uid: childId, indent: 0 }])
    parent.modified = new Date().toISOString()
    workspace.savePage(parent)
    workspace.pageChanged(parentId)
  }
}
