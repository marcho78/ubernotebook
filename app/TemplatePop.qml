import QtQuick
import QtQuick.Controls
import "../Templates.js" as Templates

// A new page from a template: planners for the day, the week and the month,
// a habit tracker and a journal, and pages for lists, meetings, lectures,
// projects, reading, recipes and packing, each shown in miniature on your
// paper. On a page that's still blank, the template goes on that page.
Pop {
  id: pop

  property var view: null
  property int current: 0
  property bool picked: false

  readonly property var planners: ["daily", "weekly", "monthly", "habits", "journal"]
  readonly property var others: ["blank", "todo", "meeting", "lecture", "project", "reading", "recipe", "packing"]
  readonly property var all: planners.concat(others)
  readonly property real cardW: 96
  readonly property real cardH: 124
  readonly property real gap: 12
  readonly property string currentId: all[Math.max(0, Math.min(all.length - 1, current))]
  // The page you're on is still blank: the template goes on it.
  readonly property bool fills: view !== null && opened && view.isEmptyPage(view.page)

  width: 5 * cardW + 4 * gap + 2 * padding
  padding: 16

  function openAt(anchor) {
    parent = anchor
    x = anchor.width - width
    y = anchor.height + 8
    var kind = view.nb && view.nb.template ? view.nb.template : "blank"
    current = Math.max(0, all.indexOf(kind))
    picked = false
    open()
  }

  function pick(id) {
    picked = true
    close()
    view.addTemplatePage(id)
  }

  // Back to writing straight away (not after the fade, when you may be
  // doing something else by then).
  onAboutToHide: if (!picked && !view.drawing) view.focusWriting()

  // Arrows move between the pages, Enter takes one (Esc closes the popover).
  function move(key) {
    var i = current
    var col = i < 5 ? i : (i - 5) % 5
    if (key === Qt.Key_Left) i = Math.max(0, i - 1)
    else if (key === Qt.Key_Right) i = Math.min(all.length - 1, i + 1)
    else if (key === Qt.Key_Down) i = i < 5 ? Math.min(all.length - 1, 5 + col) : Math.min(all.length - 1, i + 5)
    else if (key === Qt.Key_Up) i = i >= 10 ? i - 5 : i >= 5 ? Math.min(4, col) : i
    current = i
  }

  component Heading: Text {
    textFormat: Text.PlainText
    font.family: pop.theme.uiFont
    font.pixelSize: 11
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.8
    color: pop.theme.muted
  }

  component Card: Item {
    id: card
    required property var modelData
    readonly property var t: Templates.byId(modelData)
    readonly property bool isCurrent: pop.currentId === modelData
    width: pop.cardW
    height: pop.cardH + 30

    Rectangle {
      x: -4
      y: -4
      width: pop.cardW + 8
      height: pop.cardH + 8
      radius: 7
      color: "transparent"
      border.width: 2
      border.color: card.isCurrent ? pop.theme.accent : cardHover.hovered ? pop.theme.line : "transparent"
    }
    TemplateThumb {
      width: pop.cardW
      height: pop.cardH
      kind: card.modelData
      look: pop.view ? pop.view.look : undefined
      accent: pop.theme.accent
      scale: cardHover.hovered ? 1.03 : 1
      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    Text {
      textFormat: Text.PlainText
      y: pop.cardH + 8
      width: pop.cardW
      horizontalAlignment: Text.AlignHCenter
      text: card.t.label
      elide: Text.ElideRight
      font.family: pop.theme.uiFont
      font.pixelSize: 12
      font.weight: card.isCurrent ? Font.DemiBold : Font.Normal
      color: card.isCurrent ? pop.theme.text : pop.theme.muted
    }
    HoverHandler {
      id: cardHover
      cursorShape: Qt.PointingHandCursor
      onHoveredChanged: if (hovered) pop.current = pop.all.indexOf(card.modelData)
    }
    TapHandler { onTapped: pop.pick(card.modelData) }
  }

  contentItem: Item {
    focus: true
    implicitHeight: body.implicitHeight
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
        e.accepted = true
        pop.move(e.key)
      } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
        e.accepted = true
        pop.pick(pop.currentId)
      }
    }

    Column {
      id: body
      width: parent.width
      spacing: 12

      Row {
        width: parent.width
        Text {
          id: heading
          textFormat: Text.PlainText
          text: "New page"
          font.family: pop.theme.uiFont
          font.pixelSize: 15
          font.weight: Font.DemiBold
          color: pop.theme.text
        }
        Text {
          textFormat: Text.PlainText
          anchors.baseline: heading.baseline
          leftPadding: 8
          text: pop.fills ? "on this blank page" : pop.view ? "after page " + (pop.view.pageIndex + 1) : ""
          font.family: pop.theme.uiFont
          font.pixelSize: 12
          color: pop.theme.muted
        }
      }

      Heading { text: "Planners" }
      Row {
        spacing: pop.gap
        Repeater { model: pop.planners; delegate: Card {} }
      }

      Heading { text: "Pages" }
      Grid {
        columns: 5
        spacing: pop.gap
        Repeater { model: pop.others; delegate: Card {} }
      }

      Rectangle { width: parent.width; height: 1; color: pop.theme.line }
      Item {
        width: parent.width
        height: 34
        Text {
          textFormat: Text.PlainText
          width: parent.width - keysHint.implicitWidth - 12
          text: Templates.byId(pop.currentId).hint
          elide: Text.ElideRight
          font.family: pop.theme.uiFont
          font.pixelSize: 12
          color: pop.theme.text
        }
        Text {
          textFormat: Text.PlainText
          y: 17
          width: parent.width - keysHint.implicitWidth - 12
          text: pop.view && pop.view.nb && pop.view.nb.template
            ? "Ctrl+N makes a " + Templates.byId(pop.view.nb.template).label.toLowerCase() + " page, as this notebook does"
            : "A notebook can make every new page one kind: Cover, paper and pen"
          elide: Text.ElideRight
          font.family: pop.theme.uiFont
          font.pixelSize: 11
          color: pop.theme.faint
        }
        Text {
          id: keysHint
          textFormat: Text.PlainText
          anchors.right: parent.right
          text: "\u2190\u2191\u2192\u2193  Enter"
          font.family: pop.theme.uiFont
          font.pixelSize: 11
          color: pop.theme.faint
        }
      }
    }
  }
}
