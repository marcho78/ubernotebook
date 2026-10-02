import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace
import "../Docs.js" as Docs
import "../Dates.js" as Dates

// A project's line under its title: its status (a click changes it), when
// it's due (late in red; a click picks a date), and how far along it is (the
// to-dos on it and on the pages in it). Done, it offers to go in the archive.
// A page is a project from its ⋯ menu (or the Project plan template).
Item {
  id: bar

  property var theme: null
  // DocView: the page, its index, and changing the project.
  property var view: null

  readonly property var project: { var r = view ? view.revision : 0; return view && view.page && view.page.project ? view.page.project : null }
  readonly property var status: Workspace.statusOf(project ? project.status : "active")
  readonly property var due: { var k = view ? view.revision : 0; return project && project.due ? Workspace.dueInfo(project.due, new Date()) : null }
  readonly property var progress: {
    var r = view && view.workspace ? view.workspace.revision : 0
    var rr = view ? view.revision : 0
    return view && view.page && view.workspace ? Workspace.projectProgress(view.workspace.index, view.page.id) : { done: 0, total: 0 }
  }
  readonly property bool archived: { var r = view && view.workspace ? view.workspace.revision : 0; return view && view.page && view.workspace ? Workspace.inArchive(view.workspace.index, view.page.id) : false }
  readonly property bool readOnly: view ? view.locked : true

  visible: project !== null
  width: parent ? parent.width : 600
  height: visible ? 38 : 0

  function shade(id, back) {
    var c = Docs.colorEntry(id)
    return c ? (back ? c.background : c.text)[theme.dark ? 1 : 0] : String(theme.muted)
  }

  component Chip2: Rectangle {
    id: chip
    property string label: ""
    property color ink: bar.theme.text
    property color fill: "transparent"
    property string glyph: ""
    property color dot: "transparent"
    signal clicked()
    height: 28
    width: chipRow.implicitWidth + 18
    radius: 7
    color: chipHover.hovered && !bar.readOnly ? Qt.tint(fill, Qt.alpha(bar.theme.text, 0.06)) : fill
    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: 6
      Rectangle { visible: chip.dot.a > 0; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: chip.dot }
      Text {
        visible: chip.glyph !== ""
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: chip.glyph
        font.family: bar.theme.iconFont
        font.pixelSize: 13
        color: chip.ink
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: chip.label
        font.family: bar.theme.uiFont
        font.pixelSize: 13
        font.weight: Font.Medium
        color: chip.ink
      }
    }
    HoverHandler { id: chipHover; cursorShape: bar.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor }
    TapHandler { enabled: !bar.readOnly; onTapped: chip.clicked() }
  }

  Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    Chip2 {
      id: statusChip
      objectName: "projectStatus"
      label: bar.status.label
      dot: bar.shade(bar.status.color, false)
      ink: bar.theme.text
      fill: bar.shade(bar.status.color, true)
      onClicked: statusMenu.open()

      Pop {
        id: statusMenu
        theme: bar.theme
        focus: false
        width: 200
        y: statusChip.height + 6
        contentItem: Column {
          spacing: 2
          Repeater {
            model: Workspace.STATUSES
            delegate: MenuRow {
              required property var modelData
              width: parent.width
              theme: bar.theme
              icon: ""
              text: modelData.label
              checked: bar.status.id === modelData.id
              onClicked: { statusMenu.close(); bar.view.setProjectStatus(modelData.id) }
              Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 9; height: 9; radius: 4.5; color: bar.shade(modelData.color, false); visible: !parent.checked }
            }
          }
          Rectangle { width: parent.width; height: 1; color: bar.theme.line }
          MenuRow { width: parent.width; theme: bar.theme; icon: bar.theme.icons.close; text: "Not a project"; onClicked: { statusMenu.close(); bar.view.setProject(null) } }
        }
      }
    }

    Chip2 {
      id: dueChip
      objectName: "projectDue"
      glyph: bar.theme.icons.calendar
      label: bar.due ? (bar.due.overdue && bar.status.id !== "done" ? bar.due.label : "Due " + bar.due.label) : "Add a due date"
      ink: bar.due && bar.due.overdue && bar.status.id !== "done" ? bar.shade("red", false) : bar.due ? bar.theme.text : bar.theme.muted
      fill: bar.due && bar.due.overdue && bar.status.id !== "done" ? bar.shade("red", true) : "transparent"
      onClicked: duePop.start()

      Pop {
        id: duePop
        theme: bar.theme
        width: 260
        y: dueChip.height + 6
        property var parsed: null
        function start() {
          dueField.text = ""
          parsed = null
          open()
          dueField.focusField()
        }
        function take(iso) {
          close()
          bar.view.setProjectDue(iso)
        }
        contentItem: Column {
          spacing: 6
          Field {
            id: dueField
            objectName: "dueField"
            theme: bar.theme
            width: parent.width
            height: 34
            placeholder: "A date: fri, oct 20, in 2 weeks"
            onEdited: function(text) { var d = Dates.parse(text, new Date()); duePop.parsed = d ? Dates.iso(d.at, false) : null }
            onAccepted: if (duePop.parsed) duePop.take(duePop.parsed)
            onEscaped: duePop.close()
          }
          MenuRow {
            visible: duePop.parsed !== null
            width: parent.width
            theme: bar.theme
            icon: bar.theme.icons.calendar
            text: duePop.parsed ? Dates.label(Dates.fromIso(duePop.parsed).at, false, new Date()) : ""
            hint: "Enter"
            onClicked: duePop.take(duePop.parsed)
          }
          Repeater {
            model: dueField.text.trim() ? [] : [
              { label: "Today", days: 0 }, { label: "Tomorrow", days: 1 }, { label: "Next week", days: -1 }, { label: "In 2 weeks", days: 14 }, { label: "In a month", days: 30 }
            ]
            delegate: MenuRow {
              required property var modelData
              width: parent.width
              theme: bar.theme
              icon: bar.theme.icons.calendar
              text: modelData.label
              readonly property string iso: {
                var n = new Date()
                var d = modelData.days >= 0 ? new Date(n.getFullYear(), n.getMonth(), n.getDate() + modelData.days) : Dates.parse("next monday", n).at
                return Dates.iso(d, false)
              }
              hint: Dates.label(Dates.fromIso(iso).at, false, new Date())
              onClicked: duePop.take(iso)
            }
          }
          Rectangle { visible: bar.project && bar.project.due !== ""; width: parent.width; height: 1; color: bar.theme.line }
          MenuRow {
            visible: bar.project && bar.project.due !== ""
            width: parent.width
            theme: bar.theme
            icon: bar.theme.icons.close
            text: "No due date"
            onClicked: duePop.take("")
          }
        }
      }
    }

    // How far along: the to-dos done of all of them.
    Row {
      objectName: "projectProgress"
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8
      leftPadding: 4
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.progress.total > 0
        width: 110
        height: 6
        radius: 3
        color: Qt.alpha(bar.theme.text, 0.1)
        Rectangle {
          width: parent.width * (bar.progress.total ? bar.progress.done / bar.progress.total : 0)
          height: parent.height
          radius: 3
          color: bar.progress.total && bar.progress.done === bar.progress.total ? bar.shade("green", false) : bar.theme.accent
          Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: bar.progress.total ? bar.progress.done + " of " + bar.progress.total + " to-dos" : "No to-dos yet"
        font.family: bar.theme.uiFont
        font.pixelSize: 12
        color: bar.theme.muted
      }
    }

    // Done: away in the archive?
    Chip2 {
      objectName: "projectArchive"
      visible: bar.status.id === "done" && !bar.archived
      glyph: bar.theme.icons.archive
      label: "Archive it"
      ink: bar.theme.muted
      fill: "transparent"
      onClicked: bar.view.archivePage(bar.view.page.id, true)
    }
  }
}
