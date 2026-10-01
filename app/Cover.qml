import QtQuick
import QtQuick.Shapes

// A notebook's front cover: its material and color (shaders/cover.frag), its
// title put on the way that material takes it (stamped in gold foil on
// leather, written on a paper label on linen and card, typed onto kraft,
// written in a composition book's name box), and an elastic band if it has
// one. With `closed`, the pages and back cover show behind it, as on a shelf.
Item {
  id: cover

  // Covers.resolve() of the notebook's cover.
  property var look: ({ color: "#22324f", shader: 0, titleStyle: "foil", band: true, dark: true, foil: "#d8bb74", stamp: "#2a1d10", band_: "#101626", labelPaper: "#f6f1e4", labelInk: "#23262d", inside: "#e6e2d8", text: "#f5f1e8" })
  property string title: ""
  property string binding: "spiral"
  property bool closed: false
  property bool inside: false
  // Just the board (a back cover): no title, no band.
  property bool bare: false
  property int pages: 0
  property real radius: Math.max(6, Math.min(width, height) * 0.035)
  // Fonts: { marker, hand, serif, typewriter }.
  property var fonts: ({ marker: "Permanent Marker", hand: "Caveat", serif: "Lora", typewriter: "Special Elite" })
  property real seed: 0.37

  readonly property real unit: Math.min(width, height / 1.38)
  readonly property real spineW: binding === "stitched" ? Math.min(34, width * 0.13) : binding === "hardcover" ? Math.min(22, width * 0.08) : 0

  // ---- behind the cover, when closed ------------------------------------------------------

  Rectangle {
    visible: cover.closed
    x: 5
    y: 5
    width: cover.width
    height: cover.height
    radius: cover.radius
    color: Qt.darker(cover.look.color, 1.5)
  }

  // The pages, thicker the more there are.
  Rectangle {
    visible: cover.closed
    readonly property real thick: Math.min(5, 2 + cover.pages / 40)
    x: thick
    y: thick
    width: cover.width - 2
    height: cover.height - 3
    radius: cover.radius * 0.6
    color: "#f3ecdc"
    border.width: 1
    border.color: "#d9cfba"
  }

  // ---- the cover itself ---------------------------------------------------------------

  ShaderEffect {
    id: surface
    anchors.fill: parent
    readonly property size size: Qt.size(width, height)
    readonly property color base: cover.inside ? (cover.look.inside || "#e6e2d8") : cover.look.color
    readonly property real material: cover.look.shader || 0
    readonly property real radius: cover.radius
    readonly property real spine: cover.binding === "stitched" ? 1 : cover.binding === "hardcover" ? 2 : 0
    readonly property real stitch: cover.look.shader === 0 && !cover.bare ? 1 : 0
    readonly property real dpr: Screen.devicePixelRatio || 1
    readonly property real seed: cover.seed
    readonly property real inside: cover.inside ? 1 : 0
    fragmentShader: Qt.resolvedUrl("../shaders/cover.frag.qsb")
  }

  // ---- the title ------------------------------------------------------------------------

  Item {
    id: face
    visible: !cover.inside && !cover.bare
    anchors.fill: parent
    anchors.leftMargin: cover.spineW

    // Gold foil (or pressed into a light cover): leather.
    Item {
      visible: cover.look.titleStyle === "foil"
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.3
      width: parent.width * 0.78
      height: parent.height * 0.24

      Text {
        textFormat: Text.PlainText
        id: foilShadow
        anchors.fill: parent
        anchors.topMargin: 1
        text: foil.text
        font: foil.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        color: Qt.rgba(0, 0, 0, 0.45)
      }
      Text {
        textFormat: Text.PlainText
        id: foil
        anchors.fill: parent
        text: cover.title.toUpperCase()
        font.family: cover.fonts.serif
        font.weight: Font.DemiBold
        font.pixelSize: Math.max(9, cover.unit * 0.1)
        font.letterSpacing: cover.unit * 0.012
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        color: cover.look.foil
      }
      // A rule under the title, stamped the same way.
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: cover.unit * 0.02
        width: parent.width * 0.3
        height: Math.max(1, cover.unit * 0.006)
        color: cover.look.foil
        opacity: 0.8
      }
    }

    // A paper label, written on with a marker: linen and card.
    Rectangle {
      visible: cover.look.titleStyle === "label"
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.22
      width: parent.width * 0.68
      height: Math.max(24, parent.height * 0.2)
      radius: height * 0.18
      color: cover.look.labelPaper
      border.width: Math.max(1, cover.unit * 0.006)
      border.color: Qt.darker(cover.look.labelPaper, 1.25)

      Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(3, cover.unit * 0.02)
        radius: parent.radius * 0.7
        color: "transparent"
        border.width: Math.max(1, cover.unit * 0.004)
        border.color: Qt.alpha(cover.look.color, 0.45)
      }
      Text {
        textFormat: Text.PlainText
        anchors.fill: parent
        anchors.margins: parent.height * 0.14
        text: cover.title
        font.family: cover.fonts.marker
        font.pixelSize: Math.max(9, cover.unit * 0.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        fontSizeMode: Text.Fit
        minimumPixelSize: 7
        color: cover.look.labelInk
      }
    }

    // Typed straight onto kraft, inside a stamped box.
    Rectangle {
      visible: cover.look.titleStyle === "stamp"
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.24
      width: parent.width * 0.72
      height: Math.max(24, parent.height * 0.17)
      rotation: -1.6
      color: "transparent"
      border.width: Math.max(1.5, cover.unit * 0.01)
      border.color: Qt.alpha(cover.look.stamp, 0.8)
      Text {
        textFormat: Text.PlainText
        anchors.fill: parent
        anchors.margins: parent.height * 0.14
        text: cover.title.toUpperCase()
        font.family: cover.fonts.typewriter
        font.pixelSize: Math.max(9, cover.unit * 0.085)
        font.letterSpacing: cover.unit * 0.008
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        fontSizeMode: Text.Fit
        minimumPixelSize: 7
        color: Qt.alpha(cover.look.stamp, 0.88)
      }
    }

    // A composition book's name box.
    Rectangle {
      visible: cover.look.titleStyle === "box"
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.12
      width: parent.width * 0.64
      height: Math.max(36, parent.height * 0.24)
      radius: height * 0.12
      color: "#f7f5ef"
      border.width: Math.max(1.5, cover.unit * 0.008)
      border.color: "#1c1c1e"

      Column {
        anchors.fill: parent
        anchors.margins: parent.height * 0.1
        spacing: parent.height * 0.04
        Repeater {
          model: [{ label: "NAME", value: cover.title }, { label: "SUBJECT", value: "" }]
          delegate: Item {
            required property var modelData
            width: parent.width
            height: (parent.height - parent.spacing) / 2
            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 2
              text: modelData.label
              font.family: "Adwaita Sans"
              font.pixelSize: Math.max(5, cover.unit * 0.028)
              font.letterSpacing: 0.6
              color: "#3a3a3c"
            }
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.leftMargin: cover.unit * 0.1
              anchors.right: parent.right
              height: 1
              color: "#3a3a3c"
            }
            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.leftMargin: cover.unit * 0.12
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 1
              text: modelData.value
              font.family: cover.fonts.hand
              font.pixelSize: Math.max(8, cover.unit * 0.085)
              elide: Text.ElideRight
              color: "#1d3b8f"
            }
          }
        }
      }
    }
  }

  // ---- a spiral, when it's closed -----------------------------------------------------------

  Spine {
    visible: cover.closed && cover.binding === "spiral" && !cover.inside && !cover.bare
    x: -9
    width: 40
    height: cover.height
    edge: 9
    binding: "spiral"
    dark: true
  }

  // ---- the elastic band ------------------------------------------------------------------

  Rectangle {
    visible: cover.look.band === true && !cover.inside && !cover.bare
    x: cover.width - width - cover.unit * 0.07
    y: -2
    width: Math.max(5, cover.unit * 0.045)
    height: cover.height + 4
    radius: 2
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Qt.darker(cover.look.band_, 1.3) }
      GradientStop { position: 0.35; color: Qt.lighter(cover.look.band_, 1.5) }
      GradientStop { position: 1.0; color: cover.look.band_ }
    }
    // Its shadow on the cover.
    Rectangle {
      x: parent.width
      width: 3
      height: parent.height
      color: Qt.rgba(0, 0, 0, 0.22)
    }
  }
}
