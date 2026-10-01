import QtQuick
import QtQuick.Effects
import "../Papers.js" as Papers
import "../Blocks.js" as Blocks

// The formatting bar, floating at the foot of the desk like a pencil case:
// undo, the kind of block, pen and size, bold/italic/underline/strike, ink and
// highlighter, lists, alignment, things to insert, and the paper. It shows
// the formatting where the cursor is, and never takes the keyboard from the
// page.
Item {
  id: bar

  property var theme: null
  property var editor: null
  property bool dark: false
  property string pen: "sans"
  property string spacing: "regular"

  // Drawing: the pens, and what they're set to.
  property bool drawing: false
  property string inkTool: "pen"
  property string inkColor: "#1e4fa3"
  property real inkWidth: 2.2
  property var ink: null

  signal drawingRequested(bool on)
  signal inkToolPicked(string tool)
  signal inkColorPicked(string color)
  signal inkWidthPicked(real width)
  signal paperRequested(Item anchor)
  signal linkRequested(Item anchor)
  signal pictureRequested()
  signal dateRequested()

  readonly property var st: editor ? editor.formatState : ({})
  readonly property var inline: st && st.inline ? st.inline : ({})
  readonly property bool wide: width > 980
  readonly property bool medium: width > 780

  implicitHeight: 50
  implicitWidth: pill.width

  // The pens' colors: writing inks, or highlighters for the marker.
  readonly property var inkChoices: inkTool === "marker"
    ? Papers.HIGHLIGHTS.map(function(h) { return h.light })
    : ["#1f2430"].concat(Papers.INKS.map(function(i) { return i.light }))

  // The size of the block's own text, and of what's at the cursor (0 when
  // the selection mixes sizes).
  readonly property int normalSize: Papers.typeStyle(st.type && Blocks.isText(st.type) ? st.type : "p", pen, spacing).size
  readonly property int currentSize: inline.size === null ? 0 : inline.size ? Number(inline.size) : normalSize
  readonly property string sizeLabel: currentSize > 0 ? String(currentSize) : "\u2013"

  function kindLabel(type) {
    return type && Blocks.KINDS[type] ? Blocks.KINDS[type].label : "Text"
  }

  function openPaper() { paperRequested(paperButton) }

  function refocus() {
    if (!editor) return
    if (editor.selectedList.length > 0) return
    var item = editor.items[editor.focusUid]
    if (item && item.edit) item.edit.forceActiveFocus()
  }

  Rectangle {
    id: plate
    anchors.fill: pill
    radius: height / 2
    color: bar.theme.surface
    border.width: 1
    border.color: bar.theme.line
    visible: false
  }
  MultiEffect {
    source: plate
    anchors.fill: plate
    shadowEnabled: true
    shadowColor: bar.theme.shadow
    shadowBlur: 1.0
    shadowVerticalOffset: 8
    autoPaddingEnabled: true
  }

  Item {
    id: pill
    anchors.horizontalCenter: parent.horizontalCenter
    width: bar.drawing ? inkTools.width : textTools.width
    height: bar.implicitHeight
    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
  }

  Row {
    id: textTools
    anchors.horizontalCenter: parent.horizontalCenter
    height: bar.implicitHeight
    leftPadding: 10
    rightPadding: 10
    spacing: 2
    visible: !bar.drawing
    opacity: visible ? 1 : 0

    component Sep: Rectangle {
      width: 1
      height: 22
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      color: bar.theme.line
    }

    IconButton {
      visible: bar.medium
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.undo; tip: "Undo  Ctrl+Z"
      active: bar.editor && bar.editor.canUndo
      onClicked: bar.editor.undo()
    }
    IconButton {
      visible: bar.medium
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.redo; tip: "Redo  Ctrl+Shift+Z"
      active: bar.editor && bar.editor.canRedo
      onClicked: bar.editor.redo()
    }
    Sep { visible: bar.medium }

    // The kind of block.
    IconButton {
      id: kindButton
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme
      label: bar.kindLabel(bar.st.type) + "  \u25be"
      tip: "Kind of block"
      onClicked: kindMenu.open()
      Pop {
        id: kindMenu
        theme: bar.theme
        focus: false
        y: -implicitHeight - 12
        onClosed: bar.refocus()
        contentItem: Column {
          spacing: 2
          Repeater {
            model: [
              { type: "p", icon: bar.theme.icons.text, hint: "Ctrl+Alt+0" },
              { type: "h1", icon: bar.theme.icons.h1, hint: "Ctrl+Alt+1" },
              { type: "h2", icon: bar.theme.icons.h2, hint: "Ctrl+Alt+2" },
              { type: "h3", icon: bar.theme.icons.h3, hint: "Ctrl+Alt+3" },
              { type: "quote", icon: bar.theme.icons.quote, hint: "> " },
              { type: "callout", icon: bar.theme.icons.sticky, hint: "!! " },
              { type: "code", icon: bar.theme.icons.code, hint: "``` " },
              { type: "time", icon: bar.theme.icons.time, hint: "9:00 " },
              { type: "habit", icon: bar.theme.icons.habit, hint: "" }
            ]
            delegate: MenuRow {
              required property var modelData
              theme: bar.theme
              icon: modelData.icon
              text: bar.kindLabel(modelData.type)
              hint: modelData.hint
              checked: bar.st.type === modelData.type
              onClicked: {
                kindMenu.close()
                var list = bar.editor.selectedList.length ? bar.editor.selectedList : [bar.editor.focusUid]
                bar.editor.setType(list, modelData.type)
              }
            }
          }
        }
      }
    }

    // A sticky note's color.
    IconButton {
      id: toneButton
      visible: bar.st.type === "callout"
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme
      icon: bar.theme.icons.sticky
      tip: "Sticky note color"
      swatch: Papers.toneColor(bar.st.tone || "yellow", bar.dark)
      onClicked: toneMenu.open()
      Pop {
        id: toneMenu
        theme: bar.theme
        focus: false
        y: -implicitHeight - 12
        onClosed: bar.refocus()
        contentItem: Row {
          spacing: 2
          Repeater {
            model: ["yellow", "blue", "green", "pink", "purple", "gray"]
            delegate: Swatch {
              required property var modelData
              theme: bar.theme
              color: Papers.toneColor(modelData, bar.dark)
              checked: (bar.st.tone || "yellow") === modelData
              onClicked: {
                toneMenu.close()
                bar.editor.setTone(bar.editor.selectedList.length ? bar.editor.selectedList : [bar.editor.focusUid], modelData)
              }
            }
          }
        }
      }
    }

    // The pen (font) for the selection.
    IconButton {
      id: fontButton
      visible: bar.medium
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.font; tip: "Pen"
      onClicked: fontMenu.open()
      Pop {
        id: fontMenu
        theme: bar.theme
        focus: false
        y: -implicitHeight - 12
        onClosed: bar.refocus()
        contentItem: Column {
          spacing: 8
          Grid {
            columns: 4
            spacing: 4
            Repeater {
              model: Papers.PENS
              delegate: Rectangle {
                required property var modelData
                readonly property string family: bar.theme.penFamily(modelData.families)
                readonly property bool on: bar.inline.family === family
                width: 86
                height: 58
                radius: 9
                color: on ? bar.theme.accentSoft : penHover.hovered ? bar.theme.hover : "transparent"
                border.width: 1
                border.color: on ? Qt.alpha(bar.theme.accent, 0.7) : bar.theme.line
                Column {
                  anchors.centerIn: parent
                  spacing: 2
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: "Aa"; font.family: parent.parent.family; font.pixelSize: 22 * modelData.scale; color: bar.theme.text }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.family: bar.theme.uiFont; font.pixelSize: 11; color: bar.theme.muted }
                }
                HoverHandler { id: penHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                  onTapped: {
                    fontMenu.close()
                    // The notebook's own pen means no font of its own.
                    bar.editor.formatInline("family", modelData.id === bar.pen ? "" : parent.family)
                  }
                }
              }
            }
          }
        }
      }
    }

    // Text size: what's at the cursor (or selected), and every size to pick.
    IconButton {
      id: sizeButton
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme
      label: bar.sizeLabel + "  \u25be"
      tip: "Text size  Ctrl+Shift+> bigger, Ctrl+Shift+< smaller"
      onClicked: sizeMenu.open()
      Pop {
        id: sizeMenu
        theme: bar.theme
        focus: false
        padding: 6
        y: -implicitHeight - 12
        onClosed: bar.refocus()
        contentItem: Column {
          spacing: 0
          Repeater {
            model: bar.editor ? bar.editor.sizeChoices(bar.normalSize) : []
            delegate: Rectangle {
              required property var modelData
              readonly property bool on: bar.currentSize === modelData
              readonly property int shown: Math.min(modelData, 40)
              width: 210
              height: Math.max(30, Math.round(shown * 1.3))
              radius: 8
              color: on ? bar.theme.accentSoft : sizeHover.hovered ? bar.theme.hover : "transparent"
              Text {
                textFormat: Text.PlainText
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData === bar.normalSize ? "Normal" : "Aa"
                font.family: bar.theme.penFamily(Papers.pen(bar.pen).families)
                font.pixelSize: parent.shown
                color: parent.on ? bar.theme.accent : bar.theme.text
              }
              Text {
                textFormat: Text.PlainText
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                font.family: bar.theme.uiFont
                font.pixelSize: 12
                font.features: { "tnum": 1 }
                color: parent.on ? bar.theme.accent : bar.theme.muted
              }
              HoverHandler { id: sizeHover; cursorShape: Qt.PointingHandCursor }
              TapHandler {
                onTapped: {
                  sizeMenu.close()
                  bar.editor.formatInline("size", modelData === bar.normalSize ? 0 : modelData)
                }
              }
            }
          }
        }
      }
    }
    Sep {}

    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.bold; tip: "Bold  Ctrl+B"
      checked: bar.inline.bold === "all"
      onClicked: bar.editor.formatInline("bold")
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.italic; tip: "Italic  Ctrl+I"
      checked: bar.inline.italic === "all"
      onClicked: bar.editor.formatInline("italic")
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.underline; tip: "Underline  Ctrl+U"
      checked: bar.inline.underline === "all"
      onClicked: bar.editor.formatInline("underline")
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.strike; tip: "Strikethrough  Ctrl+Shift+X"
      checked: bar.inline.strike === "all"
      onClicked: bar.editor.formatInline("strike")
    }
    Sep {}

    // Ink.
    IconButton {
      id: inkButton
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.ink; tip: "Ink color"
      swatch: bar.inline.color ? (bar.dark ? (Papers.darkMap()[bar.inline.color] || bar.inline.color) : bar.inline.color) : "transparent"
      onClicked: inkMenu.open()
      Pop {
        id: inkMenu
        theme: bar.theme
        focus: false
        y: -implicitHeight - 12
        onClosed: bar.refocus()
        contentItem: Row {
          spacing: 2
          Swatch {
            theme: bar.theme
            color: bar.dark ? "#e9e6de" : "#1f2430"
            checked: !bar.inline.color
            onClicked: { inkMenu.close(); bar.editor.formatInline("color", "") }
          }
          Repeater {
            model: Papers.INKS
            delegate: Swatch {
              required property var modelData
              theme: bar.theme
              color: bar.dark ? modelData.dark : modelData.light
              checked: bar.inline.color === modelData.light
              onClicked: { inkMenu.close(); bar.editor.formatInline("color", modelData.light) }
            }
          }
        }
      }
    }
    // Highlighter.
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.highlight; tip: "Highlighter  Ctrl+Shift+H"
      swatch: bar.inline.highlight ? (bar.dark ? (Papers.darkMap()[bar.inline.highlight] || bar.inline.highlight) : bar.inline.highlight) : "transparent"
      onClicked: markMenu.open()
      Pop {
        id: markMenu
        theme: bar.theme
        focus: false
        y: -implicitHeight - 12
        onClosed: bar.refocus()
        contentItem: Row {
          spacing: 2
          Repeater {
            model: Papers.HIGHLIGHTS
            delegate: Swatch {
              required property var modelData
              theme: bar.theme
              marker: true
              color: bar.dark ? modelData.dark : modelData.light
              checked: bar.inline.highlight === modelData.light
              onClicked: { markMenu.close(); bar.editor.formatInline("highlight", modelData.light) }
            }
          }
          IconButton {
            theme: bar.theme; icon: bar.theme.icons.close; tip: "No highlight"; size: 30
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { markMenu.close(); bar.editor.formatInline("highlight", "") }
          }
        }
      }
    }
    Sep {}

    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.bullets; tip: "Bulleted list  - space"
      checked: bar.st.type === "bullet"
      onClicked: bar.editor.toggleType(bar.editor.selectedList.length ? bar.editor.selectedList : [bar.editor.focusUid], "bullet")
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.numbers; tip: "Numbered list  1. space"
      checked: bar.st.type === "number"
      onClicked: bar.editor.toggleType(bar.editor.selectedList.length ? bar.editor.selectedList : [bar.editor.focusUid], "number")
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.checks; tip: "Checklist  [] space"
      checked: bar.st.type === "check"
      onClicked: bar.editor.toggleType(bar.editor.selectedList.length ? bar.editor.selectedList : [bar.editor.focusUid], "check")
    }

    // Alignment.
    IconButton {
      id: alignButton
      visible: bar.wide
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme
      icon: bar.st.align === "center" ? bar.theme.icons.alignCenter : bar.st.align === "right" ? bar.theme.icons.alignRight : bar.st.align === "justify" ? bar.theme.icons.alignJustify : bar.theme.icons.alignLeft
      tip: "Alignment"
      onClicked: alignMenu.open()
      Pop {
        id: alignMenu
        theme: bar.theme
        focus: false
        y: -implicitHeight - 12
        onClosed: bar.refocus()
        contentItem: Row {
          spacing: 2
          Repeater {
            model: [["left", "alignLeft", "Left"], ["center", "alignCenter", "Centered"], ["right", "alignRight", "Right"], ["justify", "alignJustify", "Justified"]]
            delegate: IconButton {
              required property var modelData
              theme: bar.theme
              icon: bar.theme.icons[modelData[1]]
              tip: modelData[2]
              checked: (bar.st.align || "left") === modelData[0]
              onClicked: {
                alignMenu.close()
                bar.editor.setAlign(bar.editor.selectedList.length ? bar.editor.selectedList : [bar.editor.focusUid], modelData[0])
              }
            }
          }
        }
      }
    }
    Sep {}

    // Things to put on the page.
    IconButton {
      id: insertButton
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.plus; tip: "Insert"
      onClicked: insertMenu.open()
      Pop {
        id: insertMenu
        theme: bar.theme
        focus: false
        y: -implicitHeight - 12
        onClosed: bar.refocus()
        contentItem: Column {
          spacing: 2
          MenuRow { theme: bar.theme; icon: bar.theme.icons.link; text: "Link"; hint: "Ctrl+K"; onClicked: { insertMenu.close(); bar.linkRequested(insertButton) } }
          MenuRow { theme: bar.theme; icon: bar.theme.icons.image; text: "Picture\u2026"; hint: "or paste, or drop"; onClicked: { insertMenu.close(); bar.pictureRequested() } }
          MenuRow { theme: bar.theme; icon: bar.theme.icons.sticky; text: "Sticky note"; hint: "!! "; onClicked: { insertMenu.close(); bar.editor.insertKind("callout", { tone: "yellow" }) } }
          MenuRow { theme: bar.theme; icon: bar.theme.icons.code; text: "Code"; hint: "``` "; onClicked: { insertMenu.close(); bar.editor.insertKind("code") } }
          MenuRow { theme: bar.theme; icon: bar.theme.icons.divider; text: "Divider"; hint: "---"; onClicked: { insertMenu.close(); bar.editor.insertKind("divider", { style: "line" }) } }
          MenuRow { theme: bar.theme; icon: bar.theme.icons.calendarMonth; text: "Month calendar"; onClicked: { insertMenu.close(); bar.editor.insertKind("calendar", {}) } }
          MenuRow { theme: bar.theme; icon: bar.theme.icons.habit; text: "Habit to track"; onClicked: { insertMenu.close(); bar.editor.insertKind("habit", {}) } }
          MenuRow { theme: bar.theme; icon: bar.theme.icons.time; text: "Time slot"; hint: "9:00 "; onClicked: { insertMenu.close(); bar.editor.insertKind("time", { label: Qt.formatTime(new Date(), "HH") + ":00" }) } }
          MenuRow { theme: bar.theme; icon: bar.theme.icons.calendar; text: "Today's date"; hint: "Ctrl+;"; onClicked: { insertMenu.close(); bar.dateRequested() } }
        }
      }
    }
    IconButton {
      id: paperButton
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.paper; tip: "Paper"
      onClicked: bar.paperRequested(paperButton)
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.pen; tip: "Draw  Ctrl+Shift+D"
      onClicked: bar.drawingRequested(true)
    }
  }

  // ---- drawing -------------------------------------------------------------------

  Row {
    id: inkTools
    anchors.horizontalCenter: parent.horizontalCenter
    height: bar.implicitHeight
    leftPadding: 10
    rightPadding: 10
    spacing: 2
    visible: bar.drawing

    component Sep2: Rectangle {
      width: 1
      height: 22
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      color: bar.theme.line
    }

    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.check; label: "Done"; tip: "Back to writing  Esc"
      onClicked: bar.drawingRequested(false)
    }
    Sep2 {}
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.pen; tip: "Pen  P"
      checked: bar.inkTool === "pen"
      onClicked: {
        bar.inkToolPicked("pen")
        if (bar.inkChoices.indexOf(bar.inkColor) < 0 || bar.inkColor === Papers.HIGHLIGHTS[0].light) bar.inkColorPicked("#1f2430")
      }
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.marker; tip: "Highlighter  M"
      checked: bar.inkTool === "marker"
      onClicked: {
        bar.inkToolPicked("marker")
        if (Papers.HIGHLIGHTS.map(function(h) { return h.light }).indexOf(bar.inkColor) < 0) bar.inkColorPicked(Papers.HIGHLIGHTS[0].light)
      }
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: "\u{f01fe}"; tip: "Eraser  E"
      checked: bar.inkTool === "eraser"
      onClicked: bar.inkToolPicked("eraser")
    }
    Sep2 {}
    Repeater {
      model: bar.inkChoices
      delegate: Swatch {
        required property var modelData
        anchors.verticalCenter: parent.verticalCenter
        theme: bar.theme
        size: 20
        marker: bar.inkTool === "marker"
        color: bar.dark ? (Papers.darkMap()[modelData] || (modelData === "#1f2430" ? "#e9e6de" : modelData)) : modelData
        checked: bar.inkColor === modelData && bar.inkTool !== "eraser"
        onClicked: bar.inkColorPicked(modelData)
      }
    }
    Sep2 {}
    Repeater {
      model: [1.4, 2.2, 3.6]
      delegate: Item {
        required property var modelData
        width: 30
        height: 30
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
          anchors.fill: parent
          radius: 9
          color: bar.inkWidth === modelData ? bar.theme.accentSoft : nibHover.hovered ? bar.theme.hover : "transparent"
        }
        Rectangle {
          anchors.centerIn: parent
          width: modelData * 3.2
          height: width
          radius: width / 2
          color: bar.inkWidth === modelData ? bar.theme.accent : bar.theme.text
        }
        HoverHandler { id: nibHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: bar.inkWidthPicked(modelData) }
      }
    }
    Sep2 {}
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.undo; tip: "Undo  Ctrl+Z"
      active: bar.ink && bar.ink.canUndo
      onClicked: bar.ink.undo()
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.redo; tip: "Redo  Ctrl+Shift+Z"
      active: bar.ink && bar.ink.canRedo
      onClicked: bar.ink.redo()
    }
    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme.icons.trash; tip: "Clear the drawings on this page"
      active: bar.ink && bar.ink.strokes.length > 0
      onClicked: bar.ink.clearAll()
    }
  }
}
