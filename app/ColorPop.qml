import QtQuick
import QtQuick.Controls
import "../Docs.js" as Docs
import "../Colors.js" as Colors
import "../Sketch.js" as Sketch

// Colors in Pages: for text, or behind it. On the words selected ("words"),
// on whole blocks ("blocks": their text, or their background), on a mind
// map's idea or a table's cells ("idea": ideaPicked says which), or for a
// sketch's pen ("pen": one color, as dots of ink). An idea can also have a color
// of its own: the colors you picked last are there, and Custom… opens the
// color picker (customRequested); the idea's colors now are marked.
Pop {
  id: pop

  property var editor: null
  property string mode: "words"
  property var uids: []

  signal ideaPicked(string kind, string color)
  signal customRequested(string kind)

  // For an idea: its colors now ("red", "#ff8800", or ""), and the colors
  // you picked last.
  property string currentText: ""
  // What "no color" is called (a tag with none takes its parent's).
  property string noneLabel: ""
  property string currentBack: ""
  property var recent: []
  // What's being colored, said at the top ("Card: Book the venue"), if anything.
  property string subject: ""
  onClosed: subject = ""

  // A row's colors of your own: the idea's (if it has one), then the
  // recent ones, four in all (Custom… is the fifth).
  function customsFor(current) {
    var list = recent.slice()
    var own = Colors.normalize(current)
    if (own && Colors.isHex(current) && list.indexOf(own) < 0) list.unshift(own)
    return list.slice(0, 4)
  }

  function pickCustom(kind, hex) {
    close()
    ideaPicked(kind, hex)
  }

  function openCustom(kind) {
    customRequested(kind)
    close()
  }

  focus: false
  width: 5 * 38 + 4 * 4 + 2 * padding
  padding: 12

  // One color, as dots: a sketch's pen ("pen"), or a tag ("tag").
  readonly property bool pen: mode === "pen" || mode === "tag"
  // The pen is a highlighter: its colors are a highlighter's.
  property bool marker: false
  readonly property bool own: mode === "idea" || mode === "pen" || mode === "tag"

  function pickText(c) {
    close()
    if (own) ideaPicked("color", c ? c.id : "")
    else if (mode === "blocks") editor.setBlockColor(uids, c ? c.id : "")
    else editor.formatInline("color", c ? c.text[0] : "")
  }

  function pickBackground(c) {
    close()
    if (mode === "idea") ideaPicked("background", c ? c.id : "")
    else if (mode === "blocks") editor.setBlockColor(uids, c ? c.id + "_background" : "")
    else editor.formatInline("highlight", c ? c.background[0] : "")
  }

  component Heading: Text {
    textFormat: Text.PlainText
    font.family: pop.theme.uiFont
    font.pixelSize: 11
    font.weight: Font.DemiBold
    color: pop.theme.muted
  }

  component Tile: Rectangle {
    id: tile
    property var entry: null
    // A color of your own ("#ff8800"), instead of one of Pages'.
    property string custom: ""
    // Custom…: the color picker.
    property bool plus: false
    property bool back: false
    // The idea has this color now.
    property bool chosen: false
    signal picked()
    readonly property string fg: custom !== "" ? custom : entry ? entry.text[pop.theme.dark ? 1 : 0] : String(pop.mode === "tag" ? pop.theme.muted : pop.theme.text)
    readonly property string bg: custom !== "" ? custom : entry ? entry.background[pop.theme.dark ? 1 : 0] : "transparent"
    width: 38
    height: 38
    radius: 7
    color: tileHover.hovered ? pop.theme.hover : "transparent"
    border.width: chosen ? 2 : 0
    border.color: pop.theme.accent
    // A pen's color: a dot of the ink.
    Rectangle {
      visible: pop.pen && !tile.plus
      anchors.centerIn: parent
      width: 22
      height: 22
      radius: 11
      color: pop.marker && tile.custom === "" ? Sketch.markerHex(tile.entry ? tile.entry.id : "", pop.theme.dark, String(pop.theme.text)) : tile.fg
      border.width: 1
      border.color: Qt.alpha("#000000", 0.18)
    }
    Rectangle {
      visible: !tile.plus && !pop.pen
      anchors.centerIn: parent
      width: 26
      height: 26
      radius: 5
      color: tile.back ? tile.bg : "transparent"
      border.width: 1
      border.color: pop.theme.line
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "A"
        font.family: pop.theme.uiFont
        font.pixelSize: 15
        font.weight: Font.DemiBold
        color: !tile.back ? tile.fg : tile.custom !== "" ? Colors.readableOn(tile.custom, String(pop.theme.text)) : pop.theme.text
      }
    }
    // Custom…: a ring of every hue around a plus.
    Rectangle {
      visible: tile.plus
      anchors.centerIn: parent
      width: 26
      height: 26
      radius: 13
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0 / 6; color: "#ff4d4d" }
        GradientStop { position: 1 / 6; color: "#ffd84d" }
        GradientStop { position: 2 / 6; color: "#5ce65c" }
        GradientStop { position: 3 / 6; color: "#4de6e6" }
        GradientStop { position: 4 / 6; color: "#4d79ff" }
        GradientStop { position: 5 / 6; color: "#d94dff" }
        GradientStop { position: 6 / 6; color: "#ff4d4d" }
      }
      Rectangle {
        anchors.centerIn: parent
        width: 16
        height: 16
        radius: 8
        color: pop.theme.surface
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "+"
          font.family: pop.theme.uiFont
          font.pixelSize: 14
          font.weight: Font.Bold
          color: pop.theme.text
        }
      }
    }
    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.picked() }
    ToolTip.visible: tileHover.hovered
    ToolTip.delay: 500
    ToolTip.text: tile.plus ? "A color of your own\u2026" : tile.custom !== "" ? tile.custom + (back ? " background" : "")
      : (entry ? entry.label : pop.mode === "tag" ? (pop.noneLabel || "Gray") : pop.pen ? "The page's ink" : "Default") + (back ? " background" : "")
  }

  contentItem: Column {
    spacing: 8
    Text {
      objectName: "colorSubject"
      visible: pop.subject !== ""
      width: parent.width
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: pop.subject
      font.family: pop.theme.uiFont
      font.pixelSize: 13
      font.weight: Font.DemiBold
      color: pop.theme.text
    }
    Heading { text: pop.mode === "blocks" ? "Color" : pop.mode === "tag" ? "Tag color" : pop.pen ? "Ink" : "Text color" }
    Flow {
      width: parent.width
      spacing: 4
      Tile { entry: null; chosen: pop.own && pop.currentText === ""; onPicked: pop.pickText(null) }
      Repeater {
        model: Docs.COLORS
        delegate: Tile {
          required property var modelData
          entry: modelData
          chosen: pop.own && pop.currentText === modelData.id
          onPicked: pop.pickText(modelData)
        }
      }
      Repeater {
        model: pop.own ? pop.customsFor(pop.currentText) : []
        delegate: Tile {
          required property var modelData
          custom: modelData
          chosen: Colors.normalize(pop.currentText) === modelData
          onPicked: pop.pickCustom("color", modelData)
        }
      }
      Tile { visible: pop.own; plus: true; onPicked: pop.openCustom("color") }
    }
    Heading { visible: !pop.pen; text: "Background" }
    Flow {
      visible: !pop.pen
      width: parent.width
      spacing: 4
      Tile { entry: null; back: true; chosen: pop.mode === "idea" && pop.currentBack === ""; onPicked: pop.pickBackground(null) }
      Repeater {
        model: Docs.COLORS
        delegate: Tile {
          required property var modelData
          entry: modelData
          back: true
          chosen: pop.mode === "idea" && pop.currentBack === modelData.id
          onPicked: pop.pickBackground(modelData)
        }
      }
      Repeater {
        model: pop.mode === "idea" ? pop.customsFor(pop.currentBack) : []
        delegate: Tile {
          required property var modelData
          custom: modelData
          back: true
          chosen: Colors.normalize(pop.currentBack) === modelData
          onPicked: pop.pickCustom("background", modelData)
        }
      }
      Tile { visible: pop.mode === "idea"; plus: true; back: true; onPicked: pop.openCustom("background") }
    }
  }
}
