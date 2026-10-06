import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// A color of your own, for a mind map's idea: a square of saturation and
// brightness for the hue picked on the strip under it, its hex to type or
// paste, the colors you picked last, and the idea as it looks with it (with
// how well its text reads). What you pick shows on the map as you pick it;
// Apply (or Enter) keeps it, Cancel (or Esc, or a click away) puts back what
// was there.
Pop {
  id: picker

  // "color" (the idea's text) or "background".
  property string kind: "color"
  // The idea now: { text, fill, ownInk (its own text color, or ""), pageInk }, all hex.
  property var info: ({ text: "Idea", fill: "#ffffff", ownInk: "", pageInk: "#000000" })
  property var recent: []
  // What it had before, to put back.
  property string original: ""

  property real hue: 210
  property real sat: 0.7
  property real val: 0.9
  readonly property string hex: Colors.fromHsv(hue, sat, val)
  property bool applied: false
  property bool ready: false
  property bool typing: false
  // You've picked something: until then, the map shows what it had.
  property bool touched: false

  // The idea as it would look, and how well its text reads.
  readonly property string sampleFill: kind === "background" ? hex : info.fill
  readonly property string sampleInk: kind === "color" ? hex : (info.ownInk || Colors.readableOn(hex, info.pageInk))
  readonly property real ratio: Colors.contrast(sampleInk, sampleFill)

  signal preview(string hex)
  signal picked(string hex)
  signal canceled()

  // Clicks away close it without reaching the page under it.
  modal: true
  dim: false
  width: 300
  padding: 14

  function start(k, current, about) {
    kind = k
    original = current || ""
    info = about
    applied = false
    touched = false
    var from = Colors.normalize(current) || Colors.normalize(k === "color" ? about.ownInk || about.pageInk : about.fill) || "#3584e4"
    show(from, false)
    open()
    hexField.focusField()
  }

  // The square and the strip at a color (`picked`: by you, so it shows).
  function show(color, picked) {
    var c = Colors.toHsv(color)
    ready = false
    // A gray has no hue of its own: the strip stays where it was.
    if (c.s > 0 && c.v > 0) hue = c.h
    sat = c.s
    val = c.v
    ready = true
    if (!typing) hexField.text = color
    if (picked) {
      touched = true
      preview(hex)
    }
  }

  onHexChanged: {
    if (!ready) return
    if (!typing) hexField.text = hex
    if (touched) preview(hex)
  }

  // Apply with nothing picked keeps what was there (a color of Pages stays
  // one, and follows the theme).
  function apply() {
    applied = true
    if (touched) picked(hex)
    close()
  }

  onClosed: if (!applied) canceled()

  function clamp(x) { return Math.max(0, Math.min(1, x)) }

  component Heading: Text {
    textFormat: Text.PlainText
    font.family: picker.theme.uiFont
    font.pixelSize: 11
    font.weight: Font.DemiBold
    color: picker.theme.muted
  }

  contentItem: Column {
    spacing: 12

    Heading { text: picker.kind === "background" ? "Background of your own" : "Text color of your own" }

    // Saturation across, brightness down, for the hue below.
    Item {
      id: square
      width: parent.width
      height: 170
      Rectangle { anchors.fill: parent; radius: 8; color: Colors.fromHsv(picker.hue, 1, 1) }
      Rectangle {
        anchors.fill: parent
        radius: 8
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: "#ffffffff" }
          GradientStop { position: 1; color: "#00ffffff" }
        }
      }
      Rectangle {
        anchors.fill: parent
        radius: 8
        border.width: 1
        border.color: picker.theme.line
        gradient: Gradient {
          GradientStop { position: 0; color: "#00000000" }
          GradientStop { position: 1; color: "#ff000000" }
        }
      }
      Rectangle {
        width: 18
        height: 18
        radius: 9
        x: picker.sat * square.width - width / 2
        y: (1 - picker.val) * square.height - height / 2
        color: picker.hex
        border.width: 2
        border.color: "#ffffff"
        Rectangle { anchors.fill: parent; anchors.margins: -1; radius: 10; color: "transparent"; border.width: 1; border.color: "#59000000" }
      }
      MouseArea {
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.CrossCursor
        function at(m) {
          picker.touched = true
          picker.sat = picker.clamp(m.x / width)
          picker.val = 1 - picker.clamp(m.y / height)
        }
        onPressed: function(m) { at(m) }
        onPositionChanged: function(m) { if (pressed) at(m) }
      }
    }

    // The hue.
    Item {
      id: strip
      width: parent.width
      height: 14
      Rectangle {
        anchors.fill: parent
        radius: 7
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0 / 6; color: "#ff0000" }
          GradientStop { position: 1 / 6; color: "#ffff00" }
          GradientStop { position: 2 / 6; color: "#00ff00" }
          GradientStop { position: 3 / 6; color: "#00ffff" }
          GradientStop { position: 4 / 6; color: "#0000ff" }
          GradientStop { position: 5 / 6; color: "#ff00ff" }
          GradientStop { position: 6 / 6; color: "#ff0000" }
        }
      }
      Rectangle {
        width: 20
        height: 20
        radius: 10
        x: picker.hue / 360 * strip.width - width / 2
        y: (strip.height - height) / 2
        color: Colors.fromHsv(picker.hue, 1, 1)
        border.width: 2
        border.color: "#ffffff"
        Rectangle { anchors.fill: parent; anchors.margins: -1; radius: 11; color: "transparent"; border.width: 1; border.color: "#59000000" }
      }
      MouseArea {
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function at(m) {
          picker.touched = true
          picker.hue = picker.clamp(m.x / width) * 359.99
        }
        onPressed: function(m) { at(m) }
        onPositionChanged: function(m) { if (pressed) at(m) }
      }
    }

    // The idea with it, and its hex.
    Row {
      width: parent.width
      spacing: 10
      Rectangle {
        id: sample
        width: 140
        height: 36
        radius: 8
        color: picker.sampleFill
        border.width: 1
        border.color: picker.theme.line
        Text {
          anchors.centerIn: parent
          width: parent.width - 16
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: picker.info.text || "Idea"
          font.family: picker.theme.uiFont
          font.pixelSize: 14
          font.weight: Font.DemiBold
          color: picker.sampleInk
        }
      }
      Field {
        id: hexField
        theme: picker.theme
        width: parent.width - sample.width - 10
        height: 36
        fontSize: 14
        maximumLength: 7
        placeholder: "#rrggbb"
        onEdited: function(text) {
          var c = Colors.normalize(text)
          if (!c || !Colors.isHex(text)) return
          picker.typing = true
          picker.show(c, true)
          picker.typing = false
        }
        onAccepted: picker.apply()
        onEscaped: picker.close()
      }
    }

    // How well the idea's text reads on its background.
    Text {
      width: parent.width
      textFormat: Text.PlainText
      readonly property string rating: Colors.rating(picker.ratio)
      text: "Contrast " + picker.ratio.toFixed(1) + ":1 \u00b7 "
        + (rating === "good" ? "easy to read" : rating === "fair" ? "readable, not at small sizes" : "hard to read")
      font.family: picker.theme.uiFont
      font.pixelSize: 12
      color: rating === "poor" ? picker.theme.urgent : picker.theme.muted
    }

    // The colors you picked last.
    Column {
      visible: picker.recent.length > 0
      width: parent.width
      spacing: 6
      Heading { text: "Recent" }
      Flow {
        width: parent.width
        spacing: 6
        Repeater {
          model: picker.recent
          delegate: Rectangle {
            id: swatch
            required property var modelData
            width: 26
            height: 26
            radius: 6
            color: modelData
            border.width: Colors.normalize(picker.hex) === modelData ? 2 : 1
            border.color: Colors.normalize(picker.hex) === modelData ? picker.theme.accent : picker.theme.line
            HoverHandler { id: swatchHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: picker.show(swatch.modelData, true) }
            ToolTip.visible: swatchHover.hovered
            ToolTip.delay: 400
            ToolTip.text: swatch.modelData
          }
        }
      }
    }

    Row {
      anchors.right: parent.right
      spacing: 8
      Chip { theme: picker.theme; text: "Cancel"; onClicked: picker.close() }
      Rectangle {
        id: applyButton
        width: applyText.implicitWidth + 28
        height: 30
        radius: 15
        color: applyHover.hovered ? Qt.lighter(picker.theme.accent, 1.1) : picker.theme.accent
        Text {
          id: applyText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "Apply"
          font.family: picker.theme.uiFont
          font.pixelSize: 13
          font.weight: Font.DemiBold
          color: Colors.readableOn(String(picker.theme.accent), "#ffffff")
        }
        HoverHandler { id: applyHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: picker.apply() }
      }
    }
  }
}
