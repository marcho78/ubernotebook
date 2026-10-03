import QtQuick
import "../../Defaults.js" as Defaults
import "../../Settings.js" as Settings

// The service's settings side, for tests and the dev harness.
QtObject {
  id: fake
  property var store: null
  property var user: ({})
  readonly property var settings: Settings.merge(Defaults.DEFAULTS, user, Defaults.SCHEMA)
  property string rootPath: "/tmp/omanote-dev"
  property string version: "1.0.0"
  property string skillPath: "/tmp/omanote-dev-plugin/skills/omanote/SKILL.md"
  // The Markdown copy (Mirror.qml), as Settings shows it.
  property var mirror: QtObject { property string status: ""; property string problem: ""; property int files: 0; property var lastSync: null }
  readonly property string mirrorPath: rootPath + "/Markdown"
  function openMirror() {}

  function setSetting(key, value) {
    var next = JSON.parse(JSON.stringify(user))
    next[key] = value
    user = next
  }
  function setSettings(changes) {
    var next = JSON.parse(JSON.stringify(user))
    for (var k in changes) next[k] = changes[k]
    user = next
  }
  property string home: "/tmp"
  // Profiles (Profiles.qml), when a test has them (else none: no switch, no first run).
  property var profiles: null
  // What's open written before another profile opens (how many times), and
  // the folder a pick gets ("" as if it was called off).
  property int savedOpen: 0
  function saveOpen() { savedOpen++ }
  property string nextFolder: ""
  property string pickedFolder: ""
  function pickFolder(title, done) { pickedFolder = title; done(nextFolder) }
  function shortcutNote(event) { return event === "toggle" ? "Super + N" : "Super + Alt + N" }
  function pickPicture(done) { done("") }
  // The file a pick gets ("" as if it was called off), and what was asked for.
  property string nextFile: ""
  property string pickedKind: ""
  property string pickedFrom: ""
  function pickFile(kind, done, from) { pickedKind = kind; pickedFrom = from || ""; done(nextFile) }
  // The pictures a pick gets ([] as if it was called off).
  property var nextPictures: []
  function pickPictures(done) { done(nextPictures) }
  // The microphone (FakeRecorder.qml).
  property var recorder: FakeRecorder { input: fake.settings.audioInput || ""; boost: fake.settings.audioBoost !== false }
  // voxtype's meetings (FakeMeetings.qml).
  property var meetings: FakeMeetings {}
  // The update check (Updates.qml) and backups (Backups.qml), when a test has them.
  property var updates: null
  property var backups: null
}
