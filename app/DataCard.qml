import QtQuick
import "../Blocks.js" as Blocks
import "../Docs.js" as Docs
import "../Colors.js" as Colors

// What the newer blocks in Pages share (a button, a file, a video, a
// bookmark, a board, a synced block): their info from the page, a change
// kept as a step to undo, and their colors, an accent (`color`) and the
// card's (`background`), each one of Pages' colors or your own, picked from
// DocView's color menu.
Item {
  id: dc

  property var editor: null
  property string uid: ""
  // Its block's type, and its info (JSON) as the page has it.
  property string kind: ""
  property string source: ""
  property real available: 600
  property color ink: "black"
  readonly property bool readOnly: editor ? editor.readOnly : true
  readonly property var theme: editor ? editor.theme : null
  readonly property bool dark: editor ? editor.dark : false

  property var info: Blocks.cleanData(kind, {})
  property string written: ""
  // Colors shown while they're picked (not kept yet).
  property var trying: null
  readonly property var look: trying || info

  onSourceChanged: if (source !== written) load()
  Component.onCompleted: load()
  signal loaded()
  function load() {
    var raw = null
    try { raw = JSON.parse(source || "{}") } catch (e) { raw = null }
    written = source
    info = Blocks.cleanData(kind, raw)
    loaded()
  }

  // A change kept, as a step to undo.
  function change(fields) {
    var next = JSON.parse(JSON.stringify(info))
    for (var k in fields) next[k] = fields[k]
    var clean = Blocks.cleanData(kind, next)
    written = JSON.stringify(clean)
    info = clean
    editor.setData(uid, clean)
  }

  function act(what, arg) { editor.dataAction(uid, what, arg) }

  // ---- colors ----

  function textOf(id) { var c = Docs.colorEntry(id); return c ? c.text[dark ? 1 : 0] : Colors.normalize(id) }
  function backOf(id) { var c = Docs.colorEntry(id); return c ? c.background[dark ? 1 : 0] : Colors.normalize(id) }
  readonly property string inkHex: Colors.normalize(String(ink)) || "#000000"
  readonly property string paperHex: Colors.normalize(String(editor ? editor.paper : "#ffffff")) || "#ffffff"
  readonly property string fillHex: look.background ? backOf(look.background) : ""
  readonly property color fill: fillHex ? fillHex : Qt.alpha(ink, dark ? 0.06 : 0.035)
  readonly property color words: fillHex && Colors.isHex(look.background) ? Colors.readableOn(fillHex, inkHex) : ink
  readonly property color faint: Qt.alpha(words, 0.55)
  readonly property color accent: look.color ? textOf(look.color) : (editor ? editor.accent : "#2456b3")
  // A mark on the accent: white or black, whichever reads.
  readonly property string onAccent: Colors.contrast(Colors.normalize(String(accent)) || "#2456b3", "#ffffff") >= 2.6 ? "#ffffff" : "#14161c"

  function askColors(anchor) { if (!readOnly) act("colors", anchor) }
  function scopeColors() { return { color: info.color || "", background: info.background || "" } }
  function colorInfo() {
    return { text: sample(), fill: info.background ? backOf(info.background) : paperHex, ownInk: info.color ? textOf(info.color) : "", pageInk: inkHex }
  }
  function sample() { return "Sample" }
  // What the color menu says it colors (a board: a card, a column, or all of it).
  function colorSubject() { return "" }
  function previewColor(k, value) { var t = JSON.parse(JSON.stringify(info)); t[k === "background" ? "background" : "color"] = value; trying = t }
  function applyColor(k, value) { trying = null; var f = {}; f[k === "background" ? "background" : "color"] = value; change(f) }
  function cancelColor() { trying = null }
  function colorsClosed(refocus) { trying = null }

  readonly property bool pointerIn: hover.hovered
  HoverHandler { id: hover }
}
