import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace
import "../Docs.js" as Docs
import "../Blocks.js" as Blocks
import "../Markdown.js" as Markdown
import "../Import.js" as Import
import "../Html.js" as Html
import "../Templates.js" as Templates
import "../Agent.js" as Agent
import "../Permissions.js" as Permissions
import "../Colors.js" as Colors
import "../Tags.js" as Tags
import "../Audio.js" as Audio
import "../Meeting.js" as Meeting
import "../Calendar.js" as Calendar
import "../Dates.js" as Dates
import "../Board.js" as Board
import "../Files.js" as Files
import "../Contacts.js" as Contacts
import "../Email.js" as Email
import "../Library.js" as Library

// Pages: the other way to write in Uber Notebook, the way Notion does it. The
// sidebar has every page as a tree; the page you're on has its cover, icon
// and title, then its blocks (Editor.qml in its "doc" layout), with the "/"
// menu, a toolbar over selected words, and a menu on each block's handle.
// A page is saved a moment after you stop, and when you leave it.
FocusScope {
  id: view

  property var theme: null
  property var workspace: null
  property var service: null
  readonly property var settings: service && service.settings ? service.settings : ({})

  signal notebooksRequested()
  signal settingsRequested()
  // Settings, at what's in the sidebar.
  signal sidebarChoicesRequested()
  // What's new in a newer version (the sidebar's foot says there's one).
  signal releaseNotesRequested()
  signal toast(string text)
  // A message with a way to take back what it says was done.
  signal toastUndo(string text, var undo)
  // A picture from the desktop's file picker: done(path) ("" for none).
  signal pictureRequested(var done)
  signal confirmRequested(string title, string text, string action, var confirmed)
  // Notes to import: the desktop's file picker, for files or a folder.
  signal importRequested(bool folder)

  // The open page (Workspace.cleanPage), changed in place; `revision` counts
  // every change, so what's worked out from it looks again.
  property var page: null
  property int revision: 0
  property bool pageDirty: false
  property bool sidebarShown: true
  property var openRows: ({})
  property var history: []
  property int historyAt: -1
  property bool pendingActivate: false
  property bool settingTitle: false
  // Nothing on the page yet: it can start from a template.
  property bool pageBlank: false
  // The faint title of a page from a template you name ("What's the meeting?").
  property string titleHint: ""
  // A tag shown (its blocks, TagView.qml) instead of a page.
  property string tagShown: ""
  // The calendar shown, in place of a page.
  property bool calendarShown: false
  // The Library (everything put on the pages), in place of a page.
  property bool libraryShown: false
  // People (contacts), in place of a page.
  property bool peopleShown: false
  // Templates (yours and Uber Notebook's), in place of a page.
  property bool templatesShown: false
  // An event just made from "More" with nothing in it yet (it goes if it's left empty).
  property string justMade: ""

  readonly property var index: { var r = workspace ? workspace.revision : 0; return workspace ? workspace.index : Workspace.emptyIndex() }
  readonly property var format: { var r = revision; return page && page.format ? page.format : ({ width: "normal", size: "normal", font: "sans" }) }
  readonly property bool small: format.size === "small"
  // A locked page reads but can't be changed (unlock it in its ⋯ menu).
  readonly property bool locked: format.locked === true
  // An event's editor is open (the calendar under it doesn't take its clicks).
  readonly property bool eventEditorOpen: eventPop.opened
  readonly property bool favorite: { var r = workspace ? workspace.revision : 0; return page && workspace ? workspace.isFavorite(page.id) : false }
  readonly property string family: theme.penFamily(Docs.font(format.font).families)
  readonly property real sidebarW: sidebarShown ? 250 : 0
  readonly property real pageW: format.width === "full" ? Math.max(360, main.width - 2 * 96) : Math.max(320, Math.min(720, main.width - 2 * 84))
  readonly property alias editor: editor
  readonly property alias agentBox: agentPop
  readonly property alias agentPanel: workPanel
  readonly property alias historyPanel: historyPanel
  readonly property alias tagView: tagView
  readonly property alias calendarView: calendarView
  readonly property alias libraryView: libraryView
  readonly property alias peopleView: peopleView
  readonly property alias templatesView: templatesView
  readonly property alias pagePicker: picker
  readonly property alias picturePicker: picturePicker
  readonly property alias contactPop: contactPop
  readonly property alias flick: flick
  readonly property var crumbs: { var r = workspace ? workspace.revision : 0; var rr = revision; return page && workspace ? Workspace.path(workspace.index, page.id) : [] }
  readonly property string cover: { var r = revision; return page ? page.cover : "" }
  // The pages that link to this one.
  readonly property var backlinks: { var r = workspace ? workspace.revision : 0; var rr = revision; return page && workspace ? Workspace.backlinks(workspace.index, page.id) : [] }
  readonly property string icon: { var r = revision; return page ? page.icon : "" }
  readonly property real coverH: cover ? 200 : 0

  // ---- opening pages -------------------------------------------------------------------

  // Pages shown: the page you were on last, else the first one.
  function activate() {
    if (tagShown || libraryShown || peopleShown || templatesShown) return
    if (page) { focusPage(false); return }
    if (!workspace || !workspace.ready) { pendingActivate = true; return }
    workspace.ensureStarted()
    var ix = workspace.index
    var last = settings.lastPage || ""
    if (last && ix.pages[last] && !Workspace.inTrash(ix, last)) { open(last); return }
    var first = ix.top.filter(function(id) { var e = ix.pages[id]; return e && !e.trashed && !e.template && !e.archived && !e.synced })[0]
    if (first) { open(first); return }
    pendingActivate = true
  }

  Connections {
    target: view.workspace
    // Another notes folder (Settings, or `omarchy-shell uber-notebook set folder`).
    function onFolderChanged() { view.leaveFolder() }
    function onRevisionChanged() {
      if (view.pendingActivate && view.workspace.ready && view.visible) {
        view.pendingActivate = false
        view.activate()
      }
    }
    // A page changed on disk while it was open but unchanged here (a page
    // moved into it from elsewhere): shown as it is now.
    function onPageChanged(id) {
      if (view.page && view.page.id === id && !view.pageDirty) view.workspace.readPage(id, function(p) { if (p && view.page && view.page.id === id) view.show(p) })
    }
  }

  // Opens a page; `then`: "title" puts the cursor in its title, { block }
  // on that block. ("tag:<name>" in the history is a tag.)
  function open(id, fromHistory, then) {
    if (!workspace || !id) return
    if (String(id).indexOf("tag:") === 0) { openTag(String(id).slice(4), fromHistory); return }
    if (String(id).indexOf("calendar") === 0) { openCalendar(String(id).slice(9), fromHistory); return }
    if (String(id).indexOf("library") === 0) { openLibrary(String(id).slice(8), fromHistory); return }
    if (String(id).indexOf("people") === 0) { openPeople(String(id).slice(7), fromHistory); return }
    if (id === "templates") { openTemplates(fromHistory); return }
    commit()
    workspace.readPage(id, function(p) {
      if (!p) { view.toast("That page isn't there any more"); return }
      var e = view.workspace.index.pages[id]
      if (e) p.parent = e.parent
      view.tagShown = ""
      view.calendarShown = false
      view.libraryShown = false
      view.peopleShown = false
      view.templatesShown = false
      view.show(p)
      if (!fromHistory) {
        view.history = view.history.slice(0, view.historyAt + 1).concat([id]).slice(-100)
        view.historyAt = view.history.length - 1
      }
      view.expandTo(id)
      if (view.service) view.service.setSetting("lastPage", id)
      if (then && then.block) Qt.callLater(function() { view.editor.focusBlock(then.block, 0) })
      else view.focusPage(then === "title")
    })
  }

  // ---- buttons, files, videos, bookmarks, boards, synced blocks ------------------------------

  // The blocks being worked on (a bookmark's page being read): { uid: true }.
  property var dataWork: ({})
  function setDataWork(uid, on) {
    var t = {}
    for (var k in dataWork) if (k !== uid) t[k] = true
    if (on) t[uid] = true
    dataWork = t
  }

  // What one of them asks for.
  function dataAction(uid, what, arg) {
    if (what === "syncedPick") { openSyncedPick(uid); return }
    var i = editor.indexOf(uid)
    if (i < 0) return
    var type = editor.model.get(i).type
    var d = editor.dataOf(uid)
    if (what === "colors") { openDataColors(uid, arg); return }
    if (type === "button") {
      if (what === "new" || what === "setup") openButtonSetup(uid, arg || editor.items[uid])
      else if (what === "press") pressButton(uid)
    } else if (type === "file" || type === "video") {
      if (what === "new" || what === "pick") pickData(uid, type === "video" ? "video" : d.kind === "pdf" ? "pdf" : "any")
      else if (what === "open" && d.src) openFileHere(d.src, d.name)
    } else if (type === "bookmark") {
      if (what === "new") Qt.callLater(function() { var it = editor.items[uid]; if (it && it.dataView) it.dataView.focusLink() })
      else if (what === "fetch") fetchBookmark(uid, arg.url)
      else if (what === "open" && d.url) workspace.files.openUrl(d.url)
      else if (what === "copy" && d.url) { workspace.files.copyText(d.url); toast("Copied the link") }
    } else if (type === "board") {
      if (what === "openCard") openCard(uid, arg)
      else if (what === "deleteCard") deleteCard(uid, arg)
    } else if (type === "synced") {
      if (what === "edit" && d.page) open(d.page)
      else if (what === "unsync") unsync(uid)
    } else if (type === "email") {
      if (what === "new" || what === "pick") pickEmail(uid)
      else if (what === "open" && d.src) openAsset(d.src, d.name || "email.eml")
      else if (what === "attachment") openEmailAttachment(uid, arg)
      else if (what === "copy") copyText(arg)
      else if (what === "link") workspace.files.openUrl(arg)
    } else if (type === "gallery") {
      if (what === "new" || what === "pick") pickGalleryPictures(uid)
      else if (what === "view") showPictures(d.images, arg)
    } else if (type === "contact") {
      if (what === "new") Qt.callLater(function() { var it = editor.items[uid]; if (it && it.dataView) it.dataView.focusPick() })
      else if (what === "openPerson") openPeople(arg)
      else if (what === "copy") copyText(arg)
      else if (what === "email") mailTo(arg)
      else if (what === "web") workspace.files.openUrl(arg)
    }
  }

  // Its colors: Pages' or your own, from the color menu (and picker).
  function openDataColors(uid, anchor) {
    var v = editor.items[uid] ? editor.items[uid].dataView : null
    if (!v || !anchor) return
    tableColorTarget = uid
    colorAt = anchor.mapToItem(view, Math.min(0, anchor.width - 250), anchor.height + 6)
    var now = v.scopeColors()
    tableColors.currentText = now.color
    tableColors.currentBack = now.background
    tableColors.subject = v.colorSubject()
    tableColors.x = Math.max(8, Math.min(view.width - tableColors.width - 8, colorAt.x))
    tableColors.y = Math.min(colorAt.y, view.height - 300)
    tableColors.open()
  }

  // An email (.eml) picked or dropped, copied in and read, for a block.
  function pickEmail(uid) {
    if (!service || typeof service.pickFile !== "function") { toast("Files can't be picked here"); return }
    var pageId = page ? page.id : ""
    service.pickFile("email", function(path) { if (path) view.addEmailTo(pageId, uid, path) })
  }
  function addEmailTo(pageId, uid, path) {
    workspace.importEmail(path, function(s, why) {
      if (!s) { view.toast(why || "That email couldn't be read"); return }
      if (!view.page || view.page.id !== pageId || editor.indexOf(uid) < 0) { view.toast("Its page isn't open any more: the email's in Pages/assets"); return }
      var d = editor.dataOf(uid)
      for (var k in s) d[k] = s[k]
      editor.setData(uid, d)
    })
  }
  // An email's attachment: a calendar file's events, to put on your calendar;
  // a contact card's people, into People; anything else written out (once;
  // then kept), then opened in its app.
  function openEmailAttachment(uid, at) {
    var d = editor.dataOf(uid)
    var a = d.attachments ? d.attachments[at] : null
    if (!a) return
    if (isCalendarFile(a.name) || isContactFile(a.name)) {
      workspace.readEmail(d.src, function(m) {
        var att = m ? m.attachments[at] : null
        if (!att) { view.toast("That attachment couldn't be read"); return }
        var text = Email.attachmentText(m, att.index)
        if (view.isCalendarFile(a.name)) view.showIcs(text, a.name)
        else view.addPeopleFrom(a.name, text)
      })
      return
    }
    if (a.src) { openAsset(a.src, a.name); return }
    var pageId = page ? page.id : ""
    workspace.emailAttachment(d.src, at, a.name, function(src) {
      if (!src) { view.toast("That attachment couldn't be opened"); return }
      view.openAsset(src, a.name)
      if (view.page && view.page.id === pageId && editor.indexOf(uid) >= 0) {
        var now = editor.dataOf(uid)
        if (now.attachments && now.attachments[at]) { now.attachments[at].src = src; editor.setData(uid, now) }
      }
    })
  }

  // A link to a page, to another page (one step to undo).
  function relink(uid, id) {
    if (!id || editor.indexOf(uid) < 0 || editor.typeOf(uid) !== "link") return
    editor.setProp(uid, "target", id)
    markDirty()
  }

  // ---- pictures: a gallery's, and shown large here ----

  // Pictures picked (several at once, shown as pictures) for a gallery; the
  // desktop's file dialog a click away.
  function pickGalleryPictures(uid) {
    if (!workspace || !workspace.files) return
    var pageId = page ? page.id : ""
    picturePicker.choose(true, function(paths) { view.addToGallery(pageId, uid, paths) }, function() {
      if (view.service && typeof view.service.pickPictures === "function")
        view.service.pickPictures(function(paths) { if (paths && paths.length) view.addToGallery(pageId, uid, paths) })
    })
  }
  // Pictures copied into Pages/assets, then at the gallery's end (one step to undo).
  function addToGallery(pageId, uid, paths) {
    var list = (paths || []).filter(function(p) { return Files.kindOf(p) === "image" }).slice(0, 100)
    if (!list.length) { toast("Those aren't pictures"); return }
    var got = []
    var left = list.length
    list.forEach(function(path, i) {
      view.workspace.importPicture(path, function(src) {
        got[i] = src
        if (--left > 0) return
        var srcs = got.filter(function(s) { return !!s })
        if (!view.page || view.page.id !== pageId || editor.indexOf(uid) < 0) { if (srcs.length) view.toast("Its page isn't open any more: the pictures are in Pages/assets"); return }
        if (!srcs.length) { view.toast("Those pictures couldn't be copied in"); return }
        var d = editor.dataOf(uid)
        d.images = (d.images || []).concat(srcs.map(function(s) { return { src: s, caption: "" } }))
        editor.setData(uid, d)
      })
    })
  }
  // The gallery under a point of the page's drop area, or "".
  function galleryAt(area, x, y) {
    for (var i = 0; i < editor.model.count; i++) {
      var uid = editor.uidAt(i)
      if (editor.model.get(i).type !== "gallery") continue
      var it = editor.items[uid]
      if (!it || !it.visible) continue
      var p = it.mapFromItem(area, x, y)
      if (p.x >= 0 && p.y >= 0 && p.x < it.width && p.y < it.height) return uid
    }
    return ""
  }
  // Pictures shown large, here: [{ src, caption }], from the one at `at`.
  function showPictures(list, at) {
    viewer.show((list || []).map(function(x) { return { src: x.src, caption: x.caption || "" } }), at || 0)
  }
  // A picture on the page shown large, with the page's other pictures a key away.
  function showPagePicture(src) {
    var list = editor.serialize().filter(function(b) { return b.type === "image" && b.src }).map(function(b) { return { src: b.src, caption: "" } })
    var at = list.map(function(x) { return x.src }).indexOf(src)
    showPictures(at >= 0 ? list : [{ src: src, caption: "" }], Math.max(0, at))
  }

  // ---- a picture, out of Uber Notebook ----

  // Onto the clipboard, to paste anywhere.
  function copyPicture(src) {
    var path = workspace ? workspace.assetPath(src) : ""
    if (!path) return
    workspace.files.copyPicture(path, function(ok) { view.toast(ok ? "Copied: paste it anywhere" : "The picture couldn't be copied") })
  }
  // A copy saved where you say, named for its caption (or the page).
  function savePicture(src, caption) {
    var path = workspace ? workspace.assetPath(src) : ""
    if (!path) return
    if (!service || typeof service.pickSavePath !== "function") { toast("A copy can't be saved from here"); return }
    service.pickSavePath(Library.saveName(caption || (page ? page.title : ""), src), function(to) {
      if (!to) return
      workspace.files.copyFileTo(path, to, function(ok, why) {
        view.toast(ok ? "Saved to " + view.tilde(to) : "The picture couldn't be saved" + (why ? ": " + why : ""))
      })
    })
  }
  // A diagram or an equation as a picture (a PNG, twice its size, on its
  // block's colors): onto the clipboard, to paste anywhere.
  function copyDrawing(kind, source, look) {
    var files = workspace ? workspace.files : null
    if (!files) return
    editor.drawingImage(kind, source, look, function(result) {
      var tmp = files.tempPath("drawing-" + Date.now() + ".png")
      if (!result || !files.saveGrab(result, tmp)) { view.drawingSaid("It couldn't be made a picture"); return }
      files.copyPicture(tmp, function(ok) {
        view.drawingSaid(ok ? "Copied as a picture: paste it anywhere" : "The picture couldn't be copied")
        files.exec(["/usr/bin/rm", "-f", "--", tmp], null)
      })
    })
  }
  // Saved where you say, named for its page.
  function saveDrawing(kind, source, look) {
    var files = workspace ? workspace.files : null
    if (!files) return
    if (!service || typeof service.pickSavePath !== "function") { drawingSaid("A picture can't be saved from here"); return }
    var what = kind === "math" ? "equation" : "diagram"
    service.pickSavePath(Library.saveName(page && page.title ? page.title + " " + what : what.charAt(0).toUpperCase() + what.slice(1), "x.png"), function(to) {
      if (!to) return
      editor.drawingImage(kind, source, look, function(result) {
        var ok = !!result && files.saveGrab(result, to)
        view.drawingSaid(ok ? "Saved to " + view.tilde(to) : "The picture couldn't be saved")
      })
    })
  }
  // Said here, and in the view over everything when it's open (over the
  // toasts, which it would hide).
  function drawingSaid(text) {
    toast(text)
    var v = editor.drawingViewer
    if (v && v.opened) v.say(text)
  }
  // A path with your home as ~.
  function tilde(path) {
    var home = workspace && workspace.files ? workspace.files.home : ""
    return home && path.indexOf(home + "/") === 0 ? "~" + path.slice(home.length) : path
  }

  // ---- files that open here, or in their app ----

  function isCalendarFile(name) { return /\.(ics|ical|ifb|vcs)$/i.test(String(name || "")) }
  function isContactFile(name) { return /\.(vcf|vcard)$/i.test(String(name || "")) }

  // A file in Pages/assets in its app; one with no app for it but a web
  // browser (it would download it, and take you away from here) isn't
  // handed to it: that's said instead.
  function openAsset(src, name) {
    workspace.openAsset(src, function(ok, why) {
      if (ok) return
      var ext = (/\.([A-Za-z0-9]{1,8})$/.exec(String(name || src)) || [])[1]
      view.toast((ext ? "No app here opens ." + ext.toLowerCase() + " files" : "No app here opens it") + (why === "browser" ? " but your web browser" : "") + ": it's kept in Pages/assets")
    })
  }
  // A file block's file: a calendar's events, a contact card's people, here; else in its app.
  function openFileHere(src, name) {
    if (isCalendarFile(name) || isContactFile(name)) {
      workspace.readAsset(src, function(text) {
        if (text === null) { view.toast("That file couldn't be read"); return }
        if (view.isCalendarFile(name)) view.showIcs(text, name)
        else view.addPeopleFrom(name, text)
      })
      return
    }
    openAsset(src, name)
  }
  // A contact card's people, into People (said how many; Undo takes them out).
  function addPeopleFrom(name, text) {
    workspace.addPeopleFrom(name, text, function(r) {
      if (!r) { view.toast("There's no one in " + name); return }
      view.toastUndo((r.added ? r.added + (r.added === 1 ? " person" : " people") + " added to People" : "No one new") + (r.updated ? ", " + r.updated + " filled in" : ""), function() { view.workspace.undoContacts() })
    })
  }

  // An .ics file's events (an email's, a file block's, one dropped or
  // picked), shown, to put on your calendar.
  function showIcs(text, name) {
    var events = Calendar.fromIcs(text)
    if (!events.length) { toast("There are no events in " + (name || "it")); return }
    icsPop.events = events
    icsPop.fileName = name || ""
    icsPop.x = Math.round((view.width - icsPop.width) / 2)
    icsPop.y = Math.round(Math.max(40, view.height * 0.18))
    icsPop.open()
  }
  function addIcsEvents() {
    var fresh = icsPop.fresh
    icsPop.close()
    if (!fresh.length) return
    var cal = workspace.calendar
    fresh.forEach(function(e) { cal = Calendar.withEvent(cal, e) })
    workspace.setCalendar(cal)
    toastUndo(fresh.length + (fresh.length === 1 ? " event" : " events") + " on your calendar", function() { view.workspace.undoCalendar() })
  }
  // Calendar's Import .ics: a file picked, its events shown.
  function importIcs() {
    if (!service || typeof service.pickFile !== "function") { toast("Files can't be picked here"); return }
    service.pickFile("calendar", function(path) {
      if (!path) return
      view.workspace.files.readFiles([path], function(got) {
        if (got[path] === undefined) { view.toast("That file couldn't be read"); return }
        view.showIcs(got[path], path.slice(path.lastIndexOf("/") + 1))
      }, 16 * 1024 * 1024)
    })
  }
  function eventWhen(e) {
    var s = Dates.fromIso(e.start)
    var en = Dates.fromIso(e.end)
    if (!s) return ""
    if (e.allDay) return Dates.label(s.at, false, new Date()) + (en && e.end !== e.start ? " \u2013 " + Dates.label(en.at, false, new Date()) : "") + "  \u00b7  all day"
    var t = function(d) { return d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes() }
    return Dates.label(s.at, false, new Date()) + ", " + t(s.at) + (en ? "\u2013" + t(en.at) : "")
  }

  // A file (or a video) picked and copied in, for a block.
  function pickData(uid, kind) {
    if (!service || typeof service.pickFile !== "function") { toast("Files can't be picked here"); return }
    var pageId = page ? page.id : ""
    service.pickFile(kind, function(path) {
      if (!path) return
      view.addFileTo(pageId, uid, path)
    })
  }
  function addFileTo(pageId, uid, path) {
    workspace.importFile(path, function(f) {
      if (!f) { view.toast("The file couldn't be copied in"); return }
      if (!view.page || view.page.id !== pageId || editor.indexOf(uid) < 0) { view.toast("Its page isn't open any more: the file's in Pages/assets"); return }
      var d = editor.dataOf(uid)
      d.src = f.src
      d.name = f.name
      d.size = f.size
      d.kind = f.kind
      d.poster = f.poster || ""
      editor.setData(uid, d)
    })
  }

  // A bookmark's page read: its title, a line, its picture.
  function fetchBookmark(uid, url) {
    var pageId = page ? page.id : ""
    setDataWork(uid, true)
    workspace.fetchBookmark(url, function(data, why) {
      view.setDataWork(uid, false)
      if (why) view.toast(why)
      if (!data || !view.page || view.page.id !== pageId || editor.indexOf(uid) < 0) return
      var d = editor.dataOf(uid)
      for (var k in data) d[k] = data[k]
      editor.setData(uid, d)
    })
  }

  // A button pressed: its template put in after it, or a new page from it inside this one.
  function pressButton(uid) {
    var d = editor.dataOf(uid)
    if (!d || !d.template || !page) return
    var mine = d.template.indexOf("tpl:") === 0
    if (d.action === "page") {
      if (mine) newPageFromTemplate(d.template.slice(4), page.id)
      else {
        var t = Templates.forPages(d.template, Templates.iso(new Date()), function(x, pattern) { return Qt.formatDate(Templates.parse(x), pattern) })
        commit()
        var child = workspace.createPage({ parent: page.id, title: t.title, icon: t.icon, blocks: t.blocks })
        if (!child) return
        editor.placeBlock(editor.uidAt(editor.model.count - 1), { type: "page", id: child.id })
        markDirty()
        commit()
        open(child.id, false, "title")
      }
      return
    }
    if (mine) { useTemplateHere(d.template.slice(4), "insert", uid); return }
    var bt = Templates.forPages(d.template, Templates.iso(new Date()), function(x, pattern) { return Qt.formatDate(Templates.parse(x), pattern) })
    var i = editor.indexOf(uid)
    var base = editor.model.get(i).indent
    var list = bt.blocks.slice()
    var tail = list[list.length - 1]
    if (list.length > 1 && tail && tail.type === "p" && Html.plainText(tail.html || "") === "") list.pop()
    list.forEach(function(b) { b.indent = (b.indent || 0) + base })
    editor.insertBlocksAt(editor.subtreeEnd(i) + 1, list, false)
  }

  function openButtonSetup(uid, anchor) {
    buttonSetup.uid = uid
    var a = anchor || main
    var p = a.mapToItem(view, 0, a.height + 6)
    buttonSetup.x = Math.max(8, Math.min(view.width - buttonSetup.width - 8, p.x))
    buttonSetup.y = Math.max(8, Math.min(view.height - 460, p.y))
    buttonSetup.open()
  }

  // A board's card: its page (made, the first time: a page inside this one).
  function openCard(uid, arg) {
    if (!page) return
    if (arg.page && workspace.index.pages[arg.page] && !Workspace.inTrash(workspace.index, arg.page)) { open(arg.page); return }
    commit()
    var child = workspace.createPage({ parent: page.id, title: arg.text || "" })
    if (!child) return
    var d = editor.dataOf(uid)
    editor.setData(uid, Board.setCard(d, arg.id, { page: child.id }))
    markDirty()
    commit()
    open(child.id, false, arg.text ? "" : "title")
  }

  // A synced block's blocks made this page's own, here.
  function unsync(uid) {
    var d = editor.dataOf(uid)
    if (!d || !d.page) return
    var at = editor.indexOf(uid)
    var base = editor.model.get(at).indent
    workspace.readPage(d.page, function(p) {
      if (!p || editor.indexOf(uid) < 0) return
      var list = Workspace.flatten(p).filter(function(b) { return b.type !== "page" }).map(function(b) {
        var c = JSON.parse(JSON.stringify(b))
        delete c.uid
        c.indent = (c.indent || 0) + base
        return c
      })
      editor.swapBlocks([uid], list.length ? list : [{ type: "p", html: "", indent: base }])
      view.toast("Unsynced: its blocks are this page's own, here")
    })
  }

  // Blocks made a synced block: moved to a page of their own, the synced block in their place.
  function makeSynced(uids) {
    if (!page || locked || !uids.length) return
    commit()
    var ranges = editor.subtreeRanges(uids)
    var list = []
    ranges.forEach(function(r) { for (var k = r[0]; k <= r[1]; k++) list.push(editor.blockAt(k)) })
    if (list.some(function(b) { return b.type === "page" || b.type === "synced" })) { toast("A page or a synced block is among them: move it out first"); return }
    var base = Math.min.apply(null, list.map(function(b) { return b.indent || 0 }))
    var blocks = list.map(function(b) { var c = JSON.parse(JSON.stringify(b)); delete c.uid; c.indent = (c.indent || 0) - base; return c })
    var id = workspace.newSyncedPage(blocks)
    if (!id) return
    editor.swapBlocks(list.map(function(b) { return b.uid }), [{ type: "synced", indent: base, data: { page: id } }])
    markDirty()
    commit()
    toast("A synced block: copy it (\u22ee\u22ee, Ctrl+C) and paste it anywhere; changed in one, changed in all")
  }

  // "/synced": a new one, or one there is.
  function openSyncedPick(uid) {
    syncedPick.uid = uid
    var item = editor.items[uid]
    var p = item ? item.mapToItem(view, item.bx, item.height + 4) : Qt.point(view.width / 2 - 160, 140)
    syncedPick.x = Math.max(8, Math.min(view.width - syncedPick.width - 8, p.x))
    syncedPick.y = Math.max(8, Math.min(view.height - 360, p.y))
    syncedPick.open()
  }
  function putSynced(uid, pageId) {
    if (!pageId) return
    var made = editor.placeBlock(uid, { type: "synced", data: { page: pageId } })
    markDirty()
    commit()
    return made
  }

  // ---- the calendar -------------------------------------------------------------------------

  // The calendar, in place of a page, on a day ("2026-10-05"; "" today).
  function openCalendar(day, fromHistory) {
    if (!workspace) return
    commit()
    page = null
    editor.load([])
    pageDirty = false
    tagShown = ""
    libraryShown = false
    peopleShown = false
    templatesShown = false
    calendarShown = true
    var d = Dates.fromIso(day)
    // The view it was in last time (the first time it opens).
    calendarView.restoreMode(settings.calendarView)
    calendarView.show(d ? d.at : null, "")
    if (!fromHistory) {
      history = history.slice(0, historyAt + 1).concat(["calendar"]).slice(-100)
      historyAt = history.length - 1
    }
  }

  // An event to change, beside `anchor` (a repeating one's time: `day`).
  function closeEvent() { eventPop.close() }
  function openEvent(id, day, anchor) {
    if (!workspace || !workspace.eventById(id)) return
    eventPop.openFor(id, day, anchor)
  }

  // A new event, typed: on `day` (a Date), at `minutes` (or -1), beside
  // `anchor`; `done(id)` when it's made.
  function quickAdd(day, minutes, anchor, done) {
    if (!workspace) return
    quickAddPop.openFor(day, minutes, anchor, done)
  }

  // A question with a few answers ("Just this one" / "Every one"): then(value).
  function ask(question, options, then, anchor) {
    askPop.question = question
    askPop.options = options
    askPop.then = then
    var a = anchor || calendarView
    var p = a.mapToItem(view, anchor ? 0 : a.width / 2 - 140, anchor ? a.height + 6 : 120)
    askPop.x = Math.max(8, Math.min(view.width - askPop.width - 8, p.x))
    askPop.y = Math.max(8, Math.min(view.height - 200, p.y))
    askPop.open()
  }

  // An event's color: Pages' colors, recent ones, or your own.
  property string eventColorTarget: ""
  function openEventColors(id, anchor) {
    var ev = workspace ? workspace.eventById(id) : null
    if (!ev) return
    eventColorTarget = id
    colorAt = anchor.mapToItem(view, 0, anchor.height + 8)
    eventColors.currentText = ev.color
    eventColors.currentBack = ""
    eventColors.x = Math.max(8, Math.min(view.width - eventColors.width - 8, colorAt.x))
    eventColors.y = colorAt.y
    eventColors.open()
  }
  function setEventColor(color) {
    var ev = workspace ? workspace.eventById(eventColorTarget) : null
    if (!ev) return
    var e = JSON.parse(JSON.stringify(ev))
    e.color = color
    workspace.setCalendar(Calendar.withEvent(workspace.calendar, e))
  }

  // The notes for an event: its page, or a new one (from your meeting
  // template, else the Meeting notes one) called what it is and when,
  // linked to it.
  function notesForEvent(id, day) {
    var ev = workspace ? workspace.eventById(id) : null
    if (!ev) return
    if (ev.page && workspace.index.pages[ev.page] && !Workspace.inTrash(workspace.index, ev.page)) { open(ev.page); return }
    commit()
    var occ = day ? Calendar.occurrences({ events: [ev] }, Dates.fromIso(day).at, new Date(Dates.fromIso(day).at.getTime() + 86400000))[0] : null
    var at = occ ? occ.start : Dates.fromIso(ev.start).at
    var title = (ev.title || "Event") + " \u00b7 " + Dates.label(at, false, new Date())
    function link(pageId) {
      var e = JSON.parse(JSON.stringify(view.workspace.eventById(id)))
      e.page = pageId
      view.workspace.setCalendar(Calendar.withEvent(view.workspace.calendar, e))
    }
    var mine = userTemplates.filter(function(t) { return /meeting/i.test(t.title) })[0]
    if (mine) {
      workspace.pageFromTemplate(mine.id, "", title, templateFill(), function(made) {
        if (!made) return
        link(made)
        view.open(made)
      }, "")
      return
    }
    var t = Templates.forPages("meeting", Calendar.dayIso(at), function(d, pattern) { return Qt.formatDate(Templates.parse(d), pattern) })
    var p = workspace.createPage({ parent: "", title: title, icon: t.icon, blocks: t.blocks })
    if (!p) return
    link(p.id)
    open(p.id)
  }

  function exportCalendar() {
    if (!workspace) return
    workspace.exportCalendar(function(path) { if (path) view.toast("The calendar is in " + path.replace(/^.*\/Uber Notebook\//, "Uber Notebook/")) })
  }

  // ---- people -------------------------------------------------------------------------------

  // People, in place of a page: `id` picked (else the list, its search ready).
  function openPeople(id, fromHistory) {
    if (!workspace) return
    commit()
    page = null
    editor.load([])
    pageDirty = false
    tagShown = ""
    calendarShown = false
    libraryShown = false
    templatesShown = false
    peopleShown = true
    peopleView.show(id || "")
    if (!fromHistory) {
      history = history.slice(0, historyAt + 1).concat(["people" + (id ? ":" + id : "")]).slice(-100)
      historyAt = history.length - 1
    }
    if (!id) peopleView.focusSearch()
  }

  function copyText(text) {
    if (!workspace || !text) return
    workspace.files.copyText(text)
    toast("Copied " + (String(text).length > 40 ? "it" : text))
  }
  function mailTo(email) { if (workspace && email) workspace.files.openUrl("mailto:" + email) }

  // Contacts from a file (.vcf or .csv) picked: put in, then said how many;
  // done({ added, updated, first }) or done(null).
  function pickContacts(done) {
    if (!service || typeof service.pickFile !== "function") { toast("Files can't be picked here"); return }
    service.pickFile("contacts", function(path) { if (path) view.importContactsFrom(path, done) })
  }
  function importContactsFrom(path, done) {
    var before = workspace.contacts.contacts.map(function(c) { return c.id })
    workspace.importContacts(path, function(r, why) {
      if (!r) { view.toast(why || "No contacts were read"); if (done) done(null); return }
      var first = view.workspace.contacts.contacts.filter(function(c) { return before.indexOf(c.id) < 0 })[0]
      view.toast(r.added + (r.added === 1 ? " person" : " people") + " added" + (r.updated ? ", " + r.updated + " filled in" : ""))
      if (done) done({ added: r.added, updated: r.updated, first: first ? first.id : "" })
    })
  }
  function exportContacts() {
    workspace.exportContacts(function(path) { view.toast(path ? "Everyone's in " + path.replace(/^.*\/Uber Notebook\//, "Uber Notebook/") : "They couldn't be exported") })
  }

  // People for the "@" menu: [{ id, name, sub, initials, tint }].
  function findPeople(query) {
    if (!workspace) return []
    return Contacts.find(workspace.contacts, query, 6).map(function(c) {
      return { id: c.id, name: Contacts.nameOf(c), sub: Contacts.subtitle(c), initials: Contacts.initials(c), tint: Contacts.tintOf(c) }
    })
  }
  // Someone new from the "@" menu: their id.
  function makePerson(name) {
    if (!workspace || !String(name || "").trim()) return ""
    var c = { id: Contacts.newId(), name: String(name).trim(), phones: [], emails: [] }
    workspace.saveContact(c)
    return workspace.contactById(c.id) ? c.id : ""
  }
  // An email that's someone's: a link to them ("" if it's no one's).
  function personOfEmail(email) {
    var c = workspace ? Contacts.byEmail(workspace.contacts, email) : null
    return c ? Contacts.href(c.id) : ""
  }

  // ---- the Library ----------------------------------------------------------------------------

  // Everything put on the pages (links, files, videos, pictures, audio
  // notes, meetings, sketches), in place of a page; `kind` ("file"...) picked.
  function openLibrary(kind, fromHistory) {
    if (!workspace) return
    commit()
    page = null
    editor.load([])
    pageDirty = false
    tagShown = ""
    calendarShown = false
    peopleShown = false
    templatesShown = false
    libraryShown = true
    libraryView.reset(kind)
    if (!fromHistory) {
      history = history.slice(0, historyAt + 1).concat(["library"]).slice(-100)
      historyAt = history.length - 1
    }
    libraryView.focusSearch()
  }

  // ---- tags ---------------------------------------------------------------------------------

  // A tag's blocks, in place of the page.
  function openTag(name, fromHistory) {
    var n = Tags.clean(name)
    if (!workspace || !n) return
    commit()
    page = null
    editor.load([])
    pageDirty = false
    calendarShown = false
    libraryShown = false
    peopleShown = false
    templatesShown = false
    tagShown = n
    if (!fromHistory) {
      history = history.slice(0, historyAt + 1).concat(["tag:" + n]).slice(-100)
      historyAt = history.length - 1
    }
    tagView.load()
    tagView.forceActiveFocus()
  }

  // Tags for "#": those with what's typed, the most used first when nothing is.
  function findTags(query) {
    var list = Workspace.tagList(index)
    if (!String(query || "").replace(/^#/, "")) return list.slice().sort(function(a, b) { return b.blocks - a.blocks }).slice(0, 8)
    var by = {}
    list.forEach(function(t) { by[t.name] = t })
    return Tags.matching(list.map(function(t) { return t.name }), query, 8).map(function(n) { return by[n] })
  }

  // A tag's colors as it's drawn: its own (one of Pages', or one of yours as
  // its background), else a quiet gray. While its color is being picked, that.
  property var tagPreview: null
  // The tags' colors, with the one being picked.
  readonly property var tagColorsShown: {
    // (The index is the same object as it changes: its revision says when.)
    var r = workspace ? workspace.revision : 0
    var colors = workspace ? workspace.index.tagColors || {} : {}
    // (A copy: the same object again wouldn't tell what's drawn from it.)
    var c = {}
    for (var k in colors) c[k] = colors[k]
    if (!tagPreview) return c
    if (tagPreview.color) c[tagPreview.name] = tagPreview.color
    else delete c[tagPreview.name]
    return c
  }
  // (A tag with no color of its own takes the color of the tag it's in: #work/acme, #work's.)
  function tagLook(name) {
    var c = Workspace.tagColorOf(tagColorsShown, name).color
    var dark = theme.dark
    if (c) {
      var e = Docs.colorEntry(c)
      if (e) return { color: e.text[dark ? 1 : 0], background: e.background[dark ? 1 : 0] }
      var hex = Colors.normalize(c)
      if (hex) return { color: Colors.readableOn(hex, Colors.normalize(String(theme.text)) || "#000000"), background: hex }
    }
    return { color: Colors.normalize(String(theme.muted)) || "#666666", background: Colors.normalize(String(Qt.tint(theme.background, Qt.alpha(theme.text, dark ? 0.13 : 0.075)))) || "#eeeeee" }
  }
  function tagStyleOf(href) { var n = Tags.of(href); return n ? tagLook(n) : null }
  readonly property string tagColorsKey: JSON.stringify(tagColorsShown)
  onTagColorsKeyChanged: editor.restyle()

  // A block's text as the tag view shows it.
  function blockHtml(inner) {
    return Html.decorateLinks(editor.display(inner || ""), theme.accent, function(href) { return view.tagStyleOf(href) })
  }

  // A link clicked in the tag view: a page, a tag, or out.
  function openFromTag(link) { editor.openLink(link) }

  // The tag the color menu and renaming are for (the one shown, or one in the sidebar).
  property string tagTarget: ""

  function renameTag(to, name) {
    var from = name || tagTarget || tagShown
    var into = Tags.clean(to)
    if (!from || !into) return false
    // (The page open is written first, so what's being written in it is renamed too.)
    commit()
    workspace.changeTag(from, to, function(n) {
      view.toast(n ? "Renamed on " + n + (n === 1 ? " page" : " pages") : "Renamed")
      // The history says the new name.
      var h = view.history.slice()
      for (var i = 0; i < h.length; i++) if (h[i] === "tag:" + from) h[i] = "tag:" + into
      view.history = h
      if (view.tagShown === from) {
        view.tagShown = into
        view.tagView.load()
      } else if (view.page) {
        // The page open may have had it: shown as it is now.
        view.workspace.readPage(view.page.id, function(p) { if (p && view.page && view.page.id === p.id && !view.pageDirty) view.show(p) })
      }
    })
    return true
  }

  function removeTag(which) {
    var name = which || tagShown
    var info = Workspace.tagList(index).filter(function(t) { return t.name === name })[0]
    if (!info) return
    confirmRequested("Take " + info.label + " off every page?",
      "It comes off " + info.blocks + (info.blocks === 1 ? " block" : " blocks") + " on " + info.pages + (info.pages === 1 ? " page" : " pages")
        + ". Each page keeps the version before in its Page history.",
      "Take it off", function() {
        view.commit()
        view.workspace.changeTag(name, "", function(n) {
          view.toast(info.label + " is off " + n + (n === 1 ? " page" : " pages"))
          if (view.tagShown) view.tagView.load()
          else if (view.page) view.workspace.readPage(view.page.id, function(p) { if (p && view.page && view.page.id === p.id && !view.pageDirty) view.show(p) })
        })
      })
  }

  // The colors for a tag (`name`, else the one shown), under `anchor` (or
  // beside it, `side`).
  function openTagColors(anchor, name, side) {
    tagTarget = name || tagShown
    var c = (index.tagColors || {})[tagTarget] || ""
    var from = Workspace.tagColorOf(index.tagColors || {}, tagTarget).from
    colorAt = side ? anchor.mapToItem(view, anchor.width + 6, 0) : anchor.mapToItem(view, 0, anchor.height + 8)
    tagColors.currentText = c
    tagColors.currentBack = ""
    tagColors.noneLabel = from && from !== tagTarget ? "As #" + from : "Gray"
    tagColors.x = side ? colorAt.x : Math.max(12, colorAt.x - tagColors.width + anchor.width)
    tagColors.y = side ? Math.min(colorAt.y, view.height - 260) : colorAt.y
    tagColors.open()
  }

  function openTagCustom() {
    var c = (index.tagColors || {})[tagTarget] || ""
    var look = tagLook(tagTarget)
    tagCustom.recent = recentColors
    tagCustom.x = Math.max(12, Math.min(view.width - 320, tagColors.x))
    tagCustom.y = tagColors.y
    tagCustom.start("background", Colors.isHex(c) ? c : "", { text: "#" + tagTarget, fill: look.background, ownInk: "", pageInk: Colors.normalize(String(theme.text)) || "#000000" })
  }

  function openTagRename(anchor, name, side) {
    tagTarget = name || tagShown
    var p = side ? anchor.mapToItem(view, anchor.width + 6, 0) : anchor.mapToItem(view, 0, anchor.height + 8)
    tagRename.x = side ? p.x : Math.max(12, p.x - tagRename.width + anchor.width)
    tagRename.y = p.y
    tagRename.start(Workspace.tagList(index).filter(function(t) { return t.name === view.tagTarget }).map(function(t) { return t.label })[0] || "#" + tagTarget)
  }

  // A tag's menu (its ⋯ in the sidebar, or a right-click there).
  function openTagMenu(name, anchor) {
    tagTarget = name
    tagMenu.tag = name
    tagMenu.anchor = anchor
    var p = anchor.mapToItem(view, anchor.width - 20, anchor.height - 4)
    tagMenu.x = p.x
    tagMenu.y = Math.min(p.y, view.height - 200)
    tagMenu.open()
  }

  function show(p) {
    page = p
    settingTitle = true
    titleEdit.text = p.title
    settingTitle = false
    editor.load(Workspace.flatten(p))
    pageDirty = false
    titleHint = ""
    updateBlank()
    flick.contentY = 0
    findBar.refresh()
    revision++
    if (startWith && startWith.page === p.id) {
      var t = startWith.template
      startWith = null
      applyTemplate(t)
    }
  }

  function updateBlank() {
    pageBlank = page !== null && editor.model.count <= 1 && Blocks.isBlank(editor.serialize())
  }

  function pageTitleText() { return titleEdit.text }

  function focusPage(title) {
    if (!page) { view.forceActiveFocus(); return }
    if (title || (!page.title && Blocks.isBlank(editor.serialize()))) {
      titleEdit.forceActiveFocus()
      titleEdit.cursorPosition = titleEdit.length
    } else {
      view.forceActiveFocus()
    }
  }

  function markDirty() {
    pageDirty = true
    saveTimer.restart()
  }

  // The notes folder changed: nothing from the one before stays on screen,
  // or is written into this one (a change not written yet is the old
  // folder's), and Pages opens on what's here: the examples, in an empty one.
  function leaveFolder() {
    // (What agents asked about here is for this folder's pages: not asked.)
    agentAsks = []
    // (An agent at work in this folder stops, and while it does, it can't
    // change anything: it would go on in the next folder.)
    if (agentRun) {
      if (service && service.agentScope) service.agentScope.frozen = true
      agentRun.stop()
    }
    saveTimer.stop()
    pageDirty = false
    page = null
    history = []
    historyAt = -1
    tagShown = ""
    calendarShown = false
    libraryShown = false
    peopleShown = false
    templatesShown = false
    startWith = null
    pendingActivate = true
  }

  Timer {
    id: saveTimer
    interval: 700
    onTriggered: view.commit()
  }

  // Writes the open page, if it changed. Pages whose blocks came off it go to
  // the trash (and come back if their block does, with Undo).
  function commit() {
    saveTimer.stop()
    if (!pageDirty || !page || !workspace) return
    pageDirty = false
    var p = page
    var before = Workspace.childPages(p)
    var tree = Workspace.unflatten(editor.serialize(), p.id)
    p.content = tree.content
    p.blocks = tree.blocks
    p.title = Workspace.cleanTitle(titleEdit.text)
    p.modified = new Date().toISOString()
    var after = Workspace.childPages(p)
    before.forEach(function(id) {
      var e = view.workspace.index.pages[id]
      if (after.indexOf(id) < 0 && e && e.parent === p.id && !e.trashed) view.workspace.trashPage(id, true)
    })
    after.forEach(function(id) {
      var e = view.workspace.index.pages[id]
      if (e && e.trashed) view.workspace.restorePage(id, true)
    })
    workspace.savePage(p)
    revision++
  }

  // ---- making, moving and throwing away pages ------------------------------------------

  // A new page, at the top ("") or inside a page (at the end of it).
  function newPage(parentId) {
    if (!workspace) return
    commit()
    var parent = parentId && workspace.index.pages[parentId] ? parentId : ""
    // The template new pages inside this one start from.
    var start = parent ? workspace.index.pages[parent].childTemplate : ""
    if (start && workspace.index.pages[start] && Workspace.inTemplates(workspace.index, start) && !Workspace.inTrash(workspace.index, start)) {
      newPageFromTemplate(start, parent)
      return
    }
    var child = workspace.createPage({ parent: parent })
    if (!child) return
    if (parent) {
      if (page && page.id === parent) {
        editor.placeBlock(editor.uidAt(editor.model.count - 1), { type: "page", id: child.id })
        markDirty()
        commit()
      } else {
        workspace.editPage(parent, function(p) { return Workspace.appendPageBlock(p, child.id) })
      }
    }
    open(child.id, false, "title")
  }

  // "/page": a page inside this one, where the "/" was; then it opens.
  function subpageIn(uid) {
    if (!page) return
    var child = workspace.createPage({ parent: page.id })
    if (!child) return
    editor.placeBlock(uid, { type: "page", id: child.id })
    markDirty()
    commit()
    open(child.id, false, "title")
  }

  function trashPage(id) {
    if (!id || !workspace || !workspace.index.pages[id]) return
    var e = workspace.index.pages[id]
    var wasOpen = page && Workspace.withDescendants(workspace.index, id).indexOf(page.id) >= 0
    if (page && e.parent === page.id) {
      editor.removeBlocks([id])
      markDirty()
      commit()
    } else {
      commit()
      workspace.trashPage(id, false)
    }
    toast("\u201c" + (e.title || "Untitled") + "\u201d is in the trash")
    if (wasOpen) {
      pageDirty = false
      page = null
      var parent = e.parent && !Workspace.inTrash(workspace.index, e.parent) ? e.parent : ""
      if (parent) open(parent)
      else activate()
    }
  }

  function restorePage(id) {
    var e = workspace.index.pages[id]
    if (!e) return
    var onOpen = page && e.parent === page.id
    workspace.restorePage(id, onOpen)
    if (onOpen) {
      editor.placeBlock(editor.uidAt(editor.model.count - 1), { type: "page", id: id })
      markDirty()
      commit()
    }
    toast("\u201c" + (e.title || "Untitled") + "\u201d is back")
    if (!page) activate()
  }

  function deletePage(id) {
    var e = workspace.index.pages[id]
    if (!e) return
    confirmRequested("Delete \u201c" + (e.title || "Untitled") + "\u201d from Pages?",
      "It and the pages inside it leave Pages. Their files go to the .trash folder in your notebooks folder, where you can still get them back.",
      "Delete", function() { view.workspace.deleteForever(id) })
  }

  // Moves a page into another page ("" for the top).
  function movePage(id, target) {
    var e = workspace.index.pages[id]
    if (!e || e.parent === target) return
    var from = e.parent
    if (page && from === page.id) editor.removeBlocks([id])
    if (page && target === page.id) editor.placeBlock(editor.uidAt(editor.model.count - 1), { type: "page", id: id })
    if (!workspace.movePage(id, target, -1, page ? page.id : "")) return
    if (page && (from === page.id || target === page.id)) { markDirty(); commit() }
    if (page && page.id === id) { page.parent = target; markDirty(); commit() }
    var where = target ? (workspace.index.pages[target].title || "Untitled") : "the top of Pages"
    toast("Moved to " + where)
  }

  // A page dragged in the sidebar and dropped before, after or inside
  // another (or "end": the end of the top of Pages). The page open is
  // written first, and shown again as it is then; Undo puts it back.
  // `where` "project": dropped on the sidebar's Projects, it's a project.
  // `inPages`: dropped in Pages, where a project dropped is a page again.
  function dropPage(id, target, where, inPages) {
    if (!workspace || !workspace.index.pages[id]) return false
    if (where === "project") return makeProjectOf(id, true)
    var place = Workspace.dropPlace(workspace.index, id, target, where)
    if (!place) return false
    var was = Workspace.placeOf(workspace.index, id)
    var had = workspace.index.pages[id].project || null
    var unproject = !!(inPages && had)
    var moves = !(was.parent === place.parent && was.at === place.at)
    if (!moves && !unproject) return false
    commit()
    var title = workspace.index.pages[id].title || "Untitled"
    var into = place.parent ? "\u201c" + (workspace.index.pages[place.parent].title || "Untitled") + "\u201d" : "the top of Pages"
    function move(then) {
      if (!moves) { then(); return }
      workspace.placePage(id, place, function() { view.refreshOpen([was.parent, place.parent, id]); then() })
    }
    function undo() {
      view.commit()
      if (moves) view.workspace.placePage(id, was, function() { view.refreshOpen([was.parent, place.parent, id]) })
      if (unproject) view.projectOf(id, had)
    }
    if (unproject) {
      projectOf(id, null, function(ok) {
        if (!ok) { view.toast("\u201c" + title + "\u201d is locked: unlock it to make it a page again"); return }
        move(function() {
          view.expandTo(id)
          view.toastUndo("\u201c" + title + "\u201d is a page again" + (was.parent === place.parent ? "" : ", in " + into), undo)
        })
      })
      return true
    }
    move(function() {
      view.expandTo(id)
      view.toastUndo("Moved \u201c" + title + "\u201d" + (was.parent === place.parent ? "" : " into " + into), undo)
    })
    return true
  }

  // The page open shown again if one of these changed (keeping where you were on it).
  function refreshOpen(ids) {
    if (!page || ids.indexOf(page.id) < 0 || pageDirty) return
    var y = flick.contentY
    workspace.readPage(page.id, function(p) {
      if (!p || !view.page || view.page.id !== p.id || view.pageDirty) return
      var e = view.workspace.index.pages[p.id]
      if (e) p.parent = e.parent
      view.show(p)
      flick.contentY = y
    })
  }

  // Blocks moved (with what's inside them) to the end of another page.
  function moveBlocks(uids, target) {
    if (!page || !target || target === page.id) return
    editor.syncAll()
    var list = []
    editor.subtreeRanges(uids).forEach(function(r) { for (var k = r[0]; k <= r[1]; k++) list.push(editor.blockAt(k)) })
    if (list.length === 0) return
    var base = Math.min.apply(null, list.map(function(b) { return b.indent || 0 }))
    list.forEach(function(b) { b.indent = (b.indent || 0) - base })
    var name = workspace.index.pages[target] ? (workspace.index.pages[target].title || "Untitled") : ""
    commit()
    workspace.editPage(target, function(p) {
      var tree = Workspace.unflatten(Workspace.flatten(p).concat(list), p.id)
      p.content = tree.content
      p.blocks = tree.blocks
      return true
    }, function(ok) {
      if (!ok) return
      editor.removeBlocks(uids)
      view.markDirty()
      view.commit()
      view.toast("Moved to \u201c" + name + "\u201d")
    })
  }

  // ---- importing -------------------------------------------------------------------------------

  // Notes from files or folders, as pages (inside `parentId`, or at the top).
  function importPaths(paths, parentId) {
    if (!workspace || !paths || !paths.length) return
    commit()
    toast("Importing\u2026")
    workspace.importPaths(paths, parentId || "", function(r) {
      var note = r.pages ? "Imported " + r.pages + (r.pages === 1 ? " page" : " pages") : "There were no notes to import"
      if (r.skipped && r.skipped.length) note += " (" + r.skipped.length + " not: install pandoc or LibreOffice for Word files)"
      view.toast(note)
      if (r.first) view.open(r.first)
      else if (parentId && view.page && view.page.id === parentId) view.workspace.readPage(parentId, function(p) { if (p) view.show(p) })
    })
  }

  function openImport(anchor) {
    importMenu.parent = anchor
    importMenu.x = 8
    importMenu.y = -importMenu.implicitHeight - 6
    importMenu.open()
  }

  // Pasting several lines into the title: the first is the title, the rest
  // (Markdown or not) the start of the page.
  function pasteIntoTitle() {
    var text = editor.clipboardText()
    if (text.indexOf("\n") < 0) return false
    var lines = text.replace(/\r/g, "").split("\n")
    while (lines.length && !lines[0].trim()) lines.shift()
    var first = (lines.shift() || "").replace(/^\s*#{1,6}\s+/, "").trim()
    var rest = lines.join("\n")
    var read = Import.looksLikeMarkdown(rest) ? Import.fromMarkdown(rest, null, {}) : Import.fromText(rest)
    titleEdit.remove(titleEdit.selectionStart, titleEdit.selectionEnd)
    titleEdit.insert(titleEdit.cursorPosition, Workspace.cleanTitle(first))
    if (read.blocks.length) editor.insertBlocksAt(0, read.blocks)
    return true
  }

  // ---- favorites, copies, turning a block into a page -------------------------------------

  function toggleFavorite(id) {
    if (!workspace || !id) return
    workspace.toggleFavorite(id)
    toast(workspace.isFavorite(id) ? "In Favorites" : "Out of Favorites")
  }

  function duplicatePage(id) {
    if (!workspace || !id) return
    commit()
    var e = workspace.index.pages[id]
    workspace.duplicatePage(id, page ? page.id : "", function(copy) {
      if (!copy) return
      // On the open page: the copy's block right under the original's.
      if (view.page && e && e.parent === view.page.id) {
        var at = view.editor.indexOf(id)
        view.editor.placeBlock(at >= 0 ? id : view.editor.uidAt(view.editor.model.count - 1), { type: "page", id: copy })
        view.markDirty()
        view.commit()
      }
      view.open(copy)
    })
  }

  // A block (and what's inside it) as a page inside this one: its text the
  // page's title, what's inside it the page.
  function turnIntoPage(uid) {
    if (!page || locked) return
    var i = editor.indexOf(uid)
    if (i < 0) return
    editor.syncAll()
    var root = editor.blockAt(i)
    var end = editor.subtreeEnd(i)
    var kids = []
    for (var k = i + 1; k <= end; k++) {
      var b = editor.blockAt(k)
      b.indent -= root.indent + 1
      kids.push(b)
    }
    var title = Workspace.cleanTitle(Html.plainText(root.html || ""))
    var child = workspace.createPage({ parent: page.id, title: title, blocks: kids.length ? kids : undefined })
    if (!child) return
    editor.replaceSubtree(uid, { type: "page", id: child.id })
    markDirty()
    commit()
    toast("\u201c" + (title || "Untitled") + "\u201d is a page now")
  }

  // ---- your agent ---------------------------------------------------------------------------------

  // Ask agent: about the page, the blocks picked, the words selected, or the
  // empty line you're on ("line"). "auto" (Ctrl+J) works out which from
  // where you are. The page is written first, so the agent reads it as it is.
  // The box can ask for a new page instead; with no page open (the calendar,
  // People...), a new page is what it asks for. A page with a conversation
  // (kept from before, its panel closed or not) goes back to it instead, what
  // you picked going with your next message; New chat, in its panel, opens
  // the box.
  function openAgent(scope, uids) {
    if (!workspace || !workspace.ready) return
    // (One at a time: while it works, its panel.)
    if (agentRun) { agentPanel.visible = true; if (agentTalk && page && agentTalk.owner !== page.id) toast(Agent.name(agentTalk.agent) + " is still working on what you asked before"); return }
    if (page && workspace.chatFor(page.id)) { openChat(page.id, agentContext(scope, uids)); return }
    openAgentBox(scope, uids)
  }
  // The box, to ask anew.
  function openAgentBox(scope, uids) {
    if (!workspace || !workspace.ready) return
    if (!page) {
      agentPop.start({ scope: "new", blocks: [], words: "", line: "" }, null)
      return
    }
    var ctx = agentContext(scope, uids)
    commit()
    agentPop.start(ctx, { id: page.id, title: Workspace.cleanTitle(titleEdit.text) || page.title, locked: locked })
  }
  // What it's asked about, from where you are: { scope, blocks, words, line }.
  function agentContext(scope, uids) {
    var ctx = { scope: "page", blocks: [], words: "", line: "" }
    var list = uids || []
    if (scope === "blocks" && list.length) {
      ctx = { scope: "blocks", blocks: list.slice(), words: "", line: "" }
    } else if (scope === "line" && list.length) {
      ctx = { scope: "line", blocks: [], words: "", line: list[0] }
    } else if (scope === "words" || scope === "auto") {
      var item = editor.focusUid ? editor.items[editor.focusUid] : null
      var words = item && item.isText ? String(item.edit.selectedText || "").replace(/[\u2028\u2029]/g, "\n") : ""
      if (editor.selectedList.length > 0) ctx = { scope: "blocks", blocks: editor.selectedList.slice(), words: "", line: "" }
      else if (words.trim()) ctx = { scope: "words", blocks: [editor.focusUid], words: words, line: "" }
      else if (scope === "auto" && item && item.isText && !locked && item.edit.length === 0 && Html.plainText(editor.htmls[editor.focusUid] || "") === "")
        ctx = { scope: "line", blocks: [], words: "", line: editor.focusUid }
    }
    return ctx
  }

  // What you asked, handed to your agent with where you are: Claude Code,
  // Grok and Codex work here, in a panel on the page; the others in a terminal.
  // (`terminal`: asked in a terminal, though it could work here.)
  function askAgent(request, terminal) {
    if (agentPop.mode === "new") askAgentForPage(agentPop.agent, request, agentPop.place === "inside" && agentPop.onPage ? agentPop.onPage.id : "", terminal)
    else askAgentWith(agentPop.agent, request, agentPop.ask, request, terminal)
  }
  // `label`: what the panel says you asked (the request itself, or a
  // shorter name for a long one).
  function askAgentWith(agent, request, ctx, label, terminal) {
    if (!page || !workspace) return
    var here = !terminal && Agent.runsHere(agent) && typeof workspace.files.stream === "function"
    if (here && agentRun) { agentPanel.visible = true; toast(Agent.name(agent) + " is still working on what you asked before"); return }
    // (A new conversation: a folder of its own.)
    if (here) newAgentFolder()
    // (A page made for the last one: kept if it's this one, now asked about.)
    settleAgentPage(agentPage !== null && agentPage.id === page.id)
    commit()
    function promptFor(inPanel) {
      return Agent.prompt({
        request: request, page: { id: page.id, title: Workspace.cleanTitle(titleEdit.text) || page.title },
        scope: ctx.scope, blocks: ctx.blocks, words: ctx.words, line: ctx.line,
        skill: service && service.skillPath ? service.skillPath : "", here: inPanel, dir: inPanel ? agentDir() : "", agent: agent
      })
    }
    var prompt = promptFor(here)
    if (here) { runHere(agent, label || request, prompt, { picked: pickedKey(ctx), terminalPrompt: promptFor(false) }); return }
    workspace.files.launchAgent(prompt)
    toast("Asked " + (Agent.name(agent) || "your agent") + ": it's working in a terminal, and what it changes shows up here")
  }

  // A new page for what you asked: made here first (at the top of Pages, as
  // Ctrl+N makes one, or inside a page) and opened, then your agent writes
  // it there, so it's where you chose, not somewhere else.
  function askAgentForPage(agent, request, parentId, terminal) {
    if (!workspace || !workspace.ready) return
    var here = !terminal && Agent.runsHere(agent) && typeof workspace.files.stream === "function"
    if (here && agentRun) { agentPanel.visible = true; toast(Agent.name(agent) + " is still working on what you asked before"); return }
    // (A new conversation: a folder of its own.)
    if (here) newAgentFolder()
    // (The one made last time: kept if it's where this one goes; gone if
    // it's still empty, and then you were where you were before it.)
    var prev = agentPage
    var onPrev = prev !== null && page !== null && page.id === prev.id
    settleAgentPage(prev !== null && parentId === prev.id, true)
    commit()
    var from = page ? page.id : onPrev ? prev.from : ""
    var parent = parentId && workspace.index.pages[parentId] ? parentId : ""
    var child = workspace.createPage({ parent: parent })
    if (!child) return
    if (parent) {
      if (page && page.id === parent) {
        editor.placeBlock(editor.uidAt(editor.model.count - 1), { type: "page", id: child.id })
        markDirty()
        commit()
      } else {
        workspace.editPage(parent, function(p) { return Workspace.appendPageBlock(p, child.id) })
      }
    }
    open(child.id, false)
    function promptFor(inPanel) {
      return Agent.prompt({
        request: request, scope: "new", page: { id: child.id, title: "" },
        into: parent ? { id: parent, title: workspace.index.pages[parent].title } : null,
        skill: service && service.skillPath ? service.skillPath : "", here: inPanel, dir: inPanel ? agentDir() : "", agent: agent
      })
    }
    var prompt = promptFor(here)
    if (here) {
      agentPage = { id: child.id, from: from }
      runHere(agent, request, prompt, { owner: child.id, terminalPrompt: promptFor(false) })
      return
    }
    workspace.files.launchAgent(prompt)
    toast("Asked " + (Agent.name(agent) || "your agent") + ": it's writing the new page in a terminal, and it shows up here as it goes")
  }

  // The page made for what you asked last, while its panel's up: { id,
  // from (the page you were on) }. Settled when the panel's closed or you
  // ask again: still empty (it couldn't, or was stopped), it goes, and
  // you're back where you were (`stay`: the one asking goes on from there
  // itself); `keep` (a terminal's to write it, or it's what you're asking
  // about now), it stays.
  property var agentPage: null
  function settleAgentPage(keep, stay) {
    var made = agentPage
    agentPage = null
    if (!made || keep || !workspace || !workspace.index.pages[made.id]) return
    if (page && page.id === made.id) commit()
    var p = workspace.readPageNow(made.id)
    if (!p || p.title || p.icon || p.cover || !Blocks.isBlank(Workspace.flatten(p))) return
    var e = workspace.index.pages[made.id]
    var wasOpen = page !== null && page.id === made.id
    if (page && e.parent === page.id) {
      editor.removeBlocks([made.id])
      markDirty()
      commit()
    } else {
      workspace.trashPage(made.id, false)
    }
    workspace.deleteForever(made.id)
    if (wasOpen) {
      pageDirty = false
      page = null
      if (!stay) {
        if (made.from && workspace.index.pages[made.from] && !Workspace.inTrash(workspace.index, made.from)) open(made.from)
        else activate()
      }
    }
    toast("Nothing was written on the new page, so it's gone")
  }

  // ---- your agent, working here (Claude Code, Grok, Codex: no terminal) ----

  // While it works: { stop() }; and what it was asked, as a terminal's agent
  // is asked it, for a terminal instead.
  property var agentRun: null
  property string agentRunPrompt: ""
  // The page's conversation with your agent, kept (Workspace's chats), or null.
  readonly property var pageChat: { var r = workspace ? workspace.chatsRevision : 0; return page && workspace ? workspace.chatFor(page.id) : null }
  // The conversation in the panel: { agent, id (its session: one made for
  // Claude Code or Grok; Codex's, once its first line says), owner (the page
  // it's kept with: where it started), page (the page it last heard about),
  // picked (the blocks or words it last heard about, pickedKey's) }. It's
  // kept with its page as it goes (Workspace's chats): closed, it's gone
  // back to from that page (openChat); a reply goes on with it.
  property var agentTalk: null
  // What you picked when you went back to it (Ctrl+J with words selected,
  // /agent on an empty line...): it goes with your next message.
  property var agentPending: null
  // A new conversation (`o.picked`: what it's told is picked; `o.owner`: the
  // page it's kept with, the one open by default), or (`o.reply`) the next
  // turn of this one; `o.fresh`: in a new session, told what was said (one
  // that never said its session, or lost it).
  // The panel's agent works in a folder of its own (where the Markdown it
  // hands Uber Notebook's commands goes).
  //
  // A folder of its own for each conversation ("c-" and 12 hex, kept with
  // the conversation): what an agent leaves there (settings, instructions,
  // links) stays with that conversation, and never reaches the next, or
  // another agent's. Ones not used for two days go.
  property string agentFolder: ""
  function newAgentFolder() {
    agentFolder = "c-" + Workspace.uuid4().replace(/-/g, "").slice(0, 12)
    var base = agentBase()
    if (base && workspace && workspace.files) workspace.files.exec(["/usr/bin/find", base, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-name", "c-*", "-mmin", "+2880",
      "-exec", "/usr/bin/rm", "-rf", "--", "{}", "+"], null, { okCodes: [0, 1], timeoutMs: 20000 })
    return agentFolder
  }
  function agentBase() {
    return workspace && workspace.files && workspace.files.runtimeDir ? workspace.files.runtimeDir + "/uber-notebook-agent" : ""
  }
  function agentDir() {
    var base = agentBase()
    if (!base) return ""
    if (!Agent.isConversationFolder(agentFolder)) newAgentFolder()
    return base + "/" + agentFolder
  }

  // What an agent's work needs your yes for, asked in the panel: Uber
  // Notebook contacting a site for it (Api.agentLink), or one of its own
  // tools beyond its rules (Claude Code's: agentAsked). [{ key, agent,
  // action, target, text, always, runs, nos, owner }]: `text` what it wants
  // to do, `always` what Always says ("": once only); one question for each
  // key however often it comes (Uber Notebook's own: agent, action and site),
  // each waiting run going when you answer (by its key, as the panel gives
  // back a copy). Always keeps your yes in settings (Permissions.js), where
  // an agent can't change it; `owner`: the run it's for, whose questions go
  // with it.
  property var agentAsks: []
  function askAgentPermission(req) {
    if (!req || !req.agent || typeof req.run !== "function") return false
    if (!req.text && !req.target) return false
    var key = req.key || (req.agent + " " + req.action + " " + req.target)
    var list = agentAsks.slice()
    var same = list.filter(function(a) { return a.key === key })[0]
    if (same) {
      same.runs.push(req.run)
      if (typeof req.no === "function") same.nos.push(req.no)
    } else {
      list.push({ key: key, agent: req.agent, action: String(req.action || ""), target: String(req.target || ""),
        text: req.text ? String(req.text) : "have Uber Notebook contact " + req.target + (req.why ? ", " + req.why : ""),
        detail: Agent.visible(req.detail || ""),
        always: req.always !== undefined ? String(req.always) : "Always for " + req.target,
        // (For this conversation: `grant`, said `conversation`; "" for none.)
        grant: String(req.grant || ""), conversation: req.grant ? String(req.conversation || "Allow for this conversation") : "",
        runs: [req.run], nos: typeof req.no === "function" ? [req.no] : [], owner: req.owner || null })
    }
    agentAsks = list
    agentPanel.visible = true
    return true
  }
  function answerAgentAsk(key, how) {
    var ask = agentAsks.filter(function(a) { return a.key === key })[0]
    if (!ask) return
    agentAsks = agentAsks.filter(function(a) { return a.key !== key })
    function each(fns, arg) { fns.forEach(function(f) { try { f(arg) } catch (e) { console.warn("Uber Notebook: after you answered: " + e) } }) }
    if (how !== "once" && !(how === "always" && ask.always) && !(how === "conversation" && ask.grant)) { each(ask.nos); return }
    // For this conversation: kept with it (agentTalk.grants, which its runs'
    // scope shares), and what else waits on the same, allowed now too.
    if (how === "conversation") {
      if (agentTalk) {
        var g = agentTalk.grants || {}
        g[ask.grant] = true
        agentTalk.grants = g
      }
      var same = agentAsks.filter(function(a) { return a.agent === ask.agent && a.grant === ask.grant })
      agentAsks = agentAsks.filter(function(a) { return same.indexOf(a) < 0 })
      same.forEach(function(a) { each(a.runs) })
      each(ask.runs)
      return
    }
    var hosts = [ask.target]
    if (how === "always" && ask.action && service && typeof service.setSetting === "function") {
      var next = Permissions.withAllowed(settings.agentPermissions || [], ask.agent, ask.action, ask.target)
      service.setSetting("agentPermissions", next)
      hosts = next.filter(function(r) { return r.agent === ask.agent && r.action === ask.action }).map(function(r) { return r.target })
      // (Others waiting on the same: allowed now too.)
      var also = agentAsks.filter(function(a) { return a.agent === ask.agent && a.action === ask.action && a.target === ask.target })
      agentAsks = agentAsks.filter(function(a) { return also.indexOf(a) < 0 })
      also.forEach(function(a) { each(a.runs, hosts) })
    }
    each(ask.runs, hosts)
  }
  // An agent asking for a tool beyond its rules, as it works (Claude Code,
  // Grok; `run`: its stream): allowed at once if you've said Always to the
  // like, else asked.
  function agentAsked(agent, ev, run) {
    var a = Agent.askOf(ev.tool, ev.input, ev.title)
    function reply(allow) { if (run && typeof run.send === "function") run.send(Agent.answerFor(agent, ev, allow)) }
    if (a.action && Permissions.allowed(settings.agentPermissions || [], agent, a.action, a.target)) { reply(true); return }
    if (a.grant && agentTalk && agentTalk.grants && agentTalk.grants[a.grant] === true) { reply(true); return }
    askAgentPermission({ key: "tool " + ev.id, agent: agent, action: a.action, target: a.target, text: a.text, detail: a.detail || "",
      always: a.always, grant: a.grant || "", conversation: a.conversation || "", owner: run,
      run: function() { reply(true) }, no: function() { reply(false) } })
  }
  // A run's questions, gone with it.
  function dropAgentAsks(run) {
    if (run) agentAsks = agentAsks.filter(function(a) { return a.owner !== run })
  }

  // While it works, Uber Notebook's commands read and change your notes, not
  // Uber Notebook's settings, profiles or backups, and read files only from
  // its folder (Scope.js, Service.qml).
  function agentScope(agent, dir) {
    // (The conversation's grants go with it: a removal you've allowed for
    // this conversation isn't asked again, Api.agentRemoval.)
    if (service && typeof service.beginAgentScope === "function") service.beginAgentScope(Agent.name(agent), dir, agent, agentTalk ? agentTalk.grants : null)
  }
  function agentScopeEnd() {
    if (service && typeof service.endAgentScope === "function") service.endAgentScope()
  }

  function runHere(agent, request, prompt, o) {
    var opts = o || {}
    var files = workspace.files
    // (A reply goes on in its conversation's folder; one kept from before it
    // had them, in a new one.)
    if (opts.reply) {
      if (agentTalk && Agent.isConversationFolder(agentTalk.folder)) agentFolder = agentTalk.folder
      else newAgentFolder()
    }
    var dir = agentDir()
    // The model and effort you chose for it (Settings → AI, or the box).
    var choice = { model: settings[agent + "Model"] || "", effort: settings[agent + "Effort"] || "" }
    var choiceText = ""
    if (typeof files.agentModels === "function") files.agentModels(agent, function(list) { choiceText = Agent.choiceLabel(list, choice.model, choice.effort) })
    var owner = opts.owner || (page ? page.id : "")
    // (A conversation's grants, for this conversation: Allow shell..., kept with it.)
    if (!opts.reply) agentTalk = { agent: agent, id: "", owner: owner, page: owner, picked: opts.picked || "", grants: {}, folder: agentFolder }
    if (!agentTalk.grants) agentTalk.grants = {}
    agentTalk.folder = agentFolder
    var talk = agentTalk
    if (!opts.reply || opts.fresh) talk.id = Agent.newSessionId(agent)
    if (opts.reply) agentPanel.next(request)
    else agentPanel.begin(Agent.name(agent), request, choiceText)
    agentPanel.canReply = true
    // (For a terminal instead: the whole of it, for a reply.)
    agentRunPrompt = opts.reply && !opts.fresh ? recapPrompt(request, undefined, true) : (opts.terminalPrompt || prompt)
    saveChat()
    var retried = false
    // (Its program and folder, once found.)
    var where = null
    function go(text, session) {
      var lost = false
      var argv = Agent.command(agent, text, choice, session, where)
      if (!argv) { view.agentRun = null; view.agentScopeEnd(); agentPanel.end(127, Agent.name(agent) + " couldn't be started"); view.saveChat(); return }
      // (Claude Code takes its request on its input, and your answers to
      // what it asks as it works; Grok, over ACP, hello, its session, then
      // the request, and your answers; the input's closed once it's answered.)
      var first = Agent.input(agent, text)
      var run = null
      run = files.stream(argv, function(line) {
        Agent.fromLine(agent, line).forEach(function(ev) {
          if (ev.kind === "ask") { view.agentAsked(agent, ev, run); return }
          if (ev.kind === "control") { if (run && run.send) run.send(Agent.unsupportedFor(agent, ev.id)); return }
          if (ev.kind === "acp") { if (run && run.send) run.send(Agent.acpSession(dir, session)); return }
          if (ev.kind === "start" && agent === "grok") {
            var sid = ev.session || (session && session.resume ? session.id : "")
            if (!sid) { if (run && run.closeInput) run.closeInput(); agentPanel.take({ kind: "failed", text: "Grok didn't start its session" }); return }
            if (run && run.send) run.send(Agent.acpPrompt(sid, text))
          }
          if ((ev.kind === "done" || ev.kind === "failed") && run && run.closeInput) run.closeInput()
          // (Codex names its conversation as it starts.)
          if (ev.kind === "start" && ev.session && !talk.id) { talk.id = ev.session; view.saveChat() }
          if (ev.kind === "failed" && session.resume && Agent.lostSession(ev.text)) { lost = true; return }
          agentPanel.take(ev)
        })
      }, function(code, errors) {
        // (The conversation it was in is gone, cleared out or on another
        // computer: a new one, told what was said.)
        if (session.resume && !retried && (lost || (code !== 0 && Agent.lostSession(errors)))) {
          retried = true
          view.dropAgentAsks(run)
          talk.id = Agent.newSessionId(agent)
          agentPanel.again()
          go(view.recapPrompt(request), { id: talk.id, resume: false })
          return
        }
        view.dropAgentAsks(run)
        view.agentRun = null
        view.agentScopeEnd()
        agentPanel.end(code, Agent.failureText(agent, code, errors))
        view.saveChat()
      }, { cwd: dir, input: first !== "", env: Agent.env(agent) })
      view.agentRun = run
      if (first && run && run.send) run.send(first)
    }
    agentRun = { stop: function() { view.agentRun = null; view.agentScopeEnd(); agentPanel.end(-1, ""); view.saveChat() } }
    agentScope(agent, dir)
    files.mkdirs([dir, dir + "/.grok"], function() {
      if (!view.agentRun) return
      // Its program, found where it's installed and checked, run by that
      // full path; Grok's sandbox, in its folder.
      files.agentPath(agent, function(exe) {
        if (!view.agentRun) return
        if (!exe) {
          view.agentRun = null
          view.agentScopeEnd()
          agentPanel.end(127, Agent.name(agent) + " isn't installed where Uber Notebook can find it (on your PATH, owned by you or root, and not changeable by anyone else)")
          view.saveChat()
          return
        }
        where = { exe: exe, dir: dir, skill: service && typeof service.skillDir === "string" ? service.skillDir : "", helper: files.filesHelper || "" }
        function start() { if (view.agentRun) go(prompt, { id: talk.id, resume: !!opts.reply && !opts.fresh }) }
        // (Grok's sandbox profile, written by the files helper, never through
        // a link left there; it doesn't start without it.)
        if (agent === "grok") files.putFile(dir, ".grok/sandbox.toml", Agent.grokSandbox(files.runtimeDir), function(ok) {
          if (ok) { start(); return }
          if (!view.agentRun) return
          view.agentRun = null
          view.agentScopeEnd()
          agentPanel.end(127, "Grok's sandbox couldn't be set up in its folder")
          view.saveChat()
        })
        else start()
      })
    })
  }
  function stopAgent() { if (agentRun) agentRun.stop() }

  // The conversation, kept with its page as it is now.
  function saveChat() {
    var talk = agentTalk
    if (!talk || !talk.owner || !workspace || !workspace.index.pages[talk.owner]) return
    workspace.setChat(talk.owner, { agent: talk.agent, session: talk.id, page: talk.page, picked: talk.picked, folder: talk.folder || "",
      updated: new Date().toISOString(), turns: agentPanel.transcript() })
  }

  // Back to the page's conversation (`ctx`: what you picked, to go with your
  // next message), in its panel, the reply box ready.
  function openChat(owner, ctx) {
    var chat = workspace ? workspace.chatFor(owner) : null
    if (!chat) return false
    if (!agentTalk || agentTalk.owner !== owner || !agentPanel.visible) {
      agentTalk = { agent: chat.agent, id: chat.session, owner: owner, page: chat.page || owner, picked: chat.picked || "", folder: chat.folder || "", grants: {} }
      var choice = { model: settings[chat.agent + "Model"] || "", effort: settings[chat.agent + "Effort"] || "" }
      agentPanel.show(Agent.name(chat.agent), "", chat.turns)
      var files = workspace.files
      if (typeof files.agentModels === "function") files.agentModels(chat.agent, function(list) { agentPanel.choiceText = Agent.choiceLabel(list, choice.model, choice.effort) })
    }
    agentPanel.canReply = true
    agentPending = ctx && (ctx.scope === "blocks" || ctx.scope === "words" || ctx.scope === "line") ? ctx : null
    agentPanel.contextNote = agentPending === null ? ""
      : agentPending.scope === "blocks" ? (agentPending.blocks.length === 1 ? "The block you picked goes with it" : "The " + agentPending.blocks.length + " blocks you picked go with it")
      : agentPending.scope === "words" ? "The words you selected go with it"
      : "What it writes goes on the empty line you're on"
    Qt.callLater(function() { agentPanel.focusReply() })
    return true
  }
  // Another conversation: the box, to ask anew (the one before stays kept
  // till the new one starts).
  function newChat() {
    if (agentRun) return
    agentTalk = null
    agentPending = null
    agentPanel.visible = false
    settleAgentPage(false)
    openAgentBox("auto")
  }
  // A conversation started anew, told what was said (`turns`: its panel's,
  // the ones before this request).
  // (`terminal`: as a terminal's agent is told it.)
  function recapPrompt(request, turns, terminal) {
    var talk = agentTalk
    var here = page ? { id: page.id, title: Workspace.cleanTitle(titleEdit.text) || page.title }
      : talk && workspace.index.pages[talk.owner] ? { id: talk.owner, title: workspace.index.pages[talk.owner].title } : { id: "", title: "" }
    return Agent.prompt({ request: request, page: here, scope: "page", earlier: turns || agentPanel.history,
      skill: service && service.skillPath ? service.skillPath : "", here: !terminal, dir: terminal ? "" : agentDir(), agent: talk ? talk.agent : "" })
  }

  // What you say back, in the same conversation: where you are now when
  // that's changed since it last heard (another page; blocks or words you
  // picked, or what you picked when you went back to it), then your words.
  // One that never said which conversation it was (Codex, stopped before
  // its first line): a new session, told what was said.
  function replyToAgent(text) {
    var t = String(text || "").trim()
    var talk = agentTalk
    if (!t || agentRun || !talk || !workspace) return
    commit()
    var pending = agentPending
    agentPending = null
    agentPanel.contextNote = ""
    if (!Agent.isSessionId(talk.id)) {
      runHere(talk.agent, t, recapPrompt(t, agentPanel.transcript()), { reply: true, fresh: true, terminalPrompt: recapPrompt(t, agentPanel.transcript(), true) })
      return
    }
    var ctx = pending || pickedNow()
    var key = pickedKey(ctx)
    var here = page ? { id: page.id, title: Workspace.cleanTitle(titleEdit.text) || page.title } : null
    var prompt = Agent.reply({ reply: t, page: here, moved: here !== null && here.id !== talk.page,
      scope: pending || key !== talk.picked ? ctx.scope : "", blocks: ctx.blocks, words: ctx.words, line: ctx.line })
    if (here) talk.page = here.id
    talk.picked = key
    runHere(talk.agent, t, prompt, { reply: true })
  }
  // What's picked on the page now: blocks, or words in one ({ scope: "" }
  // for neither).
  function pickedNow() {
    if (editor.selectedList.length > 0) return { scope: "blocks", blocks: editor.selectedList.slice(), words: "" }
    var item = editor.focusUid ? editor.items[editor.focusUid] : null
    var words = item && item.isText ? String(item.edit.selectedText || "").replace(/[\u2028\u2029]/g, "\n") : ""
    if (words.trim()) return { scope: "words", blocks: [editor.focusUid], words: words }
    return { scope: "", blocks: [], words: "" }
  }
  function pickedKey(ctx) {
    if (!ctx) return ""
    if (ctx.scope === "blocks") return "blocks:" + (ctx.blocks || []).join(",")
    if (ctx.scope === "words") return "words:" + (ctx.blocks || [])[0] + ":" + ctx.words
    return ""
  }

  // ---- commands (an agent, a script) -----------------------------------------------------------

  // What a command adds to the page open here goes in at its end (before
  // the empty line it ends with), as one step you can undo, the cursor
  // staying where it is. true, "locked", or false when it's another page.
  function appendFromCommand(id, blocks) {
    if (!page || page.id !== id) return false
    if (locked) return "locked"
    var at = editor.model.count
    var lastUid = editor.uidAt(at - 1)
    var last = at > 0 ? editor.blockAt(at - 1) : null
    if (last && last.type === "p" && last.indent === 0 && Html.plainText(last.html || "") === ""
        && !(editor.items[lastUid] && editor.items[lastUid].edit.length > 0)) at--
    editor.insertBlocksAt(at, blocks, true)
    markDirty()
    commit()
    return true
  }

  // A command changing a block on the page open here: the block (and what's
  // inside it) replaced, or blocks put in after it, as one step you can
  // undo. true, "locked", or false when it's another page.
  function replaceFromCommand(id, change) {
    if (!page || page.id !== id) return false
    if (locked) return "locked"
    if (editor.indexOf(change.block) < 0) return false
    editor.replaceWithBlocks(change.block, change.blocks)
    markDirty()
    commit()
    return true
  }

  function insertFromCommand(id, change) {
    if (!page || page.id !== id) return false
    if (locked) return "locked"
    if (editor.indexOf(change.block) < 0) return false
    editor.insertAfterBlock(change.block, change.blocks)
    markDirty()
    commit()
    return true
  }

  // A page a command made inside the page open here: its block goes in
  // there the same way.
  function pageAddedInto(parentId, childId) {
    if (!page || page.id !== parentId) return false
    return appendFromCommand(parentId, [{ type: "page", id: childId, indent: 0 }]) === true
  }

  // ---- templates -----------------------------------------------------------------------------

  readonly property var templates: Templates.TEMPLATES.filter(function(t) { return t.id !== "blank" })
  // Your own templates (pages kept apart): [{ id, title, icon }].
  readonly property var userTemplates: { var r = workspace ? workspace.revision : 0; return workspace ? Workspace.templates(workspace.index) : [] }

  // ---- your own templates ------------------------------------------------------------------

  // What's written in a template, filled in now ({{date}}...).
  function templateFill() {
    var now = new Date()
    return function(text, html) { return Templates.fill(text, html, now, function(d, pattern) { return Qt.formatDate(Templates.parse(d), pattern) }) }
  }

  // A template used on the page open: on a blank page, it's what the page
  // is ("replace"); else its blocks go in after the block you're in
  // ("insert"). The pages in it are made inside this one. Undo takes the
  // blocks back off.
  function useTemplateHere(template, mode, afterUid) {
    if (!page || locked || !workspace) return
    commit()
    var pageId = page.id
    var atUid = afterUid || editor.focusUid
    workspace.useTemplate(template, pageId, templateFill(), function(top) {
      if (!view.page || view.page.id !== pageId) return
      if (mode === "replace") {
        editor.replaceAll(top.blocks.length ? top.blocks : [{ type: "p", html: "", indent: 0 }])
        if (!view.page.icon && top.icon) view.page.icon = Workspace.cleanIcon(top.icon)
        if (!view.page.cover && top.cover) view.page.cover = Workspace.cleanCover(top.cover)
        if (top.format) {
          var f = {}
          for (var k in view.page.format) f[k] = view.page.format[k]
          var keys = ["font", "width", "size"]
          keys.forEach(function(key) { if (top.format[key]) f[key] = top.format[key] })
          view.page.format = Workspace.cleanFormat(f)
        }
        if (top.project && !view.page.project) view.page.project = Workspace.cleanProject(top.project)
        if (!titleEdit.text.trim() && top.title) titleEdit.text = top.title
      } else {
        var i = editor.indexOf(atUid)
        var at = i >= 0 ? editor.subtreeEnd(i) + 1 : editor.model.count
        var base = i >= 0 ? editor.model.get(i).indent : 0
        var list = top.blocks.slice()
        // (Not the empty line a template ends with.)
        var tail = list[list.length - 1]
        if (list.length > 1 && tail && tail.type === "p" && Html.plainText(tail.html || "") === "") list.pop()
        list.forEach(function(b) { b.indent = (b.indent || 0) + base })
        editor.insertBlocksAt(at, list, false)
      }
      view.markDirty()
      view.revision++
    }, function(top) {
      if (!top) { view.toast("That template isn't there any more"); return }
      view.commit()
    })
  }

  // A new page from a template, inside `parentId` ("" at the top), opened.
  function newPageFromTemplate(template, parentId) {
    if (!workspace) return
    commit()
    var parent = parentId && workspace.index.pages[parentId] ? parentId : ""
    var openHere = page && page.id === parent ? parent : ""
    workspace.pageFromTemplate(template, parent, "", templateFill(), function(id) {
      if (!id) { view.toast("That template isn't there any more"); return }
      if (openHere && view.page && view.page.id === openHere) {
        editor.placeBlock(editor.uidAt(editor.model.count - 1), { type: "page", id: id })
        view.markDirty()
        view.commit()
      }
      view.open(id)
    }, openHere)
  }

  // A page saved as a template (a copy of it, and the pages in it).
  function saveAsTemplate(id) {
    if (!workspace || !workspace.index.pages[id]) return
    commit()
    var title = workspace.index.pages[id].title || "Untitled"
    workspace.saveAsTemplate(id, function(made) {
      if (!made) { view.toast("It couldn't be saved as a template"); return }
      view.toastUndo("\u201c" + title + "\u201d is a template: in Templates at the sidebar's foot", function() { view.workspace.trashPage(made, false) })
    })
  }

  // A new page from a template (Templates): one of yours by its id, or one
  // of Uber Notebook's ("daily"...), put on it once it's open.
  property var startWith: null
  function newPageWith(template) {
    if (!workspace) return
    if (Workspace.isUuid(template)) { newPageFromTemplate(template, ""); return }
    commit()
    var child = workspace.createPage({ parent: "" })
    if (!child) return
    startWith = { page: child.id, template: template }
    open(child.id)
  }

  // A new, empty template, opened to write.
  function newTemplate() {
    if (!workspace) return
    commit()
    var p = workspace.newTemplate()
    if (p) open(p.id, false, "title")
  }

  // The template a page is (or is in), or "".
  function templateRoot(id) {
    var ix = workspace ? workspace.index : null
    var p = id
    var seen = {}
    while (ix && p && ix.pages[p] && !seen[p]) {
      if (ix.pages[p].template) return p
      seen[p] = true
      p = ix.pages[p].parent
    }
    return ""
  }

  // A template, a page again (in the tree, at the top).
  function untemplate(id) {
    if (!workspace || !workspace.index.pages[id]) return
    commit()
    workspace.setTemplate(id, false)
    revision++
    toastUndo("\u201c" + (workspace.index.pages[id].title || "Untitled") + "\u201d is a page again, in Pages", function() { view.workspace.setTemplate(id, true); view.revision++ })
  }

  // Your templates to pick from: "insert" (here, after the block you're
  // in), "newIn" (a new page inside `pageId`), "child" (what new pages
  // inside `pageId` start from).
  function openTemplatePick(mode, pageId, anchor) {
    if (mode !== "child" && userTemplates.length === 0) { toast("No templates yet: Save as template, in a page's \u22ef menu"); return }
    templatePick.mode = mode
    templatePick.pageId = pageId || ""
    var a = anchor || main
    var at = a.mapToItem(view, a === main ? main.width / 2 - 160 : 0, a === main ? 120 : a.height + 4)
    templatePick.x = Math.max(8, Math.min(view.width - templatePick.width - 8, at.x))
    templatePick.y = Math.max(8, Math.min(view.height - 300, at.y))
    templatePick.open()
  }

  // A blank page made from a template: its blocks, and its title and icon
  // if it has none yet. Undo takes the blocks back off.
  function applyTemplate(id) {
    if (!page || locked || !pageBlank) return
    // One of your own.
    if (String(id).indexOf("tpl:") === 0) { useTemplateHere(String(id).slice(4), "replace"); return }
    var t = Templates.forPages(id, Templates.iso(new Date()), function(d, pattern) { return Qt.formatDate(Templates.parse(d), pattern) })
    editor.replaceAll(t.blocks)
    if (!page.icon && t.icon) page.icon = Workspace.cleanIcon(t.icon)
    // A project plan is a project.
    if (id === "project" && !page.project) page.project = { status: "active", due: "" }
    if (!titleEdit.text.trim() && t.title) titleEdit.text = t.title
    titleHint = t.hint
    markDirty()
    revision++
    if (!titleEdit.text.trim() && t.hint) { titleEdit.forceActiveFocus(); titleEdit.cursorPosition = 0 }
  }

  // ---- audio notes and dictation -----------------------------------------------------------

  // The microphone (Recorder.qml, through the service).
  readonly property var recorder: service && service.recorder ? service.recorder : null
  // The audio notes being worked on: { uid: "transcribe" or "louder" }.
  property var audioWork: ({})
  function setAudioWork(uid, what) {
    var t = {}
    for (var k in audioWork) if (k !== uid) t[k] = audioWork[k]
    if (what) t[uid] = what
    audioWork = t
  }

  // An audio note's file.
  function audioPath(src) { return workspace && workspace.folder ? workspace.folder + "/" + src : "" }

  // An audio note changed: on the page open (as a step to undo), or in its
  // page's file. done(ok).
  function updateAudio(pageId, uid, fn, done) {
    if (page && page.id === pageId && editor.indexOf(uid) >= 0) {
      var ok = editor.setAudio(uid, fn(editor.audioOf(uid) || Audio.make()))
      if (done) done(ok)
      return
    }
    if (!workspace || !workspace.index.pages[pageId]) { if (done) done(false); return }
    workspace.editPage(pageId, function(p) {
      var b = p.blocks ? p.blocks[uid] : null
      if (!b || b.type !== "audio") return false
      b.audio = Audio.clean(fn(Audio.clean(b.audio) || Audio.make()))
      return true
    }, function(ok) { if (done) done(ok) })
  }

  // Recording into an audio note (its button, or "/audio"). When it's done,
  // it's written out, as Settings has it.
  function recordAudio(uid) {
    if (!recorder || !page || locked || !audioPath("assets")) return
    var name = Audio.fileName(new Date())
    var pageId = page.id
    var problem = recorder.start("audio", uid, audioPath("assets/" + name), function(ok, r) {
      if (!ok) { if (!r.canceled) view.toast(r.problem || "Nothing was recorded"); return }
      view.updateAudio(pageId, uid, function(a) {
        a.src = "assets/" + name
        a.duration = r.duration
        a.peaks = r.peaks
        a.transcript = ""
        a.open = true
        return a
      }, function(saved) {
        if (!saved) { view.toast("Its note is gone: the recording is in Pages/assets/" + name); return }
        if (view.settings.audioTranscribe !== false && view.recorder.canTranscribe) view.transcribeAudio(pageId, uid)
      })
    })
    if (problem) { toast(problem); return }
    var item = editor.items[uid]
    if (item && item.audioView) item.audioView.takeKeys()
  }

  // What was said in an audio note, written out by voxtype.
  function transcribeAudio(pageId, uid) {
    var a = page && page.id === pageId ? editor.audioOf(uid) : null
    if (!a || !a.src || !recorder || audioWork[uid]) return
    setAudioWork(uid, "transcribe")
    recorder.transcribe(audioPath(a.src), a.duration, function(ok, text, problem) {
      view.setAudioWork(uid, "")
      if (!ok) { view.toast(problem || "It couldn't be written out"); return }
      view.updateAudio(pageId, uid, function(x) { x.transcript = text; x.open = true; return x })
    })
  }

  // A quiet recording made louder, into a new file (the old one stays, so
  // Undo takes it back to that).
  function louderAudio(uid) {
    var a = page && !locked ? editor.audioOf(uid) : null
    if (!a || !a.src || !recorder || audioWork[uid]) return
    var pageId = page.id
    var name = Audio.fileName(new Date())
    setAudioWork(uid, "louder")
    recorder.louder(audioPath(a.src), audioPath("assets/" + name), function(ok, peaks) {
      view.setAudioWork(uid, "")
      if (!ok) { view.toast("It couldn't be made louder"); return }
      view.updateAudio(pageId, uid, function(x) {
        x.src = "assets/" + name
        if (peaks.length) x.peaks = peaks
        return x
      })
    })
  }

  // An audio note's buttons: "record", "stop", "cancel", "transcribe", "louder".
  function audioAction(uid, what) {
    if (what === "record") recordAudio(uid)
    else if (what === "stop") { if (recorder && recorder.owner === uid) recorder.stop() }
    else if (what === "cancel") { if (recorder && recorder.owner === uid) recorder.cancel() }
    else if (what === "transcribe" && page) transcribeAudio(page.id, uid)
    else if (what === "louder") louderAudio(uid)
  }

  // Its colors (the player's, the card's), beside its button.
  function openAudioColors(uid, anchor) {
    var a = editor.items[uid] ? editor.items[uid].audioView : null
    if (!a) return
    tableColorTarget = uid
    colorAt = anchor.mapToItem(view, anchor.width - 250, anchor.height + 6)
    var now = a.scopeColors()
    tableColors.currentText = now.color
    tableColors.currentBack = now.background
    tableColors.x = Math.max(8, Math.min(view.width - tableColors.width - 8, colorAt.x))
    tableColors.y = colorAt.y
    tableColors.open()
  }

  // The voice button at the top (Ctrl+Shift+R): a new audio note where you
  // are on the page, recording at once; again, it stops.
  readonly property bool recordingNote: recorder !== null && recorder.busy && recorder.kind === "audio"
  function newAudioNote() {
    if (!recorder) { toast("Recording isn't here: Uber Notebook runs without the shell"); return }
    if (recordingNote) { if (recorder.phase === "recording") recorder.stop(); return }
    if (recorder.busy) { toast("Already recording: stop that one first"); return }
    if (!page || locked || tagShown !== "") { toast(locked ? "This page is locked: unlock it to record on it" : "Open a page to record on it"); return }
    if (!recorder.canRecord) { toast("Recording needs ffmpeg"); return }
    var made = editor.placeBlock(editor.focusUid, { type: "audio" })
    if (made) Qt.callLater(function() { view.recordAudio(made) })
  }

  // Dictation: what you say, written where you are on the page (Ctrl+Shift+D,
  // the microphone at the top, or "/dictate"; again, or Done, to finish).
  readonly property bool dictating: recorder !== null && recorder.busy && recorder.kind === "dictation" && recorder.owner === "page"
  function dictate() {
    if (!recorder) { toast("Dictation isn't here: Uber Notebook runs without the shell"); return }
    if (dictating) { if (recorder.phase === "recording") recorder.stop(); return }
    if (!page || locked || tagShown !== "") { toast(locked ? "This page is locked: unlock it to dictate into it" : "Open a page to dictate into it"); return }
    var problem = recorder.start("dictation", "page", "", function(ok, r) {
      if (!ok) { if (!r.canceled) view.toast(r.problem || "Nothing was written down"); return }
      if (view.page && !view.locked && view.tagShown === "" && editor.dictated(r.text)) return
      view.workspace.files.copyText(r.text)
      view.toast("Copied what you said: paste it where you want it")
    })
    if (problem) toast(problem)
  }

  // ---- meetings (voxtype's meeting mode) ------------------------------------------------------

  readonly property var meetings: service && service.meetings ? service.meetings : null
  // The meetings being fetched from voxtype: { uid: true }.
  property var meetingWork: ({})
  function setMeetingWork(uid, on) {
    var t = {}
    for (var k in meetingWork) if (k !== uid) t[k] = true
    if (on) t[uid] = true
    meetingWork = t
  }
  // Where the meetings started here are: { id: { pageId, uid, at } }; and the
  // one just started, until voxtype says its id: { pageId, uid, title }.
  property var meetingOwners: ({})
  property var meetingPending: null
  // The meetings fetched by themselves once (a block that ended unseen).
  property var meetingTried: ({})

  // A meeting changed: on the page open (as a step to undo), or in its page's file.
  function updateMeeting(pageId, uid, fn, done) {
    if (page && page.id === pageId && editor.indexOf(uid) >= 0) {
      var ok = editor.setMeeting(uid, fn(editor.meetingOf(uid) || Meeting.make()))
      if (done) done(ok)
      return
    }
    if (!workspace || !workspace.index.pages[pageId]) { if (done) done(false); return }
    workspace.editPage(pageId, function(p) {
      var b = p.blocks ? p.blocks[uid] : null
      if (!b || b.type !== "meeting") return false
      b.meeting = Meeting.clean(fn(Meeting.clean(b.meeting) || Meeting.make()))
      return true
    }, function(ok) { if (done) done(ok) })
  }

  function meetingProblem() {
    if (!meetings) return "Meetings aren't here: Uber Notebook runs without the shell"
    if (!meetings.available) return "Meetings need voxtype, Omarchy's dictation (omarchy voxtype install)"
    if (!meetings.enabled) return "voxtype's meeting mode is off: turn it on in the meeting"
    return ""
  }

  // A meeting started into a meeting block, named for the page.
  function startMeeting(uid) {
    if (!page || locked || !meetings || !meetings.available || !meetings.enabled) return
    if (meetings.status !== "idle" || meetingPending) { toast("voxtype is recording a meeting already"); return }
    var title = Workspace.cleanTitle(titleEdit.text) || page.title || ""
    meetingPending = { pageId: page.id, uid: uid, title: title }
    meetingWait.restart()
    meetings.start(title, function(ok, problem) {
      if (ok) return
      view.meetingPending = null
      view.toast(problem || "voxtype couldn't start the meeting")
    })
  }
  // voxtype says nothing started: said so.
  Timer {
    id: meetingWait
    interval: 12000
    onTriggered: if (view.meetingPending) { view.meetingPending = null; view.toast("voxtype didn't start the meeting: is it running?") }
  }

  // A meeting's transcript, from voxtype, into its block.
  function fetchMeeting(pageId, uid, id) {
    if (!meetings || !id) return
    setMeetingWork(uid, true)
    meetings.fetch(id, function(ok, out) {
      view.setMeetingWork(uid, false)
      if (!ok) { view.toast("voxtype couldn't give the meeting: " + out); return }
      view.updateMeeting(pageId, uid, function(m) { return Meeting.fromExport(out, m) || m })
    })
  }

  Connections {
    target: view.meetings
    // The meeting just started here: its block is that meeting.
    function onMeetingIdChanged() {
      var id = view.meetings.meetingId
      var p = view.meetingPending
      if (!id || !p) return
      view.meetingPending = null
      meetingWait.stop()
      var at = new Date()
      var owners = {}
      for (var k in view.meetingOwners) owners[k] = view.meetingOwners[k]
      owners[id] = { pageId: p.pageId, uid: p.uid, at: at.getTime() }
      view.meetingOwners = owners
      view.updateMeeting(p.pageId, p.uid, function(m) { m.id = id; m.title = p.title; m.startedAt = at.toISOString(); return m })
    }
    // A meeting ended (here or elsewhere): its transcript, into its block.
    function onFinished(id) {
      var uid = view.page ? editor.meetingBlock(id) : ""
      if (uid) { view.fetchMeeting(view.page.id, uid, id); return }
      var o = view.meetingOwners[id]
      if (o) view.fetchMeeting(o.pageId, o.uid, id)
    }
  }

  // The meeting button at the top: a new meeting where you are, started;
  // one voxtype's recording already (started elsewhere), put here.
  function newMeeting() {
    var problem = meetingProblem()
    if (!meetings || !meetings.available) { toast(problem); return }
    if (!page || locked || tagShown !== "") { toast(locked ? "This page is locked: unlock it to record on it" : "Open a page to record on it"); return }
    var running = meetings.status !== "idle" ? meetings.meetingId : ""
    if (running) {
      if (editor.meetingBlock(running)) { toast("It's recording, on this page"); return }
      var o = meetingOwners[running]
      if (o && workspace.index.pages[o.pageId]) { open(o.pageId, false, { block: o.uid }); return }
      var here = editor.placeBlock(editor.focusUid, { type: "meeting", meeting: { id: running, title: "", startedAt: new Date().toISOString() } })
      if (here) toast("voxtype's meeting, put here: it's written out when it ends")
      return
    }
    var made = editor.placeBlock(editor.focusUid, { type: "meeting" })
    if (made && meetings.enabled) Qt.callLater(function() { view.startMeeting(made) })
  }

  // A meeting voxtype recorded, put in a block: picked from its list.
  function importMeeting(uid) {
    if (!meetings) return
    var item = editor.items[uid]
    meetings.list(function(list) {
      if (list.length === 0) { view.toast("voxtype hasn't recorded a meeting yet"); return }
      meetingPick.uid = uid
      meetingPick.choices = list
      if (item) {
        meetingPick.parent = item
        meetingPick.x = Math.max(0, item.width - meetingPick.width - 8)
        meetingPick.y = 70
      }
      meetingPick.open()
    })
  }

  // The agent: the meeting summarized, under it (Claude Code, Grok and Codex
  // here, in the panel; the others in a terminal).
  function summarizeMeeting(uid) {
    if (!page || !workspace) return
    workspace.files.defaultAgent(function(agent) {
      view.askAgentWith(agent,
        "Summarize this meeting (the meeting block: who said what). Right after the meeting block, add a short summary of what it was about, the decisions made, and the action items as to-dos (who does what, by when, when it was said). Keep the meeting block as it is.",
        { scope: "blocks", blocks: [uid], words: "", line: "" }, "Summarize this meeting")
    })
  }

  // A meeting's buttons.
  function meetingAction(uid, what, arg) {
    var m = page ? editor.meetingOf(uid) : null
    if (!m || !meetings) return
    if (what === "start") startMeeting(uid)
    else if (what === "stop") meetings.stop(function(ok, problem) { if (!ok) view.toast(problem) })
    else if (what === "pause") meetings.pause(function(ok, problem) { if (!ok) view.toast(problem) })
    else if (what === "resume") meetings.resume(function(ok, problem) { if (!ok) view.toast(problem) })
    else if (what === "fetch") fetchMeeting(page.id, uid, m.id)
    else if (what === "autofetch") {
      if (meetingTried[uid]) return
      var t = {}
      for (var k in meetingTried) t[k] = true
      t[uid] = true
      meetingTried = t
      fetchMeeting(page.id, uid, m.id)
    }
    else if (what === "import") importMeeting(uid)
    else if (what === "summarize") summarizeMeeting(uid)
    else if (what === "enable") meetings.enable(function(ok, problem) {
      view.toast(ok ? "voxtype's meeting mode is on" : "Meeting mode couldn't be turned on: " + problem)
    })
  }

  // An agenda's or an event block's colors.
  function openCalColors(uid, anchor) {
    var v = editor.items[uid] ? editor.items[uid].calView : null
    if (!v) return
    tableColorTarget = uid
    colorAt = anchor.mapToItem(view, anchor.width - 250, anchor.height + 6)
    var now = v.scopeColors()
    tableColors.currentText = now.color
    tableColors.currentBack = now.background
    tableColors.x = Math.max(8, Math.min(view.width - tableColors.width - 8, colorAt.x))
    tableColors.y = colorAt.y
    tableColors.open()
  }

  // Its colors (its own, the card's), beside its button.
  function openMeetingColors(uid, anchor) {
    var v = editor.items[uid] ? editor.items[uid].meetingView : null
    if (!v) return
    tableColorTarget = uid
    colorAt = anchor.mapToItem(view, anchor.width - 250, anchor.height + 6)
    var now = v.scopeColors()
    tableColors.currentText = now.color
    tableColors.currentBack = now.background
    tableColors.x = Math.max(8, Math.min(view.width - tableColors.width - 8, colorAt.x))
    tableColors.y = colorAt.y
    tableColors.open()
  }

  // ---- projects and the archive ------------------------------------------------------------

  // The open page as a project ({ status, due }), or not (null), as a change to it.
  function setProject(next) {
    if (!page || locked) return
    var p = next ? Workspace.cleanProject(next) : null
    if (p) page.project = p
    else delete page.project
    markDirty()
    commit()
    revision++
  }

  function makeProject() { setProject({ status: "active", due: "" }) }

  // Any page made a project (`next`: { status, due }) or a page again
  // (null): the open page as a change to it, another in its file. done(ok):
  // not if it's locked.
  function projectOf(id, next, done) {
    if (!workspace || !workspace.index.pages[id]) { if (done) done(false); return }
    if (page && page.id === id) {
      if (locked) { if (done) done(false); return }
      setProject(next)
      if (done) done(true)
      return
    }
    workspace.editPage(id, function(p) {
      if (p.format && p.format.locked) return false
      var c = next ? Workspace.cleanProject(next) : null
      if (c) p.project = c
      else delete p.project
      return true
    }, function(ok) { if (done) done(ok) })
  }

  // From the sidebar (a page dragged on Projects, its menu) and the page's
  // menu: a project, or a page again, said so, with Undo.
  function makeProjectOf(id, on) {
    var e = workspace && workspace.index.pages[id]
    if (!e || !!e.project === on) return false
    commit()
    var had = e.project || null
    var title = e.title || "Untitled"
    projectOf(id, on ? { status: "active", due: "" } : null, function(ok) {
      if (!ok) { view.toast("\u201c" + title + "\u201d is locked: unlock it first"); return }
      view.toastUndo(on ? "\u201c" + title + "\u201d is a project, in Projects" : "\u201c" + title + "\u201d is a page again, in Pages", function() {
        view.projectOf(id, on ? null : had)
      })
    })
    return true
  }

  // The sidebar's + on Projects: a new page that's a project, at the top.
  function newProject() {
    if (!workspace) return
    commit()
    var p = workspace.createPage({ parent: "", project: { status: "active", due: "" } })
    if (!p) return
    open(p.id, false, "title")
  }

  function setProjectStatus(status) {
    if (!page || !page.project) return
    setProject({ status: status, due: page.project.due })
    if (status === "done") toast("Done \u2713  Archive it to put it away")
  }

  function setProjectDue(due) {
    if (!page || !page.project) return
    setProject({ status: page.project.status, due: due })
  }

  // A command changing the project of the page open (Api.project).
  function setProjectOfOpenPage(id, next) {
    if (!page || page.id !== id) return false
    if (locked) return "locked"
    setProject(next)
    return true
  }

  // The page put away in the archive (with the pages in it), or back out; Undo.
  function archivePage(id, on) {
    if (!workspace || !id || !workspace.index.pages[id]) return
    commit()
    var title = workspace.index.pages[id].title || "Untitled"
    workspace.setArchived(id, on)
    revision++
    toastUndo(on ? "\u201c" + title + "\u201d is in the archive" : "\u201c" + title + "\u201d is out of the archive", function() {
      view.workspace.setArchived(id, !on)
      view.revision++
    })
  }

  // The page in the archive a page is in (itself, or one it's inside).
  function archivedRoot(id) {
    var ix = workspace.index
    var p = id
    var seen = {}
    while (p && ix.pages[p] && !seen[p]) {
      if (ix.pages[p].archived) return p
      seen[p] = true
      p = ix.pages[p].parent
    }
    return id
  }

  // ---- the page's look -----------------------------------------------------------------------

  function setFormat(key, value) {
    if (!page) return
    var f = {}
    for (var k in page.format) f[k] = page.format[k]
    f[key] = value
    page.format = Workspace.cleanFormat(f)
    markDirty()
    commit()
  }

  // ---- page history ------------------------------------------------------------------------

  function openHistory() {
    if (!page || !workspace) return
    commit()
    historyPanel.openFor(page.id)
  }

  // An earlier version of the page put back, as a step Undo takes back (the
  // page as it was is kept in its history first, too).
  function restoreVersion(version, label) {
    if (!page || !workspace || locked || !version) return
    commit()
    workspace.keepVersion(page.id, "restore", true)
    var r = Workspace.versionToRestore(version, page, workspace.index)
    editor.resetBlocks(r.blocks)
    if (Workspace.cleanTitle(titleEdit.text) !== r.title) titleEdit.text = r.title
    page.icon = Workspace.cleanIcon(r.icon)
    markDirty()
    commit()
    toast("Restored the version from " + label + "  \u00b7  Ctrl+Z takes it back")
  }

  function setIcon(emoji) {
    if (!page) return
    page.icon = Workspace.cleanIcon(emoji)
    markDirty()
    commit()
  }

  function setCover(cover) {
    if (!page) return
    page.cover = Workspace.cleanCover(cover)
    markDirty()
    commit()
  }

  function copyMarkdown() {
    commit()
    if (!page) return
    workspace.files.copyText(Markdown.fromDocPage(page, function(id) {
      var e = view.workspace.index.pages[id]
      return e ? { title: e.title || "Untitled", icon: e.icon, file: "" } : null
    }, { calendar: workspace.calendar, syncedPage: function(id) { return view.workspace.readPageNow(id) }, contactOf: function(id) { return view.workspace.contactById(id) } }))
    toast("Copied the page as Markdown")
  }

  function exportPage() {
    commit()
    if (page) workspace.exportPage(page.id)
  }

  // The page as a PDF or a Word file, or printed (app/Exporter.qml); with
  // the pages inside it, when `withPages`.
  readonly property var exporter: exporterItem
  function exportAs(kind, withPages) {
    commit()
    if (page) exporterItem.run(kind, JSON.parse(JSON.stringify(page)), withPages === true)
  }
  function hasChildPages(id) {
    return !!workspace && Workspace.withDescendants(workspace.index, id).length > 1
  }
  function openExportMenu() { exportMenu.open() }
  function openPageMenu() { pageMenu.open() }
  Exporter {
    id: exporterItem
    workspace: view.workspace
    editor: editor
    service: view.service
    settings: view.settings
    onToast: function(text) { view.toast(text) }
  }

  // Pages to link to with "[[": the ones called what's typed, or the most
  // recent; not this one.
  function findPages(query) {
    if (!workspace) return []
    var ix = workspace.index
    var here = page ? page.id : ""
    var ids = String(query || "").trim() ? Workspace.findTitles(ix, query, 9)
      : Object.keys(ix.pages).filter(function(id) { return !Workspace.inTrash(ix, id) && !Workspace.inTemplates(ix, id) })
          .sort(function(a, b) { return ix.pages[a].modified < ix.pages[b].modified ? 1 : -1 }).slice(0, 9)
    return ids.filter(function(id) { return id !== here }).slice(0, 8).map(function(id) {
      return { id: id, title: ix.pages[id].title, icon: ix.pages[id].icon,
        path: Workspace.path(ix, id).slice(0, -1).map(function(p) { return p.title || "Untitled" }).join(" / ") }
    })
  }

  // ---- getting around ------------------------------------------------------------------------

  function back() { if (historyAt > 0) { historyAt--; open(history[historyAt], true) } }
  function forward() { if (historyAt < history.length - 1) { historyAt++; open(history[historyAt], true) } }

  function expandTo(id) {
    var o = {}
    for (var k in openRows) o[k] = openRows[k]
    Workspace.path(workspace.index, id).slice(0, -1).forEach(function(p) { o[p.id] = true })
    openRows = o
  }

  function toggleRow(id) {
    var o = {}
    for (var k in openRows) o[k] = openRows[k]
    o[id] = !o[id]
    openRows = o
  }

  function openFind() { quickFind.start() }
  function openTrash() { trashPop.x = 12; trashPop.y = view.height - trashPop.height - 60; trashPop.open() }
  // Templates (yours, then Uber Notebook's), in place of a page.
  function openTemplates(fromHistory) {
    if (!workspace) return
    commit()
    page = null
    editor.load([])
    pageDirty = false
    tagShown = ""
    calendarShown = false
    libraryShown = false
    peopleShown = false
    templatesShown = true
    templatesView.reset()
    templatesView.focusSearch()
    if (!fromHistory) {
      history = history.slice(0, historyAt + 1).concat(["templates"]).slice(-100)
      historyAt = history.length - 1
    }
  }
  function openArchive() { archivePop.x = 12; archivePop.y = view.height - archivePop.height - 90; archivePop.open() }
  function openRowMenu(id, anchor) {
    rowMenu.pageId = id
    rowMenu.parent = anchor
    rowMenu.x = anchor.width - 20
    rowMenu.y = anchor.height - 4
    rowMenu.open()
  }

  // Asks where to move a page.
  property string moving: ""
  function movePageAsk(id) {
    if (!id) return
    moving = id
    picker.purpose = "movePage"
    picker.exclude = id
    picker.allowTop = true
    picker.openAt(main, "Move \u201c" + (workspace.index.pages[id].title || "Untitled") + "\u201d to\u2026")
  }

  // Where it's asked from: the block a link or picture goes in or after.
  property string pickFor: ""
  property var movingBlocks: []

  function ensureVisible(y, h) {
    var p = editor.mapToItem(flick.contentItem, 0, y)
    var top = p.y - 90
    var bottom = p.y + h + 90
    var max = Math.max(0, flick.contentHeight - flick.height)
    if (top < flick.contentY) flick.contentY = Math.max(0, Math.round(top))
    else if (bottom > flick.contentY + flick.height) flick.contentY = Math.round(Math.min(max, bottom - flick.height))
  }

  // ---- what's on screen -------------------------------------------------------------------------

  Rectangle {
    anchors.fill: parent
    color: view.theme.background
  }

  DocSidebar {
    id: sidebar
    objectName: "sidebar"
    theme: view.theme
    view: view
    width: 250
    height: parent.height
    x: view.sidebarShown ? 0 : -width
    visible: x > -width
    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
  }

  Item {
    id: main
    x: view.sidebarW
    width: view.width - x
    height: view.height
    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // The bar above: the sidebar, back and forward, where the page is, its menu.
    Item {
      id: topBar
      z: 3
      width: parent.width
      height: 46

      Row {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        IconButton {
          visible: !view.sidebarShown
          theme: view.theme; icon: view.theme.icons.sidebar; size: 30; iconSize: 16; tip: "Show the sidebar  Ctrl+\\"
          onClicked: view.sidebarShown = true
        }
        IconButton { theme: view.theme; icon: view.theme.icons.back; size: 30; iconSize: 16; tip: "Back  Alt+\u2190"; active: view.historyAt > 0; onClicked: view.back() }
        IconButton { theme: view.theme; icon: view.theme.icons.forward; size: 30; iconSize: 16; tip: "Forward  Alt+\u2192"; active: view.historyAt < view.history.length - 1; onClicked: view.forward() }
        Item { width: 6; height: 1 }
        // The calendar shown, the Library, or People.
        Text {
          visible: view.calendarShown || view.libraryShown || view.peopleShown || view.templatesShown
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: 6
          textFormat: Text.PlainText
          text: view.templatesShown ? "Templates" : view.peopleShown ? "People" : view.libraryShown ? "Library" : "Calendar"
          font.family: view.theme.uiFont
          font.pixelSize: 13
          color: view.theme.text
        }
        // A tag shown: "Tags / #idea".
        Text {
          visible: view.tagShown !== ""
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: 6
          textFormat: Text.PlainText
          text: "Tags  /  " + (view.tagShown ? view.tagView.info.label : "")
          font.family: view.theme.uiFont
          font.pixelSize: 13
          color: view.theme.text
        }
        Repeater {
          model: view.crumbs
          delegate: Row {
            required property var modelData
            required property int index
            anchors.verticalCenter: parent.verticalCenter
            Text {
              textFormat: Text.PlainText
              visible: index > 0
              anchors.verticalCenter: parent.verticalCenter
              text: "  /  "
              font.family: view.theme.uiFont
              font.pixelSize: 13
              color: view.theme.faint
            }
            Rectangle {
              width: crumb.implicitWidth + 12
              height: 26
              radius: 5
              color: crumbHover.hovered ? view.theme.hover : "transparent"
              Text {
                id: crumb
                textFormat: Text.PlainText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
                text: (modelData.icon ? modelData.icon + " " : "") + (modelData.title || "Untitled")
                font.family: view.theme.uiFont
                font.pixelSize: 13
                color: view.theme.text
              }
              HoverHandler { id: crumbHover; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: view.open(modelData.id) }
            }
          }
        }
      }

      Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          visible: view.page !== null
          rightPadding: 10
          text: { var r = view.revision; return view.page ? "Edited " + Qt.formatDateTime(new Date(view.page.modified), "d MMM, HH:mm") : "" }
          font.family: view.theme.uiFont
          font.pixelSize: 12
          color: view.theme.faint
        }
        IconButton {
          visible: view.locked
          theme: view.theme; icon: view.theme.icons.lock; label: "Locked"; size: 30; iconSize: 14; tint: view.theme.muted
          tip: "Locked: it can't be changed. Click to unlock"
          onClicked: view.setFormat("locked", false)
        }
        IconButton {
          visible: view.page !== null
          theme: view.theme; icon: view.favorite ? view.theme.icons.star : view.theme.icons.starOutline; size: 30; iconSize: 16
          tint: view.favorite ? "#e0a82e" : view.theme.text
          tip: view.favorite ? "In Favorites" : "Add to Favorites"
          onClicked: view.toggleFavorite(view.page.id)
        }
        IconButton {
          objectName: "agentButton"
          visible: view.page !== null
          theme: view.theme; icon: view.theme.icons.agent; size: 30; iconSize: 16
          // (A conversation here: a mark under it, and it goes back to it.)
          swatch: view.pageChat !== null ? view.theme.accent : "transparent"
          tip: view.pageChat !== null ? Agent.chatTip(view.pageChat) + "  Ctrl+J" : "Ask your agent  Ctrl+J"
          onClicked: view.openAgent("auto")
        }
        IconButton {
          objectName: "recordButton"
          visible: view.page !== null && view.tagShown === "" && view.recorder !== null
          theme: view.theme; icon: view.recordingNote ? view.theme.icons.stop : view.theme.icons.record; size: 30; iconSize: 17
          tint: view.theme.dark ? "#ff6b6b" : "#e5484d"
          checked: view.recordingNote
          tip: view.recordingNote ? "Stop recording  Ctrl+Shift+R" : "Record an audio note here  Ctrl+Shift+R"
          onClicked: view.newAudioNote()
        }
        IconButton {
          objectName: "meetingButton"
          readonly property bool live: view.meetings !== null && view.meetings.status !== "idle"
          visible: view.page !== null && view.tagShown === "" && view.meetings !== null && view.meetings.available
          theme: view.theme; icon: view.theme.icons.people; size: 30; iconSize: 17
          tint: live ? (view.theme.dark ? "#ff6b6b" : "#e5484d") : view.theme.text
          checked: live
          tip: live ? "A meeting is recording: go to it" : "Record a meeting (voxtype writes out who said what)"
          onClicked: view.newMeeting()
        }
        IconButton {
          objectName: "dictateButton"
          visible: view.page !== null && view.tagShown === "" && view.recorder !== null
          theme: view.theme; icon: view.theme.icons.mic; size: 30; iconSize: 16
          tint: view.dictating ? (view.theme.dark ? "#ff6b6b" : "#e5484d") : view.theme.text
          checked: view.dictating
          tip: view.dictating ? "Done dictating  Ctrl+Shift+D" : view.recorder && view.recorder.checked && !view.recorder.canTranscribe ? "Dictation needs voxtype (Omarchy's dictation)" : "Dictate: say it, and it's written where you are  Ctrl+Shift+D"
          onClicked: view.dictate()
        }
        IconButton { visible: view.tagShown === "" && !view.calendarShown && !view.libraryShown && !view.peopleShown && !view.templatesShown; theme: view.theme; icon: view.theme.icons.search; size: 30; iconSize: 16; tip: "Find on this page  Ctrl+F"; checked: findBar.shown; onClicked: findBar.toggle() }
        IconButton {
          id: moreButton
          visible: !view.calendarShown && !view.libraryShown && !view.peopleShown && !view.templatesShown
          theme: view.theme; icon: view.theme.icons.more; size: 30; iconSize: 16; tip: "Font, width, export, trash"
          active: view.page !== null
          onClicked: pageMenu.open()
          PageMenu {
            id: pageMenu
            theme: view.theme
            view: view
            x: moreButton.width - width
            y: moreButton.height + 6
          }
          ExportMenu {
            id: exportMenu
            theme: view.theme
            view: view
            x: moreButton.width - width
            y: moreButton.height + 6
          }
        }
      }
    }

    // ---- the page -----------------------------------------------------------------------------

    // A tag's blocks, in place of the page.
    TagView {
      id: tagView
      z: 2
      anchors.top: topBar.bottom
      anchors.bottom: parent.bottom
      width: parent.width
      visible: view.tagShown !== ""
      theme: view.theme
      workspace: view.workspace
      view: view
      name: view.tagShown
      onColorRequested: function(anchor) { view.openTagColors(anchor) }
      onRenameRequested: function(anchor) { view.openTagRename(anchor) }
      onRemoveRequested: view.removeTag()
    }

    // People, in place of a page.
    PeopleView {
      id: peopleView
      objectName: "peopleView"
      z: 2
      anchors.top: topBar.bottom
      anchors.bottom: parent.bottom
      width: parent.width
      visible: view.peopleShown
      theme: view.theme
      workspace: view.workspace
      view: view
    }

    // The Library, in place of a page.
    LibraryView {
      id: libraryView
      objectName: "libraryView"
      z: 2
      anchors.top: topBar.bottom
      anchors.bottom: parent.bottom
      width: parent.width
      visible: view.libraryShown
      theme: view.theme
      workspace: view.workspace
      view: view
    }

    // Templates, in place of a page.
    TemplatesView {
      id: templatesView
      objectName: "templatesView"
      z: 2
      anchors.top: topBar.bottom
      anchors.bottom: parent.bottom
      width: parent.width
      visible: view.templatesShown
      theme: view.theme
      workspace: view.workspace
      view: view
    }

    // The calendar, in place of a page.
    CalendarView {
      id: calendarView
      objectName: "calendarView"
      z: 2
      anchors.top: topBar.bottom
      anchors.bottom: parent.bottom
      width: parent.width
      visible: view.calendarShown
      theme: view.theme
      workspace: view.workspace
      view: view
    }

    Flickable {
      id: flick
      anchors.top: topBar.bottom
      anchors.bottom: parent.bottom
      width: parent.width
      contentWidth: width
      contentHeight: Math.max(height, header.height + editor.height + 260)
      interactive: false
      clip: true
      visible: view.page !== null
      Behavior on contentY { enabled: scroller.animate; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      // The cover, across the whole page.
      Item {
        id: coverArea
        width: flick.width
        height: view.coverH
        visible: view.cover !== ""
        readonly property var stops: Docs.coverStops(view.cover)
        Rectangle {
          anchors.fill: parent
          visible: coverArea.stops !== null
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: coverArea.stops ? coverArea.stops[0] : "black" }
            GradientStop { position: coverArea.stops && coverArea.stops.length > 2 ? 0.5 : 1.0; color: coverArea.stops ? coverArea.stops[1] : "black" }
            GradientStop { position: 1.0; color: coverArea.stops ? coverArea.stops[coverArea.stops.length - 1] : "black" }
          }
        }
        Image {
          anchors.fill: parent
          visible: coverArea.stops === null
          source: coverArea.stops === null && view.cover ? view.workspace.assetUrl(view.cover) : ""
          // (Decoded no wider than a cover can show; only its width, since
          // it's cropped: both would decode it to fill them.)
          sourceSize.width: 3840
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }
        HoverHandler { id: coverHover }
        Row {
          visible: coverHover.hovered
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 12
          spacing: 6
          Chip { theme: view.theme; text: "Change cover"; color: view.theme.surfaceHigh; onClicked: coverPop.openAt(this) }
          Chip { theme: view.theme; text: "Remove"; color: view.theme.surfaceHigh; onClicked: view.setCover("") }
        }
      }

      Column {
        id: header
        x: (flick.width - view.pageW) / 2
        y: view.cover ? view.coverH - (view.icon ? 42 : 0) : (view.icon ? 54 : 70)
        width: view.pageW
        spacing: 4

        // The icon, and (on hover) buttons to add one or a cover.
        Text {
          id: iconText
          textFormat: Text.PlainText
          visible: view.icon !== ""
          text: view.icon
          font.family: "Noto Color Emoji"
          font.pixelSize: 64
          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: { emojiPop.target = "page"; emojiPop.removable = true; emojiPop.openAt(iconText) } }
        }
        Item {
          width: parent.width
          height: 30
          HoverHandler { id: headHover }
          Row {
            visible: headHover.hovered || titleEdit.activeFocus && titleEdit.length === 0
            spacing: 4
            IconButton {
              id: addIcon
              visible: view.icon === ""
              theme: view.theme; icon: view.theme.icons.emoji; label: "Add icon"; size: 28; iconSize: 15; tint: view.theme.muted
              onClicked: { emojiPop.target = "page"; emojiPop.removable = false; view.setIcon(Docs.randomEmoji()) }
            }
            IconButton {
              id: addCover
              visible: view.cover === ""
              theme: view.theme; icon: view.theme.icons.cover; label: "Add cover"; size: 28; iconSize: 15; tint: view.theme.muted
              onClicked: view.setCover("gradient:" + Math.floor(Math.random() * Docs.COVERS.length))
            }
          }
        }

        // The title.
        TextEdit {
          id: titleEdit
          width: parent.width
          textFormat: TextEdit.PlainText
          wrapMode: TextEdit.Wrap
          font.family: view.family
          font.pixelSize: view.small ? 34 : 40
          font.weight: Font.Bold
          color: view.theme.text
          selectionColor: Qt.alpha(view.theme.accent, 0.3)
          selectedTextColor: view.theme.text
          selectByMouse: true
          readOnly: view.locked
          onTextChanged: {
            if (view.settingTitle || !view.page) return
            // The sidebar and the path above follow as you type.
            var e = view.workspace.index.pages[view.page.id]
            if (e) { e.title = Workspace.cleanTitle(text); view.workspace.revision++ }
            view.markDirty()
          }
          Keys.onPressed: function(e) {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (e.key === Qt.Key_Down && titleEdit.cursorPosition === titleEdit.length) || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) {
              e.accepted = true
              editor.focusStart()
            } else if (((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_V) || ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Insert)) {
              if (view.pasteIntoTitle()) e.accepted = true
            }
          }
          Text {
            textFormat: Text.PlainText
            visible: titleEdit.length === 0 && titleEdit.preeditText === ""
            text: view.titleHint || "Untitled"
            font: titleEdit.font
            color: Qt.alpha(view.theme.text, 0.25)
          }
        }
        // Put away in the archive: it says so, and takes it back out.
        Rectangle {
          id: archivedNote
          objectName: "archivedNote"
          readonly property bool shown: { var r = view.workspace ? view.workspace.revision : 0; return view.page !== null && view.workspace !== null && Workspace.inArchive(view.workspace.index, view.page.id) }
          visible: shown
          width: archivedRow.implicitWidth + 24
          height: visible ? 32 : 0
          radius: 8
          color: Qt.alpha(view.theme.text, 0.06)
          Row {
            id: archivedRow
            anchors.centerIn: parent
            spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: view.theme.icons.archive; font.family: view.theme.iconFont; font.pixelSize: 14; color: view.theme.muted }
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "In the archive"; font.family: view.theme.uiFont; font.pixelSize: 13; color: view.theme.muted }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Bring it back"
              font.family: view.theme.uiFont
              font.pixelSize: 13
              font.weight: Font.DemiBold
              color: view.theme.accent
              HoverHandler { cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: view.archivePage(view.archivedRoot(view.page.id), false) }
            }
          }
        }

        // A synced block's blocks: it says so; back where you were.
        Rectangle {
          id: syncedNote
          objectName: "syncedNote"
          readonly property bool shown: { var r = view.workspace ? view.workspace.revision : 0; return view.page !== null && view.workspace !== null && view.workspace.index.pages[view.page.id] !== undefined && view.workspace.index.pages[view.page.id].synced === true }
          readonly property int places: { var r = view.workspace ? view.workspace.revision : 0; return shown ? Workspace.backlinks(view.workspace.index, view.page.id).length : 0 }
          visible: shown
          width: syncedRow2.implicitWidth + 24
          height: visible ? 32 : 0
          radius: 8
          color: Qt.alpha("#e5904d", 0.14)
          Row {
            id: syncedRow2
            anchors.centerIn: parent
            spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: view.theme.icons.synced; font.family: view.theme.iconFont; font.pixelSize: 14; color: "#c86f2a" }
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "A synced block's blocks: what you change here changes on " + (syncedNote.places === 1 ? "the page it's on" : "the " + syncedNote.places + " pages it's on"); font.family: view.theme.uiFont; font.pixelSize: 13; color: view.theme.text }
            Text {
              visible: view.historyAt > 0
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Back"
              font.family: view.theme.uiFont
              font.pixelSize: 13
              font.weight: Font.DemiBold
              color: view.theme.accent
              HoverHandler { cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: view.back() }
            }
          }
        }

        // The notes for an event: it says which (a click opens it).
        Rectangle {
          id: eventNote
          objectName: "eventNote"
          readonly property var ev: {
            var r = view.workspace ? view.workspace.calendarRevision : 0
            if (!view.page || !view.workspace) return null
            var list = view.workspace.calendar.events
            for (var i = 0; i < list.length; i++) if (list[i].page === view.page.id) return list[i]
            return null
          }
          readonly property var next: ev ? Calendar.nextOf(ev, new Date()) : null
          visible: ev !== null
          width: eventRow2.implicitWidth + 24
          height: visible ? 32 : 0
          radius: 8
          color: Qt.alpha(view.theme.text, 0.06)
          Row {
            id: eventRow2
            anchors.centerIn: parent
            spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: view.theme.icons.calendar; font.family: view.theme.iconFont; font.pixelSize: 14; color: view.theme.accent }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: eventNote.next ? Calendar.line(eventNote.next, new Date()) : ""
              font.family: view.theme.uiFont
              font.pixelSize: 13
              color: view.theme.text
            }
          }
          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: view.openEvent(eventNote.ev.id, eventNote.next ? eventNote.next.day : "", eventNote) }
        }

        // A template: it says so; a new page from it, or a page again.
        Rectangle {
          id: templateNote
          objectName: "templateNote"
          readonly property string root: { var r = view.workspace ? view.workspace.revision : 0; return view.page ? view.templateRoot(view.page.id) : "" }
          visible: root !== ""
          width: templateRow2.implicitWidth + 24
          height: visible ? 32 : 0
          radius: 8
          color: Qt.alpha(view.theme.accent, 0.1)
          Row {
            id: templateRow2
            anchors.centerIn: parent
            spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: view.theme.icons.templates; font.family: view.theme.iconFont; font.pixelSize: 14; color: view.theme.accent }
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "A template: new pages from it start like this"; font.family: view.theme.uiFont; font.pixelSize: 13; color: view.theme.text }
            Text {
              objectName: "templateUse"
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "New page from it"
              font.family: view.theme.uiFont
              font.pixelSize: 13
              font.weight: Font.DemiBold
              color: view.theme.accent
              HoverHandler { cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: view.newPageFromTemplate(templateNote.root, "") }
            }
          }
        }

        // A template's own page: what it's for, in a line (Templates shows it).
        Item {
          id: aboutTemplate
          objectName: "templateAbout"
          readonly property string saved: { var r = view.workspace ? view.workspace.revision : 0; return visible && view.workspace.index.pages[view.page.id] ? view.workspace.index.pages[view.page.id].description || "" : "" }
          visible: view.page !== null && templateNote.root === view.page.id
          width: parent.width
          height: visible ? 28 : 0
          onSavedChanged: if (!aboutInput.activeFocus) aboutInput.text = saved
          onVisibleChanged: if (visible) aboutInput.text = saved
          TextInput {
            id: aboutInput
            objectName: "templateAboutInput"
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            maximumLength: 200
            selectByMouse: true
            font.family: view.theme.uiFont
            font.pixelSize: 14
            color: view.theme.text
            selectionColor: Qt.alpha(view.theme.accent, 0.35)
            onEditingFinished: if (view.page) view.workspace.setDescription(view.page.id, text)
            onActiveFocusChanged: if (!activeFocus && view.page) view.workspace.setDescription(view.page.id, text)
            Keys.onEscapePressed: { text = aboutTemplate.saved; view.forceActiveFocus() }
            Text {
              visible: aboutInput.text === ""
              textFormat: Text.PlainText
              text: "What it's for, in a line (shown in Templates)"
              font: aboutInput.font
              color: view.theme.faint
            }
            HoverHandler { cursorShape: Qt.IBeamCursor }
          }
        }

        // A project: its status, when it's due, how far along it is.
        ProjectBar {
          id: projectBar
          objectName: "projectBar"
          theme: view.theme
          view: view
        }

        // The pages that link here.
        Flow {
          visible: view.backlinks.length > 0
          width: parent.width
          spacing: 4
          topPadding: 4
          Text {
            textFormat: Text.PlainText
            height: 26
            verticalAlignment: Text.AlignVCenter
            rightPadding: 4
            text: "\u21a9 Linked from"
            font.family: view.theme.uiFont
            font.pixelSize: 12
            color: view.theme.muted
          }
          Repeater {
            model: view.backlinks
            delegate: Rectangle {
              required property var modelData
              readonly property var e: view.workspace.index.pages[modelData] || ({ title: "", icon: "" })
              width: backName.implicitWidth + 16
              height: 26
              radius: 13
              color: backHover.hovered ? view.theme.hover : Qt.alpha(view.theme.text, 0.04)
              border.width: 1
              border.color: view.theme.line
              Text {
                id: backName
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: (parent.e.icon ? parent.e.icon + " " : "") + (parent.e.title || "Untitled")
                font.family: view.theme.uiFont
                font.pixelSize: 12
                color: view.theme.text
              }
              HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: view.open(modelData) }
            }
          }
        }
        Item { width: 1; height: 10 }

        Editor {
          id: editor
          layout: "doc"
          theme: view.theme
          findTags: function(query) { return view.findTags(query) }
          tagStyle: function(href) { return view.tagStyleOf(href) }
          width: view.pageW
          contentWidth: width
          focus: true
          family: view.family
          monoFamily: view.theme.monoFont
          uiFamily: view.theme.uiFont
          ink: view.theme.text
          muted: view.theme.muted
          accent: view.theme.accent
          linkColor: view.theme.accent
          selectionColor: Qt.alpha(view.theme.accent, 0.3)
          dark: view.theme.dark
          paper: view.theme.background
          smallText: view.small
          readOnly: view.locked
          strikeDone: view.settings.strikeDone !== false
          assetUrl: function(src) { return view.workspace ? view.workspace.assetUrl(src) : "" }
          assetInfo: function(src, done) { if (view.workspace) view.workspace.assetInfo(src, done); else done(null) }
          readClipboard: view.workspace && view.workspace.files && typeof view.workspace.files.readClipboard === "function" ? function(done, primary) { view.workspace.files.readClipboard(done, primary) } : null
          pageInfo: function(id) { return view.workspace ? view.workspace.pageMeta(id) : null }
          pagesRevision: view.workspace ? view.workspace.revision : 0
          findPages: function(query) { return view.findPages(query) }
          findPeople: function(query) { return view.findPeople(query) }
          makePerson: function(name) { return view.makePerson(name) }
          personOfEmail: function(email) { return view.personOfEmail(email) }
          onContactOpened: function(id, anchor, x, y) { contactPop.openAt(id, anchor, x, y) }
          makePage: function(title) {
            var made = view.workspace ? view.workspace.createPage({ parent: "", title: title }) : null
            return made ? made.id : ""
          }
          onChanged: { view.markDirty(); if (view.pageBlank || editor.model.count <= 1) view.updateBlank() }
          onCursorAt: function(y, h) { view.ensureVisible(y, h) }
          onLeaveTop: { titleEdit.forceActiveFocus(); titleEdit.cursorPosition = titleEdit.length }
          onPageOpened: function(id) { view.open(id) }
          onSubpageRequested: function(uid) { view.subpageIn(uid) }
          onPageLinkRequested: function(uid) {
            view.pickFor = uid
            picker.purpose = "link"
            picker.exclude = ""
            picker.allowTop = false
            picker.openAt(main, "Link to page")
          }
          onPageRelinkRequested: function(uid) {
            view.pickFor = uid
            picker.purpose = "relink"
            picker.exclude = ""
            picker.allowTop = false
            picker.openAt(main, "Link to another page")
          }
          onImageRequested: function(uid) {
            var place = function(path) {
              if (path) view.workspace.importPicture(path, function(src) { if (src) editor.placeBlock(uid, { type: "image", src: src, width: 1, align: "center" }) })
            }
            // A picture, shown as pictures (the desktop's file dialog a click away).
            picturePicker.choose(false, function(paths) { place(paths[0]) }, function() { view.pictureRequested(place) })
          }
          onIconRequested: function(uid) {
            if (view.locked) return
            view.pickFor = uid
            emojiPop.target = "callout"
            emojiPop.removable = false
            var item = editor.items[uid]
            if (item) emojiPop.openAt(item)
          }
          onBlockMenuRequested: function(uid) {
            var item = editor.items[uid]
            if (!item) return
            blockMenu.openFor(uid, item)
            blockMenu.x = item.bx - 48
            blockMenu.y = (item.isText ? item.markY : 20) + 16
          }
          onLanguageRequested: function(uid) {
            if (view.locked) return
            view.pickFor = uid
            var item = editor.items[uid]
            if (!item) return
            langPop.current = item.lang || "Plain text"
            langPop.parent = item
            langPop.x = item.bx + 8
            langPop.y = item.textTop - 4
            langPop.open()
          }
          onTextCopied: function(text) { view.workspace.files.copyText(text); view.toast("Copied") }
          onLinkOpened: function(url) { view.workspace.files.openUrl(url) }
          onPictureOpened: function(src) { view.showPagePicture(src) }
          onPictureCopyRequested: function(src) { view.copyPicture(src) }
          onDrawingCopyRequested: function(kind, source, look) { view.copyDrawing(kind, source, look) }
          onDrawingSaveRequested: function(kind, source, look) { view.saveDrawing(kind, source, look) }
          onPictureSaveRequested: function(src) { view.savePicture(src, "") }
          onPastePicture: function(afterUid) { view.workspace.pastePicture(function(src) { if (src) editor.insertPicture(afterUid, src, 0) }) }
          onLinkRequested: linkPop.openAt(bubble)
          onMindMapColorsRequested: function(uid, anchor) { view.openIdeaColors(uid, anchor) }
          onTableMenuRequested: function(uid, kind, index, anchor) { tableMenu.openFor(uid, kind, index, anchor, view) }
          onTableColorsRequested: function(uid, anchor) { view.openTableColors(uid, anchor) }
          onSketchColorsRequested: function(uid, anchor) { view.openSketchColors(uid, anchor) }
          recorder: view.recorder
          audioWork: view.audioWork
          onAudioRequested: function(uid) { view.recordAudio(uid) }
          onAudioAction: function(uid, what) { view.audioAction(uid, what) }
          onAudioColorsRequested: function(uid, anchor) { view.openAudioColors(uid, anchor) }
          onDictateRequested: view.dictate()
          onRecordRequested: view.newAudioNote()
          onTemplateRequested: function(uid) { view.openTemplatePick("insert", "", editor.items[uid] || null) }
          calendarSource: view.workspace
          dataWork: view.dataWork
          onDataAction: function(uid, what, arg) { view.dataAction(uid, what, arg) }
          onCalendarAction: function(uid, what, arg) {
            if (what === "add") view.quickAdd(arg.day, -1, arg.anchor)
            else if (what === "open") view.openEvent(arg.id, arg.day, arg.anchor)
            else if (what === "colors") view.openCalColors(uid, arg)
          }
          onEventRequested: function(uid) {
            var item = editor.items[uid]
            var n = new Date()
            view.quickAdd(new Date(n.getFullYear(), n.getMonth(), n.getDate()), -1, item || null, function(id) {
              editor.placeBlock(uid, { type: "event", calendar: { id: id } })
            })
          }
          meetings: view.meetings
          meetingWork: view.meetingWork
          onMeetingAction: function(uid, what, arg) { view.meetingAction(uid, what, arg) }
          onMeetingColorsRequested: function(uid, anchor) { view.openMeetingColors(uid, anchor) }
          onMeetingRequested: function(uid) { view.startMeeting(uid) }
          onTagOpened: function(name) { view.openTag(name) }
          onAgentRequested: function(uid) {
            var i = editor.indexOf(uid)
            var empty = i >= 0 && Html.plainText(editor.blockAt(i).html || "") === "" && !(editor.items[uid] && editor.items[uid].edit.length > 0)
            view.openAgent(empty ? "line" : "blocks", [uid])
          }
        }

        // On a blank page: templates to start from.
        Column {
          id: templateRow
          visible: view.pageBlank && !view.locked
          width: parent.width
          topPadding: 18
          spacing: 10
          Text {
            textFormat: Text.PlainText
            text: "Start with a template"
            font.family: view.theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: view.theme.muted
          }
          Flow {
            width: parent.width
            spacing: 6
            // Yours first.
            Repeater {
              model: view.page && view.templateRoot(view.page.id) === "" ? view.userTemplates : []
              delegate: Chip {
                required property var modelData
                objectName: "userTemplateChip"
                theme: view.theme
                icon: modelData.icon ? "" : view.theme.icons.templates
                text: (modelData.icon ? modelData.icon + "  " : "") + modelData.title
                checked: true
                onClicked: view.applyTemplate("tpl:" + modelData.id)
              }
            }
            Repeater {
              model: view.templates
              delegate: Chip {
                required property var modelData
                theme: view.theme
                icon: view.theme.icons[modelData.icon] || ""
                text: modelData.label
                onClicked: view.applyTemplate(modelData.id)
              }
            }
          }
        }
      }

      // A click under the last block writes there.
      MouseArea {
        y: header.y + header.height
        width: flick.width
        height: Math.max(0, flick.contentHeight - y)
        cursorShape: Qt.IBeamCursor
        onClicked: editor.clickBelow()
      }

      DropArea {
        id: pageDrop
        anchors.fill: parent
        onEntered: function(drag) { drag.accepted = drag.hasUrls }
        onDropped: function(drop) {
          if (!drop.hasUrls) return
          // Pictures dropped on a gallery: into it.
          var onGallery = view.page && !view.locked ? view.galleryAt(pageDrop, drop.x, drop.y) : ""
          if (onGallery) {
            var pics = []
            for (var g = 0; g < drop.urls.length && g < 100; g++) {
              var gp = decodeURIComponent(String(drop.urls[g]).replace(/^file:\/\//, ""))
              if (Files.kindOf(gp) === "image") pics.push(gp)
            }
            if (pics.length) { view.addToGallery(view.page.id, onGallery, pics); return }
          }
          var after = editor.focusUid
          var notes = []
          for (var i = 0; i < drop.urls.length && i < 100; i++) {
            var path = decodeURIComponent(String(drop.urls[i]).replace(/^file:\/\//, ""))
            // An email (.eml): an email block.
            if (/\.eml$/i.test(path) && i < 12 && view.page && !view.locked) {
              var mail = editor.placeBlock(after || editor.uidAt(editor.model.count - 1), { type: "email" })
              after = mail
              view.addEmailTo(view.page.id, mail, path)
              continue
            }
            // Contacts (.vcf): into People.
            if (/\.(vcf|vcard)$/i.test(path)) { view.importContactsFrom(path, function(r) { if (r) view.openPeople(r.first) }); continue }
            // A calendar file (.ics): its events, to put on your calendar.
            if (view.isCalendarFile(path)) {
              var icsPath = path
              view.workspace.files.readFiles([icsPath], function(got) { if (got[icsPath] !== undefined) view.showIcs(got[icsPath], icsPath.slice(icsPath.lastIndexOf("/") + 1)) }, 16 * 1024 * 1024)
              continue
            }
            // Notes dropped on a page come in as pages inside it; pictures, on it.
            if (Import.kindOf(path) !== "") notes.push(path)
            else if (i < 12 && Files.kindOf(path) === "image") view.workspace.importPicture(path, function(src) { if (src) editor.insertPicture(after, src, 0) })
            else if (i < 12 && view.page && !view.locked) {
              // Any other file: a file block (a video's, a video block).
              var made = editor.placeBlock(after || editor.uidAt(editor.model.count - 1), { type: Files.kindOf(path) === "video" ? "video" : "file" })
              after = made
              view.addFileTo(view.page.id, made, path)
            }
          }
          if (notes.length && view.page) view.importPaths(notes, view.page.id)
        }
      }
    }

    WheelHandler {
      id: wheel
      target: null
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) { scroller.wheel(event) }
    }
    // A trackpad as the fingers move (and on, gliding, when they lift); a wheel a step a notch.
    SmoothScroll { id: scroller; flick: flick; step: 90; notchMs: 120; speed: view.settings.scrollSpeed || "normal" }

    // No page open (none yet, or every one in the trash).
    Column {
      visible: view.page === null && view.tagShown === "" && !view.calendarShown && !view.libraryShown && !view.peopleShown && !view.templatesShown && view.workspace !== null && view.workspace.ready
      anchors.centerIn: parent
      spacing: 12
      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No page open"
        font.family: view.theme.uiFont
        font.pixelSize: 18
        color: view.theme.muted
      }
      IconButton {
        anchors.horizontalCenter: parent.horizontalCenter
        theme: view.theme; icon: view.theme.icons.newPage; label: "New page"
        onClicked: view.newPage("")
      }
    }

    // Over selected words: the toolbar.
    BubbleBar {
      id: bubble
      z: 6
      theme: view.theme
      editor: editor
      readonly property rect sel: {
        var s = editor.formatState
        var c = flick.contentY
        return editor.selectionRect()
      }
      readonly property point at: { var c = flick.contentY; return editor.mapToItem(main, sel.x, sel.y) }
      visible: editor.formatState.hasSelection === true && editor.selectedList.length === 0 && editor.slash === null && !view.locked
        && editor.formatState.type !== "code"
        && editor.dragUid === "" && editor.activeFocus && sel.width > 0
      x: Math.max(8, Math.min(main.width - width - 8, at.x + sel.width / 2 - width / 2))
      y: at.y - height - 8 < topBar.height ? at.y + sel.height + 8 : at.y - height - 8
      onLinkRequested: function(anchor) { linkPop.openAt(anchor) }
      onAgentRequested: view.openAgent("words")
    }

    // The microphone on: dictating, or an audio note recording on another page.
    RecordingBar {
      id: recordingBar
      objectName: "recordingBar"
      z: 6
      theme: view.theme
      readonly property bool elsewhere: view.recorder !== null && view.recorder.busy && view.recorder.kind === "audio"
        && !(view.page && editor.indexOf(view.recorder.owner) >= 0)
      visible: view.dictating || elsewhere
      label: view.dictating ? "Listening" : "Recording an audio note"
      listening: view.recorder !== null && view.recorder.phase === "recording"
      busyText: view.recorder && view.recorder.phase === "transcribing" ? "Writing it down\u2026" : "Saving\u2026"
      seconds: view.recorder ? view.recorder.elapsed : 0
      levels: view.recorder ? view.recorder.recent : []
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 26
      onDone: if (view.recorder) view.recorder.stop()
      onCanceled: if (view.recorder) view.recorder.cancel()
    }
    // A meeting started here, recording while another page is open.
    RecordingBar {
      id: meetingBar
      objectName: "meetingBar"
      z: 6
      theme: view.theme
      property real now: Date.now()
      Timer { interval: 1000; repeat: true; running: meetingBar.visible; onTriggered: meetingBar.now = Date.now() }
      readonly property var owner: view.meetings && view.meetings.meetingId ? view.meetingOwners[view.meetings.meetingId] || null : null
      visible: !recordingBar.visible && owner !== null && !(view.page && view.page.id === owner.pageId)
      label: view.meetings && view.meetings.status === "paused" ? "Meeting paused" : "Recording a meeting"
      listening: view.meetings !== null && view.meetings.finishing === ""
      busyText: "Writing it out\u2026"
      seconds: owner ? (now - owner.at) / 1000 : 0
      doneLabel: "Stop"
      cancelable: false
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 26
      onDone: if (view.meetings) view.meetings.stop(function(ok, problem) { if (!ok) view.toast(problem) })
    }

    FindBar {
      id: findBar
      z: 5
      theme: view.theme
      editor: editor
      anchors.horizontalCenter: parent.horizontalCenter
      y: topBar.height + 4
      onDone: view.forceActiveFocus()
    }
  }

  // ---- popovers -------------------------------------------------------------------------------

  SlashMenu {
    id: slashMenu
    theme: view.theme
    editor: editor
  }

  Connections {
    target: editor
    function onSlashChanged() {
      // (Closed even while it's still opening: `opened` isn't true till then,
      // and a quick pick would leave it up, empty.)
      if (editor.slash === null) { slashMenu.close(); return }
      var r = editor.slashRect()
      slashMenu.parent = editor
      slashMenu.x = r.x - 8
      var below = editor.mapToItem(view, 0, r.y + r.height).y + slashMenu.height + 20 < view.height
      slashMenu.y = below ? r.y + r.height + 6 : r.y - slashMenu.height - 6
      if (!slashMenu.opened) slashMenu.open()
    }
  }

  MentionMenu {
    id: mentionMenu
    theme: view.theme
    editor: editor
  }

  Connections {
    target: editor
    function onMentionChanged() {
      if (editor.mention === null) { mentionMenu.close(); return }
      var r = editor.mentionRect()
      mentionMenu.parent = editor
      mentionMenu.x = r.x - 8
      var below = editor.mapToItem(view, 0, r.y + r.height).y + mentionMenu.height + 20 < view.height
      mentionMenu.y = below ? r.y + r.height + 6 : r.y - mentionMenu.height - 6
      if (!mentionMenu.opened) mentionMenu.open()
    }
  }

  BlockMenu {
    id: blockMenu
    theme: view.theme
    editor: editor
    onToPageRequested: function(uid) { view.turnIntoPage(uid) }
    onSyncedRequested: function(uids) { view.makeSynced(uids) }
    onMindMapRequested: function(uids) {
      if (!editor.toMindMap(uids)) view.toast("A page or a sketch is among those blocks, and it would be lost: move it out first")
    }
    onAgentRequested: function(uids) { view.openAgent("blocks", uids) }
    onMoveRequested: function(uids) {
      view.movingBlocks = uids
      picker.purpose = "moveBlocks"
      picker.exclude = view.page ? view.page.id : ""
      picker.allowTop = false
      picker.openAt(main, "Move to\u2026")
    }
  }

  AgentPop {
    id: agentPop
    theme: view.theme
    files: view.workspace ? view.workspace.files : null
    service: view.service
    parent: view
    onSent: function(request) { view.askAgent(request, false) }
    onSentToTerminal: function(request) { view.askAgent(request, true) }
  }

  // Your agent at work, without a terminal: a panel at the bottom right.
  AgentPanel {
    id: workPanel
    theme: view.theme
    z: 40
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 20
    width: Math.min(420, view.width - 40)
    maxHeight: Math.max(220, view.height * 0.62)
    asks: view.agentAsks
    onAsked: function(key, how) { view.answerAgentAsk(key, how) }
    onStopRequested: view.stopAgent()
    onReplied: function(text) { view.replyToAgent(text) }
    onNewChatRequested: view.newChat()
    // (Closed: put away, kept with its page, to go back to. A new page it
    // left empty goes, unless it finished: it may be waiting for your
    // answer, there.)
    onDismissed: { view.agentTalk = null; view.agentPending = null; view.settleAgentPage(status === "done") }
    onTerminalRequested: {
      // (What it was doing here stops first: one agent at it, not two. The
      // page made for it stays: the terminal's to write it. The
      // conversation goes on there, not here.)
      if (view.agentRun) view.stopAgent()
      view.agentTalk = null
      view.settleAgentPage(true)
      if (!view.workspace || !view.agentRunPrompt) return
      view.workspace.files.launchAgent(view.agentRunPrompt)
      view.toast("Opened in a terminal: what it changes shows up here")
    }
  }

  // ---- a mind map's colors ----------------------------------------------------------------

  // The colors you picked last (newest first), kept as a setting.
  readonly property var recentColors: Colors.recentList(settings.recentColors || "")
  function rememberColor(hex) {
    if (service) service.setSetting("recentColors", Colors.withRecent(settings.recentColors || "", hex))
  }

  // The map whose idea is being colored.
  property string colorTarget: ""
  property point colorAt: Qt.point(0, 0)
  property bool customOpen: false
  function colorMap() {
    var item = editor.items[colorTarget]
    return item && item.mindMap ? item.mindMap : null
  }

  // The colors for the idea you're on, beside its color button (placed on
  // the page: the map is drawn again under them as colors change).
  function openIdeaColors(uid, anchor) {
    var m = editor.items[uid] ? editor.items[uid].mindMap : null
    if (!m || !m.current) return
    colorTarget = uid
    colorAt = anchor.mapToItem(view, anchor.width + 6, 0)
    ideaColors.currentText = m.current.color || ""
    ideaColors.currentBack = m.current.background || ""
    ideaColors.x = colorAt.x
    ideaColors.y = colorAt.y
    ideaColors.open()
  }

  function openCustomColor(kind) {
    var m = colorMap()
    if (!m || !m.current) return
    customOpen = true
    customColor.recent = recentColors
    customColor.x = colorAt.x
    customColor.y = colorAt.y
    customColor.start(kind, kind === "color" ? m.current.color : m.current.background, m.colorInfo())
  }

  // The table whose cells are being colored (its colorScope says which).
  property string tableColorTarget: ""
  property bool tableCustomOpen: false
  // (An audio note's colors use them too.)
  function colorTable() {
    var item = editor.items[tableColorTarget]
    return item ? item.tableView || item.audioView || item.meetingView || item.calView || item.dataView || null : null
  }

  // The colors for a table's cells, beside the button or handle they were
  // asked for from.
  function openTableColors(uid, anchor) {
    var t = editor.items[uid] ? editor.items[uid].tableView : null
    if (!t || !t.colorScope) return
    tableColorTarget = uid
    colorAt = anchor.mapToItem(view, anchor.width + 6, 0)
    var now = t.scopeColors()
    tableColors.currentText = now.color
    tableColors.currentBack = now.background
    tableColors.x = colorAt.x
    tableColors.y = colorAt.y
    tableColors.open()
  }

  function openTableCustom(kind) {
    var t = colorTable()
    if (!t || t.colorScope === null) return
    tableCustomOpen = true
    tableCustom.recent = recentColors
    tableCustom.x = colorAt.x
    tableCustom.y = colorAt.y
    var now = t.scopeColors()
    tableCustom.start(kind, kind === "color" ? now.color : now.background, t.colorInfo())
  }

  // The sketch whose pen color is being picked.
  property string sketchColorTarget: ""
  property bool sketchCustomOpen: false
  function colorSketch() {
    var item = editor.items[sketchColorTarget]
    return item && item.sketchView ? item.sketchView : null
  }

  function openSketchColors(uid, anchor) {
    var k = editor.items[uid] ? editor.items[uid].sketchView : null
    if (!k) return
    sketchColorTarget = uid
    colorAt = anchor.mapToItem(view, 0, anchor.height + 8)
    sketchColors.currentText = k.penColor
    sketchColors.currentBack = ""
    sketchColors.marker = k.tool === "marker"
    sketchColors.x = colorAt.x
    sketchColors.y = colorAt.y
    sketchColors.open()
  }

  function openSketchCustom() {
    var k = colorSketch()
    if (!k) return
    sketchCustomOpen = true
    sketchCustom.recent = recentColors
    sketchCustom.had = k.penColor
    sketchCustom.x = colorAt.x
    sketchCustom.y = colorAt.y
    sketchCustom.start("color", Colors.isHex(k.penColor) ? k.penColor : "", k.colorInfo())
  }

  HistoryPanel {
    id: historyPanel
    theme: view.theme
    workspace: view.workspace
    view: view
    parent: view
    onRestoreRequested: function(page, label) { view.restoreVersion(page, label) }
  }

  // A table's row or column menu (its handle).
  TableMenu {
    id: tableMenu
    theme: view.theme
    editor: editor
  }

  // Colors for a mind map's idea (its color button).
  ColorPop {
    id: ideaColors
    theme: view.theme
    editor: editor
    mode: "idea"
    parent: view
    recent: view.recentColors
    onIdeaPicked: function(kind, color) {
      var m = view.colorMap()
      if (m) m.setIdeaColor(kind, color)
    }
    onCustomRequested: function(kind) { view.openCustomColor(kind) }
    onClosed: {
      if (view.customOpen) return
      var m = view.colorMap()
      if (m) m.colorsClosed(false)
    }
  }

  // A tag's color (the tag view's palette).
  ColorPop {
    id: tagColors
    objectName: "tagColors"
    theme: view.theme
    editor: editor
    mode: "tag"
    parent: view
    recent: view.recentColors
    property bool customOpen: false
    onIdeaPicked: function(kind, color) { view.workspace.setTagColor(view.tagTarget, color) }
    onCustomRequested: function(kind) { customOpen = true; view.openTagCustom() }
  }

  // A tag's color of your own: shown as you pick, kept with Apply.
  ColorPicker {
    id: tagCustom
    objectName: "tagCustom"
    theme: view.theme
    parent: view
    onPreview: function(hex) { view.tagPreview = { name: view.tagTarget, color: hex } }
    onPicked: function(hex) {
      view.tagPreview = null
      view.workspace.setTagColor(view.tagTarget, hex)
      view.rememberColor(hex)
    }
    onCanceled: view.tagPreview = null
    onClosed: { view.tagPreview = null; tagColors.customOpen = false }
  }

  TagRename {
    id: tagRename
    theme: view.theme
    parent: view
    known: Workspace.tagList(view.index).map(function(t) { return t.name })
    onRenamed: function(to) { view.renameTag(to, view.tagTarget) }
  }

  // A tag's menu in the sidebar: its blocks, its color, renaming it, taking it off.
  Pop {
    id: tagMenu
    objectName: "tagMenu"
    theme: view.theme
    property string tag: ""
    property var anchor: null
    readonly property var info: { var r = view.workspace ? view.workspace.revision : 0; return Workspace.tagList(view.index).filter(function(t) { return t.name === tagMenu.tag })[0] || { label: "#" + tagMenu.tag, pages: 0, blocks: 0 } }
    focus: false
    width: 240
    contentItem: Column {
      spacing: 2
      Text {
        textFormat: Text.PlainText
        leftPadding: 10
        topPadding: 4
        bottomPadding: 4
        text: tagMenu.info.label + "  \u00b7  " + tagMenu.info.blocks + (tagMenu.info.blocks === 1 ? " block" : " blocks")
        font.family: view.theme.uiFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: view.theme.muted
      }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.open; text: "Every block with it"; onClicked: { tagMenu.close(); view.openTag(tagMenu.tag) } }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.palette; text: "Color"; hint: "\u203a"; onClicked: { var a = tagMenu.anchor; var t = tagMenu.tag; tagMenu.close(); view.openTagColors(a, t, true) } }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.pen; text: "Rename\u2026"; onClicked: { var a = tagMenu.anchor; var t = tagMenu.tag; tagMenu.close(); view.openTagRename(a, t, true) } }
      Rectangle { width: parent.width; height: 1; color: view.theme.line }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.trash; text: "Take it off every page"; danger: true; onClicked: { var t = tagMenu.tag; tagMenu.close(); view.removeTag(t) } }
    }
  }

  // A sketch's pen color (its color button).
  ColorPop {
    id: sketchColors
    objectName: "sketchColors"
    theme: view.theme
    editor: editor
    mode: "pen"
    parent: view
    recent: view.recentColors
    onIdeaPicked: function(kind, color) { var k = view.colorSketch(); if (k) k.setColor(color) }
    onCustomRequested: function(kind) { view.openSketchCustom() }
    onClosed: {
      if (view.sketchCustomOpen) return
      var k = view.colorSketch()
      if (k) k.colorsClosed()
    }
  }

  // A pen color of your own: the pen takes it as you pick; Cancel puts back
  // the one it had.
  ColorPicker {
    id: sketchCustom
    objectName: "sketchCustom"
    theme: view.theme
    parent: view
    // The pen's color before (to put back).
    property string had: ""
    onPreview: function(hex) { var k = view.colorSketch(); if (k) k.setColor(hex) }
    onPicked: function(hex) {
      var k = view.colorSketch()
      if (k) k.setColor(hex)
      view.rememberColor(hex)
    }
    onCanceled: { var k = view.colorSketch(); if (k) k.setColor(had) }
    onClosed: {
      view.sketchCustomOpen = false
      var k = view.colorSketch()
      if (k) k.colorsClosed()
    }
  }

  // Colors for a table's cells (the cell you're in, or a row or a column).
  ColorPop {
    id: tableColors
    objectName: "tableColors"
    theme: view.theme
    editor: editor
    mode: "idea"
    parent: view
    recent: view.recentColors
    onIdeaPicked: function(kind, color) { var t = view.colorTable(); if (t) t.applyColor(kind, color) }
    onCustomRequested: function(kind) { view.openTableCustom(kind) }
    onClosed: {
      if (view.tableCustomOpen) return
      var t = view.colorTable()
      if (t) t.colorsClosed(true)
    }
  }

  // A person named on a page, clicked: their card.
  ContactPop {
    id: contactPop
    objectName: "contactPop"
    theme: view.theme
    workspace: view.workspace
    parent: view
    onCopied: function(what) { view.copyText(what) }
    onEmailRequested: function(email) { view.mailTo(email) }
    onPeopleRequested: function(id) { view.openPeople(id) }
  }

  // A color of your own for them: shown in the table as you pick, kept with
  // Apply, put back with Cancel.
  ColorPicker {
    id: tableCustom
    objectName: "tableCustom"
    theme: view.theme
    parent: view
    onPreview: function(hex) { var t = view.colorTable(); if (t) t.previewColor(kind, hex) }
    onPicked: function(hex) {
      var t = view.colorTable()
      if (t) t.applyColor(kind, hex)
      view.rememberColor(hex)
    }
    onCanceled: { var t = view.colorTable(); if (t) t.cancelColor() }
    onClosed: {
      view.tableCustomOpen = false
      var t = view.colorTable()
      if (t) t.colorsClosed(true)
    }
  }

  // A color of your own for it: shown on the map as you pick, kept with
  // Apply, put back with Cancel.
  ColorPicker {
    id: customColor
    theme: view.theme
    parent: view
    onPreview: function(hex) { var m = view.colorMap(); if (m) m.previewIdeaColor(kind, hex) }
    onPicked: function(hex) {
      var m = view.colorMap()
      if (m) m.previewIdeaColor(kind, hex)
      view.rememberColor(hex)
    }
    onCanceled: { var m = view.colorMap(); if (m) m.previewIdeaColor(kind, original) }
    onClosed: {
      view.customOpen = false
      var m = view.colorMap()
      if (m) m.colorsClosed(true)
    }
  }

  LinkPop {
    id: linkPop
    theme: view.theme
    editor: editor
  }

  EmojiPop {
    id: emojiPop
    theme: view.theme
    property string target: "page"
    function openAt(anchor) {
      parent = anchor
      x = 0
      y = anchor.height + 6
      open()
    }
    onPicked: function(emoji) {
      if (target === "page") view.setIcon(emoji)
      else editor.setProp(view.pickFor, "icon", emoji)
    }
    onRemoved: if (target === "page") view.setIcon("")
  }

  CoverPop {
    id: coverPop
    theme: view.theme
    function openAt(anchor) {
      parent = anchor
      x = anchor.width - width
      y = -height - 8
      open()
    }
    onPicked: function(cover) { view.setCover(cover) }
    onUploadRequested: view.pictureRequested(function(path) {
      if (path) view.workspace.importPicture(path, function(src) { if (src) view.setCover(src) })
    })
  }

  ChoicePop {
    id: langPop
    theme: view.theme
    choices: Docs.LANGUAGES
    onPicked: function(value) { editor.setProp(view.pickFor, "lang", value === "Plain text" ? "" : value) }
  }

  PagePicker {
    id: picker
    theme: view.theme
    workspace: view.workspace
    property string purpose: "link"
    onPicked: function(id) {
      if (purpose === "link") editor.placeBlock(view.pickFor, { type: "link", target: id })
      else if (purpose === "relink") view.relink(view.pickFor, id)
      else if (purpose === "moveBlocks") view.moveBlocks(view.movingBlocks, id)
      else if (purpose === "movePage") view.movePage(view.moving, id)
    }
  }

  QuickFind {
    id: quickFind
    theme: view.theme
    workspace: view.workspace
    parent: view
    onPageChosen: function(id) { view.open(id) }
    onTagChosen: function(name) { view.openTag(name) }
  }

  ArchivePop {
    id: archivePop
    objectName: "archivePop"
    theme: view.theme
    workspace: view.workspace
    parent: view
    onOpenRequested: function(id) { view.open(id) }
    onUnarchiveRequested: function(id) { view.archivePage(id, false) }
  }

  TrashPop {
    id: trashPop
    theme: view.theme
    workspace: view.workspace
    parent: view
    onRestoreRequested: function(id) { view.restorePage(id) }
    onDeleteRequested: function(id) { view.deletePage(id) }
  }

  // Importing: files, or a whole folder (a Notion or Obsidian export).
  Pop {
    id: importMenu
    theme: view.theme
    focus: false
    width: 300
    contentItem: Column {
      spacing: 2
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.page; text: "Files\u2026"; hint: "Markdown, HTML, text, Word\u2026"; onClicked: { importMenu.close(); view.importRequested(false) } }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.folder; text: "A folder\u2026"; hint: "a Notion or Obsidian export"; onClicked: { importMenu.close(); view.importRequested(true) } }
    }
  }

  // A button set up: its words, what it does, its template.
  Pop {
    id: buttonSetup
    objectName: "buttonSetup"
    theme: view.theme
    property string uid: ""
    property int tick: 0
    readonly property var d: { var t = tick; return uid ? editor.dataOf(uid) : null }
    focus: true
    width: 340
    onOpened: buttonLabel.text = d ? d.label : ""
    onClosed: if (d && buttonLabel.text !== d.label) set({ label: buttonLabel.text })
    function set(fields) {
      var n = editor.dataOf(uid)
      if (!n) return
      for (var k in fields) n[k] = fields[k]
      editor.setData(uid, n)
      tick++
    }
    onUidChanged: tick++
    contentItem: Column {
      spacing: 8
      Field {
        id: buttonLabel
        objectName: "buttonLabel"
        theme: view.theme
        width: parent.width
        height: 34
        placeholder: "Its words (else the template's name)"
        onAccepted: buttonSetup.set({ label: text })
      }
      Row {
        spacing: 6
        Chip { objectName: "buttonInsert"; theme: view.theme; text: "Puts it in, here"; checked: buttonSetup.d && buttonSetup.d.action !== "page"; onClicked: buttonSetup.set({ action: "insert" }) }
        Chip { objectName: "buttonPage"; theme: view.theme; text: "Makes a page inside"; checked: buttonSetup.d && buttonSetup.d.action === "page"; onClicked: buttonSetup.set({ action: "page" }) }
      }
      Text { textFormat: Text.PlainText; leftPadding: 4; text: "Your templates"; visible: view.userTemplates.length > 0; font.family: view.theme.uiFont; font.pixelSize: 11; color: view.theme.muted }
      Repeater {
        model: view.userTemplates
        delegate: MenuRow {
          required property var modelData
          objectName: "buttonTemplate"
          width: parent.width; theme: view.theme
          icon: modelData.icon ? "" : view.theme.icons.templates
          text: (modelData.icon ? modelData.icon + "  " : "") + modelData.title
          checked: buttonSetup.d && buttonSetup.d.template === "tpl:" + modelData.id
          onClicked: buttonSetup.set({ template: "tpl:" + modelData.id })
        }
      }
      Text { textFormat: Text.PlainText; leftPadding: 4; text: "Uber Notebook's"; font.family: view.theme.uiFont; font.pixelSize: 11; color: view.theme.muted }
      Flow {
        objectName: "buttonBuiltins"
        width: parent.width
        spacing: 5
        Repeater {
          model: view.templates
          delegate: Chip {
            required property var modelData
            theme: view.theme
            icon: view.theme.icons[modelData.icon] || ""
            text: modelData.label
            checked: buttonSetup.d && buttonSetup.d.template === modelData.id
            onClicked: buttonSetup.set({ template: modelData.id })
          }
        }
      }
      Chip {
        objectName: "buttonDone"
        anchors.right: parent.right
        theme: view.theme
        text: "Done"
        checked: true
        onClicked: buttonSetup.close()
      }
    }
  }

  // "/synced": a new synced block, or one there is.
  Pop {
    id: syncedPick
    objectName: "syncedPick"
    theme: view.theme
    property string uid: ""
    focus: false
    width: 340
    readonly property var list: { var r = view.workspace ? view.workspace.revision : 0; return view.workspace ? Workspace.syncedPages(view.workspace.index).slice(0, 12) : [] }
    contentItem: Column {
      spacing: 2
      MenuRow {
        objectName: "syncedNew"
        width: parent.width; theme: view.theme; icon: view.theme.icons.plus; text: "A new synced block"
        hint: "write in it, then put it anywhere"
        onClicked: {
          syncedPick.close()
          var id = view.workspace.newSyncedPage([])
          view.putSynced(syncedPick.uid, id)
          view.open(id, false, { block: "" })
        }
      }
      Text { visible: syncedPick.list.length > 0; textFormat: Text.PlainText; leftPadding: 8; topPadding: 4; text: "Or one there is"; font.family: view.theme.uiFont; font.pixelSize: 11; color: view.theme.muted }
      Repeater {
        model: syncedPick.list
        delegate: MenuRow {
          required property var modelData
          objectName: "syncedChoice"
          width: parent.width; theme: view.theme; icon: view.theme.icons.synced
          text: { var t = view.workspace.texts[modelData.id] || ""; t = t.replace(/^Synced block\s*/, "").replace(/\s+/g, " ").trim(); return t.slice(0, 60) || "(empty)" }
          hint: { var n = Workspace.backlinks(view.workspace.index, modelData.id).length; return n === 1 ? "on 1 page" : "on " + n + " pages" }
          onClicked: { syncedPick.close(); view.putSynced(syncedPick.uid, modelData.id) }
        }
      }
    }
  }

  // The calendar's: an event to change, a new one typed, a question, its color.
  EventPop {
    id: eventPop
    objectName: "eventPop"
    theme: view.theme
    workspace: view.workspace
    view: view
    parent: view
  }
  QuickAddPop {
    id: quickAddPop
    objectName: "quickAddPop"
    theme: view.theme
    workspace: view.workspace
    view: view
    parent: view
  }
  Pop {
    id: askPop
    objectName: "askPop"
    theme: view.theme
    property string question: ""
    property var options: []
    property var then: null
    focus: false
    width: 280
    contentItem: Column {
      spacing: 2
      Text {
        textFormat: Text.PlainText
        leftPadding: 8
        bottomPadding: 4
        width: parent.width
        wrapMode: Text.Wrap
        text: askPop.question
        font.family: view.theme.uiFont
        font.pixelSize: 12
        color: view.theme.muted
      }
      Repeater {
        model: askPop.options
        delegate: MenuRow {
          required property var modelData
          objectName: "askOption"
          width: parent.width
          theme: view.theme
          icon: ""
          text: modelData.label
          onClicked: { var t = askPop.then; askPop.close(); if (t) t(modelData.value) }
        }
      }
    }
  }
  ColorPop {
    id: eventColors
    objectName: "eventColors"
    theme: view.theme
    editor: editor
    mode: "tag"
    noneLabel: "Accent"
    parent: view
    recent: view.recentColors
    onIdeaPicked: function(kind, color) { view.setEventColor(color) }
    onCustomRequested: function(kind) {
      var ev = view.workspace.eventById(view.eventColorTarget)
      eventCustom.recent = view.recentColors
      eventCustom.x = view.colorAt.x
      eventCustom.y = view.colorAt.y
      eventCustom.start("color", ev && Colors.isHex(ev.color) ? ev.color : "", { text: ev ? ev.title || "Event" : "Event", fill: String(view.theme.background), ownInk: "", pageInk: String(view.theme.text) })
    }
  }
  ColorPicker {
    id: eventCustom
    objectName: "eventCustom"
    theme: view.theme
    parent: view
    property string had: ""
    onPicked: function(hex) { view.setEventColor(hex); view.rememberColor(hex) }
  }

  // Pictures to choose, shown as pictures (a gallery's several, /image's one).
  PicturePicker {
    id: picturePicker
    anchors.fill: parent
    z: 62
    theme: view.theme
    files: view.workspace ? view.workspace.files : null
    onVisibleChanged: if (!visible) view.forceActiveFocus()
  }

  // Pictures shown large (a picture's, a gallery's), over the whole view.
  PictureViewer {
    id: viewer
    anchors.fill: parent
    z: 60
    theme: view.theme
    urlOf: function(src) { return view.workspace ? view.workspace.assetUrl(src) : src }
    onOpenRequested: function(src) { view.openAsset(src, src) }
    onCopyRequested: function(src) { view.copyPicture(src) }
    onSaveRequested: function(src, caption) { view.savePicture(src, caption) }
    onVisibleChanged: if (!visible) view.forceActiveFocus()
  }

  // An .ics file's events: what they are, which are on your calendar
  // already, and Add (those that aren't).
  Pop {
    id: icsPop
    objectName: "icsPop"
    theme: view.theme
    property var events: []
    property string fileName: ""
    readonly property var fresh: { var r = view.workspace ? view.workspace.calendarRevision : 0; return view.workspace ? events.filter(function(e) { return !Calendar.hasLike(view.workspace.calendar, e) }) : [] }
    width: 420
    padding: 18
    contentItem: Column {
      spacing: 10
      Column {
        width: parent.width
        spacing: 2
        Text {
          textFormat: Text.PlainText
          text: icsPop.events.length === 1 ? "An event" : icsPop.events.length + " events"
          font.family: view.theme.uiFont
          font.pixelSize: 15
          font.weight: Font.DemiBold
          color: view.theme.text
        }
        Text {
          visible: icsPop.fileName !== ""
          width: parent.width
          elide: Text.ElideMiddle
          textFormat: Text.PlainText
          text: icsPop.fileName
          font.family: view.theme.uiFont
          font.pixelSize: 12
          color: view.theme.muted
        }
      }
      Repeater {
        model: icsPop.events.slice(0, 6)
        delegate: Row {
          required property var modelData
          readonly property bool there: { var r = view.workspace ? view.workspace.calendarRevision : 0; return Calendar.hasLike(view.workspace.calendar, modelData) }
          objectName: "icsEvent"
          width: parent.width
          spacing: 10
          Rectangle { width: 3; height: eventText.height; radius: 1.5; color: Qt.alpha(view.theme.text, 0.3) }
          Column {
            id: eventText
            width: parent.width - 13
            spacing: 1
            Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: parent.parent.modelData.title; font.family: view.theme.uiFont; font.pixelSize: 13; font.weight: Font.Medium; color: view.theme.text }
            Text {
              width: parent.width
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: view.eventWhen(parent.parent.modelData) + (parent.parent.modelData.place ? "  \u00b7  " + parent.parent.modelData.place : "") + (parent.parent.there ? "  \u00b7  on your calendar" : "")
              font.family: view.theme.uiFont
              font.pixelSize: 12
              color: view.theme.muted
            }
          }
        }
      }
      Text {
        visible: icsPop.events.length > 6
        textFormat: Text.PlainText
        text: "and " + (icsPop.events.length - 6) + " more"
        font.family: view.theme.uiFont
        font.pixelSize: 12
        color: view.theme.muted
      }
      Text {
        visible: icsPop.fresh.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: icsPop.events.length === 1 ? "It's on your calendar already." : "They're on your calendar already."
        font.family: view.theme.uiFont
        font.pixelSize: 12
        color: view.theme.muted
      }
      Item { width: 1; height: 2 }
      Row {
        spacing: 8
        TextButton {
          objectName: "icsAdd"
          visible: icsPop.fresh.length > 0
          theme: view.theme
          primary: true
          text: icsPop.fresh.length === icsPop.events.length ? "Add to calendar" : "Add the " + icsPop.fresh.length + " new"
          onClicked: view.addIcsEvents()
        }
        TextButton { theme: view.theme; text: icsPop.fresh.length > 0 ? "Cancel" : "Close"; onClicked: icsPop.close() }
      }
    }
  }

  // A template to pick: to put here, for a new page inside one, or what new pages inside one start from.
  Pop {
    id: templatePick
    objectName: "templatePick"
    theme: view.theme
    property string mode: "insert"
    property string pageId: ""
    focus: false
    width: 320
    readonly property string current: { var r = view.workspace ? view.workspace.revision : 0; return mode === "child" && view.workspace && view.workspace.index.pages[pageId] ? view.workspace.index.pages[pageId].childTemplate || "" : "" }
    contentItem: Column {
      spacing: 2
      Text {
        textFormat: Text.PlainText
        leftPadding: 8
        bottomPadding: 4
        width: parent.width
        wrapMode: Text.Wrap
        text: templatePick.mode === "child" ? "New pages inside it start from" : templatePick.mode === "newIn" ? "A new page inside it, from" : "Put a template here"
        font.family: view.theme.uiFont
        font.pixelSize: 12
        color: view.theme.muted
      }
      MenuRow {
        visible: templatePick.mode === "child"
        width: parent.width; theme: view.theme; icon: view.theme.icons.page; text: "A blank page"
        checked: templatePick.current === ""
        onClicked: { templatePick.close(); view.workspace.setChildTemplate(templatePick.pageId, "") }
      }
      Repeater {
        model: view.userTemplates
        delegate: MenuRow {
          required property var modelData
          objectName: "templateChoice"
          width: parent.width
          theme: view.theme
          icon: modelData.icon ? "" : view.theme.icons.templates
          text: (modelData.icon ? modelData.icon + "  " : "") + modelData.title
          checked: templatePick.mode === "child" && templatePick.current === modelData.id
          onClicked: {
            templatePick.close()
            var id = modelData.id
            if (templatePick.mode === "child") view.workspace.setChildTemplate(templatePick.pageId, id)
            else if (templatePick.mode === "newIn") view.newPageFromTemplate(id, templatePick.pageId)
            else view.useTemplateHere(id, "insert")
          }
        }
      }
      Text {
        visible: templatePick.mode === "child" && view.userTemplates.length === 0
        textFormat: Text.PlainText
        leftPadding: 8
        width: parent.width
        wrapMode: Text.Wrap
        text: "No templates yet: Save as template, in a page's \u22ef menu."
        font.family: view.theme.uiFont
        font.pixelSize: 12
        color: view.theme.muted
      }
    }
  }

  // The meetings voxtype recorded, to put one in a meeting block.
  Pop {
    id: meetingPick
    objectName: "meetingPick"
    theme: view.theme
    property string uid: ""
    property var choices: []
    focus: false
    width: 340
    contentItem: Column {
      spacing: 2
      Text {
        textFormat: Text.PlainText
        leftPadding: 8
        bottomPadding: 4
        text: "Meetings voxtype recorded"
        font.family: view.theme.uiFont
        font.pixelSize: 12
        color: view.theme.muted
      }
      Repeater {
        model: meetingPick.choices
        delegate: MenuRow {
          required property var modelData
          objectName: "meetingChoice"
          width: parent.width
          theme: view.theme
          icon: view.theme.icons.people
          text: modelData.title || "Meeting"
          hint: [modelData.date, modelData.duration].filter(function(x) { return x }).join("  \u00b7  ")
          onClicked: {
            meetingPick.close()
            var id = modelData.id
            var uid = meetingPick.uid
            var title = modelData.title
            if (!view.page) return
            var pageId = view.page.id
            view.updateMeeting(pageId, uid, function(m) { m.id = id; m.title = title; return m }, function() { view.fetchMeeting(pageId, uid, id) })
          }
        }
      }
    }
  }

  // A page's menu in the sidebar.
  Pop {
    id: rowMenu
    theme: view.theme
    property string pageId: ""
    focus: false
    width: 230
    contentItem: Column {
      spacing: 2
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.newPage; text: "A page inside it"; onClicked: { rowMenu.close(); view.newPage(rowMenu.pageId) } }
      MenuRow {
        objectName: "rowFromTemplate"
        width: parent.width; theme: view.theme; icon: view.theme.icons.templates; text: "A page inside it, from a template\u2026"
        onClicked: { rowMenu.close(); view.openTemplatePick("newIn", rowMenu.pageId, rowMenu.parent) }
      }
      MenuRow {
        width: parent.width; theme: view.theme
        icon: view.workspace && view.workspace.isFavorite(rowMenu.pageId) ? view.theme.icons.star : view.theme.icons.starOutline
        text: view.workspace && view.workspace.isFavorite(rowMenu.pageId) ? "Out of Favorites" : "Add to Favorites"
        onClicked: { rowMenu.close(); view.toggleFavorite(rowMenu.pageId) }
      }
      MenuRow {
        objectName: "rowProject"
        width: parent.width; theme: view.theme; icon: view.theme.icons.briefcase
        readonly property bool isProject: { var r = view.workspace ? view.workspace.revision : 0; return !!(view.workspace && view.workspace.index.pages[rowMenu.pageId] && view.workspace.index.pages[rowMenu.pageId].project) }
        text: isProject ? "Not a project" : "Make it a project"
        onClicked: { rowMenu.close(); view.makeProjectOf(rowMenu.pageId, !isProject) }
      }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.duplicate; text: "Duplicate"; onClicked: { rowMenu.close(); view.duplicatePage(rowMenu.pageId) } }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.move; text: "Move to\u2026"; onClicked: { rowMenu.close(); view.movePageAsk(rowMenu.pageId) } }
      MenuRow { objectName: "rowArchive"; width: parent.width; theme: view.theme; icon: view.theme.icons.archive; text: "Archive"; onClicked: { rowMenu.close(); view.archivePage(rowMenu.pageId, true) } }
      Rectangle { width: parent.width; height: 1; color: view.theme.line }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.trash; text: "Move to the trash"; danger: true; onClicked: { rowMenu.close(); view.trashPage(rowMenu.pageId) } }
    }
  }

  // ---- keys -------------------------------------------------------------------------------------

  Keys.onPressed: function(e) { if (view.handleKey(e)) e.accepted = true }

  function handleKey(e) {
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    var alt = (e.modifiers & Qt.AltModifier) !== 0
    if (ctrl && !shift && !alt && e.key === Qt.Key_N) { newPage(""); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_P) { openFind(); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_Backslash) { sidebarShown = !sidebarShown; return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_F) { findBar.open(); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_J) { openAgent("auto"); return true }
    if (ctrl && shift && !alt && e.key === Qt.Key_D) { dictate(); return true }
    if (ctrl && shift && !alt && e.key === Qt.Key_R) { newAudioNote(); return true }
    if (ctrl && shift && !alt && e.key === Qt.Key_C) { openCalendar("", false); return true }
    if (alt && !ctrl && e.key === Qt.Key_Left) { back(); return true }
    if (alt && !ctrl && e.key === Qt.Key_Right) { forward(); return true }
    return false
  }
}
