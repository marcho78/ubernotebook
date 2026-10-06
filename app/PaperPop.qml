import QtQuick
import QtQuick.Controls
import "../Papers.js" as Papers

// The paper: its pattern, color and line spacing, for this page or the whole
// notebook. Each choice shows as a scrap of the paper it makes.
Pop {
  id: pop

  property var view: null
  property bool wholeNotebook: false
  readonly property var current: view && view.page && view.page.paper ? view.page.paper : (view && view.nb ? view.nb.paper : { pattern: "ruled", color: "ivory", spacing: "regular" })
  readonly property var colors: view ? view.themeColors : ({})

  width: 404
  padding: 14
  focus: false

  function openAt(anchor) {
    parent = anchor
    var below = anchor.mapToItem(null, 0, 0).y < (anchor.Window.window ? anchor.Window.window.height / 2 : 400)
    x = (anchor.width - width) / 2
    y = below ? anchor.height + 8 : -implicitHeight - 12
    wholeNotebook = !(view.page && view.page.paper)
    open()
  }

  function pick(changes) {
    var next = { pattern: current.pattern, color: current.color, spacing: current.spacing }
    for (var k in changes) next[k] = changes[k]
    view.setPaper(next, wholeNotebook)
  }

  component Heading: Text {
    font.family: pop.theme.uiFont
    font.pixelSize: 11
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.8
    color: pop.theme.muted
  }

  contentItem: Column {
    spacing: 10

    Heading { text: "Pattern" }
    Grid {
      columns: 6
      spacing: 6
      Repeater {
        model: Papers.PATTERNS
        delegate: Column {
          required property var modelData
          spacing: 4
          Rectangle {
            width: 58
            height: 58
            radius: 6
            color: "transparent"
            border.width: 2
            border.color: pop.current.pattern === modelData.id ? pop.theme.accent : patternHover.hovered ? pop.theme.line : "transparent"
            Paper {
              anchors.fill: parent
              anchors.margins: 3
              look: Papers.resolve({ pattern: modelData.id, color: pop.current.color, spacing: "compact" }, pop.colors)
              originY: 8
              marginLine: 12
              gridOrigin: 4
              layer.enabled: true
            }
            HoverHandler { id: patternHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: pop.pick({ pattern: modelData.id }) }
          }
          Text {
            textFormat: Text.PlainText
            width: 58
            horizontalAlignment: Text.AlignHCenter
            text: modelData.label
            elide: Text.ElideRight
            font.family: pop.theme.uiFont
            font.pixelSize: 11
            color: pop.current.pattern === modelData.id ? pop.theme.accent : pop.theme.muted
          }
        }
      }
    }

    Heading { text: "Paper" }
    Flow {
      width: parent.width
      spacing: 4
      Repeater {
        model: Papers.PAPERS
        delegate: Swatch {
          required property var modelData
          theme: pop.theme
          size: 28
          color: Papers.resolve({ color: modelData.id }, pop.colors).paper
          checked: pop.current.color === modelData.id
          tip: modelData.label
          onClicked: pop.pick({ color: modelData.id })
        }
      }
    }

    Heading { text: "Lines" }
    Row {
      spacing: 6
      Repeater {
        model: Papers.SPACINGS
        delegate: Chip {
          required property var modelData
          theme: pop.theme
          text: modelData.label
          checked: pop.current.spacing === modelData.id
          onClicked: pop.pick({ spacing: modelData.id })
        }
      }
    }

    Rectangle { width: parent.width; height: 1; color: pop.theme.line }
    Row {
      spacing: 6
      Chip { theme: pop.theme; text: "This page"; checked: !pop.wholeNotebook; onClicked: pop.wholeNotebook = false }
      Chip { theme: pop.theme; text: "Every page"; checked: pop.wholeNotebook; onClicked: { pop.wholeNotebook = true; pop.view.setPaper(pop.current, true) } }
    }
  }
}
