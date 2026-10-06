import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../Papers.js" as Papers
import "../Covers.js" as Covers
import "../Templates.js" as Templates

// Choosing a notebook: its title, the kind of page it makes (blank, or a
// planner's day, week or month, a journal, ...), cover (color, material, an
// elastic band), binding, paper and pen, with the cover drawn as you choose.
// For a new notebook, or to change one you have.
Popup {
  id: dialog

  property var theme: null
  // The notebook being changed, or null for a new one.
  property var target: null
  property var defaults: ({})

  property string title: ""
  property string coverColor: "navy"
  property string material: "leather"
  property bool band: true
  property string binding: "spiral"
  property string pattern: "ruled"
  property string paperColor: "ivory"
  property string lineSpacing: "regular"
  property string pen: "sans"
  // The kind of page it makes (Templates.PAGE_KINDS); "" is blank.
  property string kind: ""

  signal done(var choice)
  signal deleteRequested(var notebook)

  readonly property var themeColors: ({ background: String(theme.background), foreground: String(theme.foreground), accent: String(theme.accent) })

  anchors.centerIn: Overlay.overlay
  width: Math.min(900, (parent ? parent.width : 900) - 40)
  height: Math.min(640, (parent ? parent.height : 640) - 40)
  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape

  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, dialog.theme && dialog.theme.dark ? 0.5 : 0.3) }

  enter: Transition {
    ParallelAnimation {
      NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
      NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 180; easing.type: Easing.OutCubic }
    }
  }
  exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }

  function start(notebook) {
    target = notebook || null
    var d = defaults || {}
    var nb = notebook || {}
    title = notebook ? notebook.title : ""
    coverColor = nb.cover ? nb.cover.color : (d.cover || "navy")
    material = nb.cover ? nb.cover.material : (d.material || "leather")
    band = nb.cover && typeof nb.cover.band === "boolean" ? nb.cover.band : Covers.material(material).band
    binding = nb.binding || d.binding || "spiral"
    pattern = nb.paper ? nb.paper.pattern : (d.paper || "ruled")
    paperColor = nb.paper ? nb.paper.color : (d.paperColor || "ivory")
    lineSpacing = nb.paper ? nb.paper.spacing : (d.spacing || "regular")
    pen = nb.pen || d.pen || "sans"
    kind = nb.template || ""
    titleField.text = title
    open()
    titleField.focusField()
  }

  function finish() {
    var choice = {
      title: titleField.text.trim() || "Untitled notebook",
      cover: { color: coverColor, material: material, band: band },
      binding: binding,
      paper: { pattern: pattern, color: paperColor, spacing: lineSpacing },
      pen: pen,
      template: kind
    }
    close()
    done(choice)
  }

  // A new notebook of planners starts on the paper they look best on.
  function pickKind(id) {
    kind = id === "blank" ? "" : id
    var t = Templates.byId(id)
    if (!target && t.paper) pattern = t.paper
  }

  background: Item {
    Rectangle {
      id: plate
      anchors.fill: parent
      radius: 16
      color: dialog.theme.surface
      border.width: 1
      border.color: dialog.theme.line
      visible: false
    }
    MultiEffect {
      source: plate
      anchors.fill: plate
      shadowEnabled: true
      shadowColor: dialog.theme.shadow
      shadowBlur: 1.0
      shadowVerticalOffset: 14
      autoPaddingEnabled: true
    }
  }

  component Heading: Text {
    font.family: dialog.theme.uiFont
    font.pixelSize: 11
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.8
    color: dialog.theme.muted
  }

  contentItem: Item {
    // The cover, as it will look.
    Rectangle {
      id: stage
      width: parent.width * 0.4
      height: parent.height
      radius: 16
      color: Qt.alpha(dialog.theme.background, 0.6)
      Rectangle { anchors.right: parent.right; width: 16; height: parent.height; color: parent.color }

      Item {
        id: preview
        readonly property real w: Math.min(stage.width - 90, (stage.height - 120) / 1.38)
        width: w
        height: w * 1.38
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -10

        Rectangle { id: previewShadow; anchors.fill: parent; radius: 10; color: "black"; visible: false }
        MultiEffect {
          source: previewShadow
          anchors.fill: previewShadow
          shadowEnabled: true
          shadowColor: dialog.theme.shadow
          shadowBlur: 1.0
          shadowVerticalOffset: 16
          autoPaddingEnabled: true
        }
        Cover {
          anchors.fill: parent
          closed: true
          pages: 40
          look: Covers.resolve({ color: dialog.coverColor, material: dialog.material, band: dialog.band }, String(dialog.theme.accent))
          title: titleField.text.trim() || "Untitled notebook"
          binding: dialog.binding
          fonts: dialog.theme.coverFonts
        }
        Spine {
          visible: dialog.binding === "spiral"
          x: -16
          width: 44
          height: parent.height
          edge: 16
          binding: "spiral"
        }
      }

      // A scrap of the paper inside.
      Paper {
        width: preview.width * 0.6
        height: 54
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        look: Papers.resolve({ pattern: dialog.pattern, color: dialog.paperColor, spacing: dialog.lineSpacing }, dialog.themeColors)
        originY: 4
        marginLine: 14
        gridOrigin: 6
        layer.enabled: true
        Text {
          textFormat: Text.PlainText
          x: 22
          y: 4 + (parent.look.pitch || 30) * 0.8 - baselineOffset
          text: "The quick brown fox"
          font.family: dialog.theme.penFamily(Papers.pen(dialog.pen).families)
          font.pixelSize: Papers.typeStyle("p", dialog.pen, dialog.lineSpacing).size
          color: parent.look.ink
        }
      }
    }

    // The choices.
    Flickable {
      id: form
      x: stage.width + 26
      y: 22
      width: parent.width - x - 26
      height: parent.height - y - 76
      contentHeight: choices.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: choices
        width: form.width
        spacing: 10

        Text {
          textFormat: Text.PlainText
          text: dialog.target ? "This notebook" : "A new notebook"
          font.family: dialog.theme.uiFont
          font.pixelSize: 19
          font.weight: Font.DemiBold
          color: dialog.theme.text
        }
        Field {
          id: titleField
          theme: dialog.theme
          width: parent.width
          height: 38
          placeholder: "What's it for?"
          maximumLength: 120
          onAccepted: dialog.finish()
          onEscaped: dialog.close()
        }

        Heading { text: "Pages" }
        Flow {
          width: parent.width
          spacing: 6
          Repeater {
            model: Templates.PAGE_KINDS
            delegate: Chip {
              required property var modelData
              theme: dialog.theme
              text: modelData === "blank" ? "Blank" : Templates.byId(modelData).label
              icon: dialog.theme.icons[Templates.byId(modelData).icon] || ""
              checked: (dialog.kind || "blank") === modelData
              onClicked: dialog.pickKind(modelData)
            }
          }
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: Templates.byId(dialog.kind || "blank").every
            + (dialog.kind ? ". Any page can be another kind: + above the page." : ", or from a template: + above the page.")
          wrapMode: Text.Wrap
          font.family: dialog.theme.uiFont
          font.pixelSize: 12
          color: dialog.theme.muted
        }

        Heading { text: "Cover" }
        Flow {
          width: parent.width
          spacing: 2
          Repeater {
            model: Covers.COLORS
            delegate: Swatch {
              required property var modelData
              theme: dialog.theme
              size: 26
              color: modelData.id === "accent" ? dialog.theme.accent : modelData.color
              tip: modelData.label
              checked: dialog.coverColor === modelData.id
              onClicked: dialog.coverColor = modelData.id
            }
          }
        }
        Flow {
          width: parent.width
          spacing: 6
          Repeater {
            model: Covers.MATERIALS
            delegate: Chip {
              required property var modelData
              theme: dialog.theme
              text: modelData.label
              checked: dialog.material === modelData.id
              onClicked: {
                dialog.material = modelData.id
                dialog.band = modelData.band
              }
            }
          }
        }
        Row {
          spacing: 10
          Toggle { theme: dialog.theme; checked: dialog.band; onToggled: function(on) { dialog.band = on }; anchors.verticalCenter: parent.verticalCenter }
          Text { textFormat: Text.PlainText; text: "Elastic band"; font.family: dialog.theme.uiFont; font.pixelSize: 13; color: dialog.theme.text; anchors.verticalCenter: parent.verticalCenter }
        }

        Heading { text: "Binding" }
        Row {
          spacing: 6
          Repeater {
            model: Covers.BINDINGS
            delegate: Chip {
              required property var modelData
              theme: dialog.theme
              text: modelData.label
              checked: dialog.binding === modelData.id
              onClicked: dialog.binding = modelData.id
            }
          }
        }

        Heading { text: "Paper" }
        Flow {
          width: parent.width
          spacing: 6
          Repeater {
            model: Papers.PATTERNS
            delegate: Chip {
              required property var modelData
              theme: dialog.theme
              text: modelData.label
              checked: dialog.pattern === modelData.id
              onClicked: dialog.pattern = modelData.id
            }
          }
        }
        Flow {
          width: parent.width
          spacing: 2
          Repeater {
            model: Papers.PAPERS
            delegate: Swatch {
              required property var modelData
              theme: dialog.theme
              size: 24
              color: Papers.resolve({ color: modelData.id }, dialog.themeColors).paper
              tip: modelData.label
              checked: dialog.paperColor === modelData.id
              onClicked: dialog.paperColor = modelData.id
            }
          }
        }
        Row {
          spacing: 6
          Repeater {
            model: Papers.SPACINGS
            delegate: Chip {
              required property var modelData
              theme: dialog.theme
              text: modelData.label
              checked: dialog.lineSpacing === modelData.id
              onClicked: dialog.lineSpacing = modelData.id
            }
          }
        }

        Heading { text: "Pen" }
        Flow {
          width: parent.width
          spacing: 6
          Repeater {
            model: Papers.PENS
            delegate: Rectangle {
              required property var modelData
              readonly property bool on: dialog.pen === modelData.id
              width: 92
              height: 56
              radius: 10
              color: on ? dialog.theme.accentSoft : penHover.hovered ? dialog.theme.hover : "transparent"
              border.width: 1
              border.color: on ? Qt.alpha(dialog.theme.accent, 0.7) : dialog.theme.line
              Column {
                anchors.centerIn: parent
                spacing: 1
                Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: "Aa"; font.family: dialog.theme.penFamily(modelData.families); font.pixelSize: 21 * modelData.scale; color: dialog.theme.text }
                Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.family: dialog.theme.uiFont; font.pixelSize: 11; color: dialog.theme.muted }
              }
              HoverHandler { id: penHover; cursorShape: Qt.PointingHandCursor }
              TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: dialog.pen = modelData.id }
            }
          }
        }
        Item { width: 1; height: 6 }
      }
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: 22
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 20
      spacing: 8
      IconButton { theme: dialog.theme; label: "Cancel"; onClicked: dialog.close() }
      Rectangle {
        width: createLabel.implicitWidth + 32
        height: 34
        radius: 17
        color: createTap.pressed ? Qt.darker(dialog.theme.accent, 1.15) : dialog.theme.accent
        Text {
          textFormat: Text.PlainText
          id: createLabel
          anchors.centerIn: parent
          text: dialog.target ? "Save" : "Create notebook"
          font.family: dialog.theme.uiFont
          font.pixelSize: 13
          font.weight: Font.DemiBold
          color: dialog.theme.onAccent
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; id: createTap; onTapped: dialog.finish() }
      }
    }
    IconButton {
      visible: dialog.target !== null
      anchors.left: form.left
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 20
      theme: dialog.theme
      icon: dialog.theme.icons.trash
      label: "Put in the trash"
      tint: dialog.theme.urgent
      onClicked: { var t = dialog.target; dialog.close(); dialog.deleteRequested(t) }
    }
  }
}
