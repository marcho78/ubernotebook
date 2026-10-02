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
  function shortcutNote(event) { return event === "toggle" ? "Super + N" : "Super + Alt + N" }
  function pickPicture(done) { done("") }
  // The microphone (FakeRecorder.qml).
  property var recorder: FakeRecorder { input: fake.settings.audioInput || ""; boost: fake.settings.audioBoost !== false }
}
