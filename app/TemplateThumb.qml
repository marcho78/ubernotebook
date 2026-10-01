import QtQuick
import "../Templates.js" as Templates
import "../Blocks.js" as Blocks
import "../Papers.js" as Papers

// A page of a template in miniature, on your paper in your ink: the title,
// headings as bars, checkboxes, bullets, the times of a schedule, a habit's
// seven days, a calendar's dates, sticky notes in their colors.
Rectangle {
  id: thumb

  property string kind: "blank"
  // A resolved paper (Papers.resolve).
  property var look: Papers.resolve({}, {})
  property color accent: "#2456b3"

  readonly property real rowH: 7
  readonly property real pad: 8
  readonly property real bodyTop: 18
  readonly property color ink: look.ink || "#1f2430"
  readonly property var page: Templates.build(kind, Templates.iso(new Date()), function(d, pattern) { return "x" })
  readonly property bool titled: page.title !== "" || Templates.titleHint(kind) !== ""
  readonly property int maxRows: Math.floor((height - bodyTop - 4) / rowH)

  // Each block as rows of the miniature (a calendar takes a few).
  readonly property var rows: {
    var out = []
    page.blocks.forEach(function(b) {
      if (b.type === "calendar") {
        var cal = Blocks.monthLayout(b.month)
        out.push({ type: "calhead" })
        for (var w = 0; w < cal.weeks; w++) out.push({ type: "calweek", from: w === 0 ? cal.offset : 0, to: w === cal.weeks - 1 ? (cal.offset + cal.days - 1) % 7 : 6 })
      } else {
        out.push({ type: b.type, tone: b.tone || "", written: !!b.html && b.type !== "h2" })
      }
    })
    return out.slice(0, maxRows)
  }

  color: look.paper || "#fbf6e9"
  radius: 3
  border.width: 1
  border.color: Qt.alpha("#000000", look.dark ? 0.4 : 0.1)
  clip: true

  // The title, and the rule under it.
  Rectangle {
    visible: thumb.titled
    x: thumb.pad
    y: 8
    width: (thumb.width - thumb.pad * 2) * (thumb.page.day ? 0.5 : 0.62)
    height: 3
    radius: 1.5
    color: Qt.alpha(thumb.ink, 0.72)
  }
  Rectangle {
    visible: thumb.page.day !== ""
    anchors.right: parent.right
    anchors.rightMargin: thumb.pad
    y: 8.5
    width: 12
    height: 2
    radius: 1
    color: Qt.alpha(thumb.ink, 0.35)
  }
  Rectangle {
    visible: thumb.look.headRule === true
    x: 0
    y: thumb.bodyTop - 3
    width: parent.width
    height: 1
    color: Qt.alpha(thumb.look.line || "#7d9cc4", (thumb.look.lineAlpha || 0.4) * 1.2)
  }

  Column {
    x: thumb.pad
    y: thumb.bodyTop
    width: thumb.width - thumb.pad * 2
    Repeater {
      model: thumb.rows
      delegate: Item {
        id: row
        required property var modelData
        width: parent.width
        height: thumb.rowH
        readonly property string type: modelData.type

        // The ruled line it sits on.
        Rectangle {
          visible: thumb.look.pattern === "ruled" || thumb.look.pattern === "legal"
          x: -thumb.pad
          y: row.height - 1
          width: thumb.width
          height: 0.6
          color: Qt.alpha(thumb.look.line || "#7d9cc4", thumb.look.lineAlpha || 0.4)
        }
        Loader {
          // What the mark drawn in it needs to know (a note's color, a week's days).
          property var info: row.modelData
          anchors.fill: parent
          sourceComponent: row.type === "h1" || row.type === "h2" || row.type === "h3" ? headingMark
            : row.type === "check" ? checkMark
            : row.type === "bullet" ? bulletMark
            : row.type === "number" ? numberMark
            : row.type === "time" ? timeMark
            : row.type === "habit" ? habitMark
            : row.type === "callout" ? noteMark
            : row.type === "quote" ? quoteMark
            : row.type === "calhead" ? calHeadMark
            : row.type === "calweek" ? calWeekMark
            : null
        }
        // Words already written on it (a packing list's).
        Rectangle {
          visible: row.modelData.written === true
          x: 7
          y: row.height - 3
          width: parent.width * 0.38
          height: 1.2
          radius: 0.6
          color: Qt.alpha(thumb.ink, 0.45)
        }
      }
    }
  }

  Component {
    id: headingMark
    Item {
      Rectangle { y: parent.height - 3.6; width: parent.width * 0.42; height: 2.2; radius: 1.1; color: Qt.alpha(thumb.ink, 0.7) }
    }
  }
  Component {
    id: checkMark
    Item {
      Rectangle { y: parent.height - 5; width: 4; height: 4; radius: 1; color: "transparent"; border.width: 0.8; border.color: Qt.alpha(thumb.ink, 0.6) }
    }
  }
  Component {
    id: bulletMark
    Item {
      Rectangle { x: 1; y: parent.height - 3.6; width: 2; height: 2; radius: 1; color: Qt.alpha(thumb.ink, 0.7) }
    }
  }
  Component {
    id: numberMark
    Item {
      Rectangle { y: parent.height - 3.4; width: 3; height: 1.4; radius: 0.7; color: Qt.alpha(thumb.ink, 0.6) }
    }
  }
  Component {
    id: timeMark
    Item {
      Rectangle { y: parent.height - 3.4; width: 7; height: 1.4; radius: 0.7; color: Qt.alpha(thumb.ink, 0.45) }
      Rectangle { x: 10; width: 0.8; height: parent.height; color: Qt.alpha(thumb.accent, 0.5) }
    }
  }
  Component {
    id: habitMark
    Item {
      Row {
        anchors.right: parent.right
        y: parent.height - 5.2
        spacing: 1.4
        Repeater {
          model: 7
          delegate: Rectangle { width: 4.2; height: 4.2; radius: 2.1; color: "transparent"; border.width: 0.7; border.color: Qt.alpha(thumb.ink, 0.5) }
        }
      }
    }
  }
  Component {
    id: noteMark
    Item {
      id: note
      readonly property var info: parent ? parent.info : null
      Rectangle { y: 1; width: parent.width; height: parent.height - 1.5; radius: 1; color: Papers.toneColor(note.info && note.info.tone ? note.info.tone : "yellow", thumb.look.dark === true) }
    }
  }
  Component {
    id: quoteMark
    Item {
      Rectangle { x: 1; width: 1; height: parent.height; color: Qt.alpha(thumb.accent, 0.7) }
    }
  }
  Component {
    id: calHeadMark
    Item {
      Rectangle { y: parent.height - 3.6; width: parent.width * 0.3; height: 2; radius: 1; color: Qt.alpha(thumb.ink, 0.65) }
    }
  }
  Component {
    id: calWeekMark
    Item {
      id: week
      readonly property var info: parent ? parent.info : null
      Repeater {
        model: 7
        delegate: Rectangle {
          required property int index
          visible: week.info !== null && index >= week.info.from && index <= week.info.to
          x: (index + 0.5) * week.width / 7 - 1
          y: week.height - 3.4
          width: 2
          height: 2
          radius: 1
          color: Qt.alpha(thumb.ink, index >= 5 ? 0.35 : 0.6)
        }
      }
    }
  }
}
