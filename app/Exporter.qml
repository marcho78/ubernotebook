import QtQuick
import "../Export.js" as Export
import "../Equations.js" as Equations
import "../Diagram.js" as Diagram
import "../Blocks.js" as Blocks
import "../Workspace.js" as Workspace
import "../Library.js" as Library
import "../Html.js" as Html

// A page made a PDF, a Word file, or printed (a PDF opened in your PDF
// viewer, whose print dialog has your printers): Export.js writes it as HTML
// in a folder of its own (in $XDG_RUNTIME_DIR, only yours), equations drawn
// and diagrams made pictures; the files helper puts its pictures in and
// checks it (export-html); then Chromium (its own program, not the launcher
// that reads your flags; a profile of its own, no extensions, every request
// sent nowhere) or LibreOffice (a profile of its own) makes the file, each
// with no network at all where the system allows it (unshare: a network of
// its own, with nothing in it). The file's copied where you say (or to the
// Exports folder, as Settings says), never over one that's there unless you
// said so in the dialog; then its folder's taken away.
Item {
  id: ex

  property var workspace: null
  property var editor: null
  property var service: null
  property var settings: ({})
  signal toast(string text)

  // One at a time.
  property bool busy: false
  // The profile the one being made began in ({ gen, folder, root, assets }).
  property var from: null
  readonly property string movedWhy: "another profile was opened"
  function moved() {
    var w = workspace
    return !from || !w || w.generation !== from.gen || w.folder !== from.folder || !w.files || w.files.rootPath !== from.root
  }
  // What's installed: { browser, office, unshare }, once looked for.
  property var tools: null

  readonly property var browsers: ["/usr/lib/chromium/chromium", "/opt/google/chrome/chrome", "/opt/brave.com/brave/brave", "/usr/lib/chromium-browser/chromium-browser"]
  // A program it may run: a plain executable file (not a link) owned by root
  // that no one else can change; then whether unshare can give one no
  // network.
  readonly property string probeScript: "for f in \"$@\"; do "
    + "if [ -f \"$f\" ] && [ ! -L \"$f\" ] && [ -x \"$f\" ] && [ \"$(/usr/bin/stat -c %u -- \"$f\")\" = 0 ] "
    + "&& [ $(( 0$(/usr/bin/stat -c %a -- \"$f\") & 022 )) = 0 ]; then echo \"$f\"; fi; done; "
    + "/usr/bin/unshare --user --map-current-user --net -- /usr/bin/true 2>/dev/null && echo unshare; true"

  // (`need`: "browser", "office", or "any" for both: looked for again if it
  // wasn't there, so one installed since is found.)
  function probe(done, need) {
    if (tools && (!need || (need === "any" ? tools.browser && tools.office : tools[need]))) { done(tools); return }
    var files = workspace ? workspace.files : null
    if (!files) { done({ browser: "", office: "", unshare: false }); return }
    files.exec(["/usr/bin/bash", "-c", probeScript, "uber-notebook-export-tools"].concat(browsers, ["/usr/lib/libreoffice/program/soffice"]), function(ok, out) {
      var lines = String(out || "").split("\n")
      var t = { browser: "", office: "", unshare: lines.indexOf("unshare") >= 0 }
      lines.forEach(function(l) {
        if (!t.browser && ex.browsers.indexOf(l) >= 0) t.browser = l
        if (l === "/usr/lib/libreoffice/program/soffice") t.office = l
      })
      ex.tools = t
      done(t)
    }, { timeoutMs: 8000, maxBytes: 4096 })
  }

  // "pdf", "docx" or "print": the page `pageId` (`page`, as it is now),
  // and the pages inside it with `withPages`.
  function run(kind, page, withPages) {
    if (busy) { toast("Still making the last one"); return }
    if (!workspace || !page) return
    var files = workspace.files
    // (The profile it began in: another opened on the way, it stops at the
    // next step, its folder taken away; nothing is made from a mix of two.)
    from = { gen: workspace.generation, folder: workspace.folder, root: files.rootPath, assets: Workspace.assetsDir(files.rootPath) }
    probe(function(t) {
      if (ex.moved()) { toast("Not made: another profile was opened"); return }
      if (kind === "docx" && !t.office) { toast("A Word file needs LibreOffice: install it (omarchy pkg add libreoffice-fresh) and try again"); return }
      if (kind !== "docx" && !t.browser) { toast("A PDF needs Chromium: install it (omarchy pkg add chromium) and try again"); return }
      busy = true
      toast(kind === "print" ? "Getting it ready to print…" : kind === "docx" ? "Making the Word file…" : "Making the PDF…")
      var ids = withPages ? Workspace.withDescendants(workspace.index, page.id).filter(function(pid) { return pid === page.id || !Workspace.inTrash(workspace.index, pid) }) : [page.id]
      var others = ids.filter(function(pid) { return pid !== page.id })
      workspace.readPages(others, function(read) {
        if (ex.moved()) { ex.fail("", ex.movedWhy); return }
        var byId = {}
        read.forEach(function(p) { byId[p.id] = p })
        byId[page.id] = page
        var pages = ids.map(function(pid) { return byId[pid] }).filter(function(p) { return !!p })
        var work = files.runtimeDir + "/uber-notebook-export-" + Workspace.uuid4().slice(0, 8)
        // (A folder of its own, made new: never one that's there, which is
        // taken away after; one it couldn't make, it leaves.)
        workspace.readSyncedOf(pages, function() {
          if (ex.moved()) { ex.fail("", ex.movedWhy); return }
          files.exec(["/usr/bin/mkdir", "-m", "700", "--", work, work + "/drawings"], function(made) {
            if (!made) { ex.fail("", "its folder couldn't be made"); return }
            if (ex.moved()) { ex.fail(work, ex.movedWhy); return }
            ex.drawEquations(pages, function() {
              if (ex.moved()) { ex.fail(work, ex.movedWhy); return }
              ex.drawDiagrams(pages, work, function(drawings) {
                if (ex.moved()) { ex.fail(work, ex.movedWhy); return }
                ex.write(kind, pages, work, drawings, t)
              })
            })
          })
        })
      })
    }, kind === "docx" ? "office" : "browser")
  }

  // Every equation on them drawn (the editor's MathJax), or given up on
  // after a while (then its LaTeX is shown).
  function drawEquations(pages, done) {
    var wanted = []
    function add(tex, display) { if (tex) wanted.push({ tex: tex, display: display }) }
    pages.forEach(function(p) {
      for (var id in p.blocks) {
        var b = p.blocks[id]
        if (b.type === "code" && Equations.isLang(b.lang)) add(Html.plainText(b.html || ""), true)
        if (Blocks.isText(b.type)) Equations.inText(b.html || "").forEach(function(t) { add(t, false) })
        if (b.type === "table" && b.table) b.table.rows.forEach(function(r) { r.forEach(function(c) { Equations.inText(c).forEach(function(t) { add(t, false) }) }) })
      }
    })
    if (!wanted.length || !editor || typeof editor.mathOf !== "function") { done(); return }
    var tries = 0
    function check() {
      var left = wanted.filter(function(w) { return !editor.mathOf(w.tex, w.display) })
      if (!left.length || ++tries > 100 || ex.moved()) { done(); return }
      waiter.next = check
      waiter.restart()
    }
    check()
  }
  Timer { id: waiter; interval: 150; property var next: null; onTriggered: if (next) next() }

  // Each diagram made a picture, one after another: done({ blockId: name }).
  function drawDiagrams(pages, work, done) {
    var list = []
    pages.forEach(function(p) {
      for (var id in p.blocks) {
        var b = p.blocks[id]
        if (b.type === "code" && Diagram.isLang(b.lang)) list.push({ id: id, source: Html.plainText(b.html || "") })
      }
    })
    var out = {}
    var n = 0
    function next() {
      if (n >= list.length || !editor || typeof editor.drawingImage !== "function" || ex.moved()) { done(out); return }
      var d = list[n++]
      editor.drawingImage("diagram", d.source, { ink: Export.INK, back: "#ffffff" }, function(result) {
        var name = "d" + n + ".png"
        if (result && workspace.files.saveGrab(result, work + "/drawings/" + name)) out[d.id] = name
        Qt.callLater(next)
      })
    }
    next()
  }

  function write(kind, pages, work, drawings, t) {
    var files = workspace.files
    var top = pages[0]
    var format = top.format || {}
    var index = workspace.index.pages
    var html = Export.toHtml(pages, {
      title: top.title || "Untitled",
      paper: Qt.locale().measurementSystem === Locale.ImperialUSSystem ? "Letter" : "A4",
      small: format.size === "small",
      font: format.font || "sans",
      lookup: function(id) { var e = index[id]; return e ? { title: e.title || "Untitled", icon: e.icon } : null },
      math: function(tex, display) { var d = editor ? editor.mathOf(tex, display) : null; return d && d.svg ? d.svg : null },
      drawing: function(id) { return drawings[id] || "" },
      calendar: workspace.calendar,
      contactOf: function(id) { return workspace.contactById(id) },
      syncedPage: function(id) { return workspace.readPageNow(id) }
    })
    files.writeFile(work + "/page.src.html", html, function(wrote) {
      if (!wrote) { ex.fail(work, "it couldn't be written"); return }
      if (ex.moved()) { ex.fail(work, ex.movedWhy); return }
      files.helper(["export-html", ex.from.assets, work, String(512 * 1024 * 1024)], function(ok, out) {
        var r = files.parseJson(String(out || "").trim().split("\n").pop())
        if (!ok || !r || !r.ok) { ex.fail(work, r && r.error ? r.error : "its pictures couldn't be put in"); return }
        if (ex.moved()) { ex.fail(work, ex.movedWhy); return }
        ex.convert(kind, work, t, function(made) {
          if (!made) { ex.fail(work, kind === "docx" ? "LibreOffice couldn't make it" : "Chromium couldn't make it"); return }
          if (ex.moved()) { ex.fail(work, ex.movedWhy); return }
          ex.deliver(kind, made, top, work)
        })
      }, { timeoutMs: 120000, maxBytes: 64 * 1024 })
    })
  }

  // The file made from it: done(its path), or done("").
  function convert(kind, work, t, done) {
    var files = workspace.files
    var walled = t.unshare ? ["/usr/bin/unshare", "--user", "--map-current-user", "--net", "--"] : []
    var argv, made
    if (kind === "docx") {
      made = work + "/out/page.docx"
      argv = walled.concat([t.office, "--headless", "--norestore", "--nologo", "-env:UserInstallation=file://" + encodeURI(work) + "/lo",
        "--convert-to", "docx:MS Word 2007 XML", "--outdir", work + "/out", work + "/page.html"])
    } else {
      made = work + "/page.pdf"
      argv = walled.concat([t.browser, "--headless", "--disable-gpu", "--no-first-run", "--no-default-browser-check", "--disable-extensions",
        "--disable-background-networking", "--disable-component-update", "--disable-sync", "--disable-default-apps", "--disable-breakpad",
        "--mute-audio", "--user-data-dir=" + work + "/profile", "--proxy-server=http://127.0.0.1:9", "--host-resolver-rules=MAP * ~NOTFOUND",
        "--no-pdf-header-footer", "--print-to-pdf=" + made, "file://" + encodeURI(work) + "/page.html"])
    }
    files.exec(argv, function() {
      files.exec(["/usr/bin/test", "-s", made], function(there) { done(there ? made : "") })
    }, { timeoutMs: kind === "docx" ? 180000 : 120000, maxBytes: 1024 * 1024, okCodes: [0, 1] })
  }

  // Where it goes: printing, a folder of its own for it, opened in your PDF
  // viewer; else where you say (Settings: ask), or the Exports folder.
  function deliver(kind, made, top, work) {
    var files = workspace.files
    var ext = kind === "docx" ? ".docx" : ".pdf"
    var name = Library.saveName(top.title || "Untitled", "x" + ext)
    if (kind === "print") {
      var dir = files.runtimeDir + "/uber-notebook-print"
      files.mkdirs([dir], function() {
        // (What was printed a day ago or more goes.)
        files.exec(["/usr/bin/find", dir, "-maxdepth", "1", "-type", "f", "-name", "*.pdf", "-mmin", "+1440", "-delete"], function() {
          var to = dir + "/" + name
          files.exec(["/usr/bin/cp", "--", made, to], function(ok) {
            ex.done(work)
            if (!ok) { toast("It couldn't be got ready to print"); return }
            files.openPrint(to, function(opened) {
              toast(opened ? "Opened in your PDF viewer: print it from there" : "No app to print from: the PDF is " + to.replace(/^\/run\/user\/\d+/, "$XDG_RUNTIME_DIR"))
            })
          }, { timeoutMs: 30000 })
        })
      })
      return
    }
    function copyTo(to, overwrite) {
      files.exec(["/usr/bin/cp"].concat(overwrite ? [] : ["--update=none-fail"], ["--", made, to]), function(ok) {
        ex.done(work)
        toast(ok ? "Saved to " + to.replace(/^\/home\/[^\/]+/, "~") : "It couldn't be saved there")
      }, { timeoutMs: 60000 })
    }
    if (settings.exportTo === "folder" || !service || typeof service.pickSavePath !== "function") {
      var base = ex.from.root + "/Exports"
      files.mkdirs([base], function() { copyTo(base + "/" + name.replace(/(\.[a-z]+)$/, " " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HHmm") + "$1"), false) })
      return
    }
    // (Saving over a file that's there, the dialog asks first.)
    service.pickSavePath(name, function(to) {
      if (!to) { ex.done(work); toast("Not saved"); return }
      if (ex.moved()) { ex.fail(work, ex.movedWhy); return }
      copyTo(to, true)
    }, "document")
  }

  function done(work) {
    busy = false
    if (work) workspace.files.exec(["/usr/bin/rm", "-rf", "--", work], null)
  }
  function fail(work, why) {
    done(work)
    toast("It couldn't be made: " + why)
  }
}
