import QtQuick

// voxtype's meeting mode, for tests: Meetings.qml's side the app sees. A
// meeting started is recording (its id `nextId`) until stop(); then it's
// written out, and fetch() has `exportJson` for it.
QtObject {
  id: fake
  property bool available: true
  property bool enabled: true
  property bool checked: true
  // Turned on here, voxtype not restarted since (Meetings.qml).
  property bool waiting: false
  readonly property string waitingText: "Meeting mode is on in voxtype's settings. It takes effect once voxtype restarts: log out and back in, or restart the voxtype service yourself."
  property string status: "idle"
  property string meetingId: ""
  property string finishing: ""
  property string working: ""
  property bool known: true

  property string nextId: "3f2a9c1e-7b4d-4e2a-9f1c-2b3c4d5e6f70"
  property var starts: []
  property var fetched: []
  property int enables: 0
  property var past: [{ id: "11111111-2222-3333-4444-555555555555", title: "Design review", date: "2026-10-01 14:00", duration: "12m 4s", status: "Completed" }]
  function exportFor(id) {
    return JSON.stringify({
      metadata: { id: id, title: "Weekly sync", startedAt: "2026-10-02T09:30:00+00:00", durationSecs: 95, status: "completed", chunkCount: 4 },
      transcript: { segments: [
        { id: 0, startMs: 1000, endMs: 4000, text: "Morning, everyone.", source: "microphone", speaker: "You", chunkId: 0 },
        { id: 1, startMs: 5000, endMs: 9000, text: "The release notes are done.", source: "loopback", speaker: "Remote", chunkId: 0 },
        { id: 2, startMs: 60000, endMs: 64000, text: "Ship it on Friday.", source: "microphone", speaker: "You", chunkId: 2 }
      ], totalChunks: 4, wordCount: 12, durationMs: 95000, speakers: ["You", "Remote"] }
    })
  }

  signal finished(string id)

  function check(done) { if (done) done() }
  function start(title, done) {
    if (!enabled) { done(false, "Meeting mode is off in voxtype's settings"); return }
    if (waiting) { done(false, waitingText); return }
    if (status !== "idle") { done(false, "A meeting is already being recorded"); return }
    starts = starts.concat([title])
    meetingId = nextId
    status = "recording"
    done(true, "")
  }
  function stop(done) {
    if (status === "idle") { if (done) done(false, "No meeting is being recorded"); return }
    var id = meetingId
    finishing = id
    if (done) done(true, "")
    Qt.callLater(function() { fake.status = "idle"; fake.meetingId = ""; fake.finishing = ""; fake.finished(id) })
  }
  function pause(done) { status = "paused"; if (done) done(true, "") }
  function resume(done) { status = "recording"; if (done) done(true, "") }
  function fetch(id, done) {
    fetched = fetched.concat([id])
    var json = exportFor(id)
    Qt.callLater(function() { done(true, json) })
  }
  function list(done) { var p = past; Qt.callLater(function() { done(p) }) }
  function enable(done) { enables++; enabled = true; waiting = true; Qt.callLater(function() { done(true, "") }) }
}
