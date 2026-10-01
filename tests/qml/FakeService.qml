import QtQuick
import "../../Defaults.js" as Defaults
import "../../Settings.js" as Settings

// The service's settings side, for tests and the dev harness.
QtObject {
  property var store: null
  property var user: ({})
  readonly property var settings: Settings.merge(Defaults.DEFAULTS, user, Defaults.SCHEMA)
  property string rootPath: "/tmp/omanote-dev"
  property string version: "1.0.0"
  property string skillPath: "/tmp/omanote-dev-plugin/skills/omanote/SKILL.md"

  function setSetting(key, value) {
    var next = JSON.parse(JSON.stringify(user))
    next[key] = value
    user = next
  }
  function shortcutNote(event) { return event === "toggle" ? "Super + N" : "Super + Alt + N" }
  function pickPicture(done) { done("") }
}
