import QtQuick
import "Updates.js" as Updates

// Whether there's a newer Uber Notebook (Updates.js): GitHub's list of the
// project's releases (the manifest's homepage), asked a minute after
// Uber Notebook starts and once a day after that while Settings has it on, and
// whenever you ask. It's one plain request for that list: nothing of yours
// goes with it. A newer one shows in the sidebar, on the shelf and in
// Settings, with its notes and the command that installs it (`omarchy plugin
// update`), to run in a terminal: it shows what changes and asks first.
// Uber Notebook never installs anything itself.
Item {
  id: up

  // Store.qml: programs to run (exec), files to read (readNow).
  property var files: null
  property string current: "1.1.1"
  property string homepage: ""
  property string pluginDir: ""
  property string pluginId: ""
  // Asked once a day by itself (Settings → About), or only when you ask.
  property bool automatic: true

  readonly property string repo: Updates.repoOf(homepage)
  // "idle" (not asked yet), "checking", "current" (up to date), "available",
  // "none" (no releases published yet), "failed" (`problem` says why).
  property string status: "idle"
  property string problem: ""
  // The newer releases, newest first ([{ version, tag, name, notes, url, date }]).
  property var newer: []
  readonly property var latest: newer.length ? newer[0] : null
  readonly property bool available: newer.length > 0
  property var checkedAt: null
  // A git checkout, so `omarchy plugin update` can update it.
  property bool managed: false
  readonly property string updateCommand: "omarchy plugin update " + pluginId

  readonly property string curlScript: "/usr/bin/curl -q -sS -L --proto =https --proto-redir =https --max-time 15 --max-filesize 2000000 -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' -A 'Uber Notebook' -w '\\n%{http_code}' -- \"$1\""

  function check(done) {
    if (status === "checking") { if (done) done(); return }
    if (!repo || !files) { status = "failed"; problem = "There's no GitHub page to ask (the manifest's homepage)."; if (done) done(); return }
    status = "checking"
    problem = ""
    files.exec(["/usr/bin/bash", "-c", curlScript, "uber-notebook-update", Updates.releasesUrl(repo)], function(ok, out) {
      up.checkedAt = new Date()
      if (!ok) {
        up.status = "failed"
        up.problem = "Couldn't reach GitHub" + (String(out || "").trim() ? ": " + String(out).trim().split("\n").pop().replace(/^curl: \(\d+\)\s*/, "").slice(0, 160) : ".")
      } else {
        var r = Updates.response(out)
        var list = r.code === 200 ? Updates.releases(r.body) : null
        if (r.code === 404 || (list && list.length === 0)) { up.newer = []; up.status = "none" }
        else if (list) { up.newer = Updates.newer(list, up.current); up.status = up.newer.length ? "available" : "current" }
        else {
          up.status = "failed"
          up.problem = r.code === 403 || r.code === 429 ? "GitHub says to ask again later." : "GitHub answered " + (r.code || "with nothing") + "."
        }
      }
      if (done) done()
    }, { timeoutMs: 20000, maxBytes: 2 * 1024 * 1024 })
  }

  // What's new: the newer releases' notes, or (up to date, or `own`) this
  // version's, from CHANGELOG.md. { title, markdown, url }.
  function notes(own) {
    if (newer.length && !own) return { title: newer.length === 1 ? "What's new in " + newer[0].version : "What's new since " + current, markdown: Updates.combined(newer), url: newer[0].url }
    var text = files ? files.readNow(pluginDir + "/CHANGELOG.md", 4 * 1024 * 1024) : null
    var own = text ? Updates.fromChangelog(text, current) : null
    return { title: "What's in " + current, markdown: own ? own.notes : "The notes for this version aren't here.", url: "" }
  }

  // How it is, for agents: { version, latest, updateAvailable, status, ... }.
  function summary() {
    return {
      version: current,
      latest: latest ? latest.version : current,
      updateAvailable: available,
      status: status,
      problem: problem,
      checked: checkedAt ? checkedAt.toISOString() : "",
      automatic: automatic,
      update: managed ? "the user runs " + updateCommand + " in a terminal (it shows the changes and asks first)" : "reinstall from git (omarchy plugin add <its git URL>) to update with omarchy plugin update",
      releases: newer.map(function(r) { return { version: r.version, name: r.name, date: r.date, url: r.url } })
    }
  }

  Component.onCompleted: {
    if (files && pluginDir) files.exec(["/usr/bin/test", "-d", pluginDir + "/.git"], function(ok) { up.managed = ok }, { okCodes: [0] })
  }

  // A minute after starting, then once a day.
  Timer {
    id: firstCheck
    interval: 60 * 1000
    running: up.automatic && up.repo !== ""
    onTriggered: up.check()
  }
  Timer {
    interval: 24 * 3600 * 1000
    running: up.automatic && up.repo !== ""
    repeat: true
    onTriggered: up.check()
  }
}
