import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../Help.js" as Help

// Help (Ctrl+/, or Help at the sidebar's foot): every key and where it
// works, what you can type, every block, every feature where you meet it,
// and the commands from a terminal (Help.js); a search over all of it.
// Only words, shown as plain text: nothing here is run, opened or read
// from your notes.
Popup {
  id: panel
  objectName: "helpPanel"

  property var theme: null
  property string section: "start"
  property string query: ""

  readonly property var sections: Help.SECTIONS
  readonly property var current: sections.filter(function(x) { return x.id === panel.section })[0] || sections[0]
  // What's found for the words typed: [{ section, group, row }], the first 300.
  readonly property var found: query.trim() ? Help.find(query).slice(0, 300) : []
  readonly property bool searching: query.trim() !== ""

  function openAt(id) {
    if (sections.some(function(x) { return x.id === id })) section = id
    open()
  }

  anchors.centerIn: Overlay.overlay
  width: Math.min(980, (parent ? parent.width : 980) - 40)
  height: Math.min(720, (parent ? parent.height : 720) - 40)
  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, panel.theme && panel.theme.dark ? 0.5 : 0.3) }

  onOpened: {
    query = ""
    search.text = ""
    flick.contentY = 0
    search.focusField()
  }
  onSectionChanged: flick.contentY = 0
  onQueryChanged: flick.contentY = 0

  background: Item {
    Rectangle { id: plate; anchors.fill: parent; radius: 16; color: panel.theme.surface; border.width: 1; border.color: panel.theme.line; visible: false }
    MultiEffect { source: plate; anchors.fill: plate; shadowEnabled: true; shadowColor: panel.theme.shadow; shadowBlur: 1.0; shadowVerticalOffset: 14; autoPaddingEnabled: true }
  }

  // A row: what you do (a key, what you type, where you click), what it
  // does, and a note under it.
  component HelpRow: Item {
    id: hr
    property var row: ["", "", ""]
    objectName: "helpRow"
    width: parent ? parent.width : 400
    height: Math.max(doText.height, whatCol.height) + 12
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(panel.theme.line, 0.6) }
    Text {
      id: doText
      y: 6
      width: Math.round(hr.width * 0.34) - 12
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: hr.row[0]
      font.family: panel.theme.uiFont
      font.pixelSize: 13
      font.weight: Font.DemiBold
      color: panel.theme.text
    }
    Column {
      id: whatCol
      x: Math.round(hr.width * 0.34)
      y: 6
      width: hr.width - x
      spacing: 2
      Text {
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: hr.row[1]
        font.family: panel.theme.uiFont
        font.pixelSize: 13
        color: panel.theme.text
      }
      Text {
        visible: hr.row[2] !== ""
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: hr.row[2]
        font.family: panel.theme.uiFont
        font.pixelSize: 12
        color: panel.theme.muted
      }
    }
  }
  component GroupTitle: Text {
    width: parent ? parent.width : 400
    topPadding: 10
    bottomPadding: 4
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    font.family: panel.theme.uiFont
    font.pixelSize: 12
    font.weight: Font.DemiBold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.6
    color: panel.theme.muted
  }

  contentItem: Item {
    // ---- the sections, at the left ----
    Rectangle {
      id: nav
      width: 220
      height: parent.height
      radius: 16
      color: Qt.alpha(panel.theme.text, 0.035)
      // (Square on the right, where it meets the section.)
      Rectangle { anchors.right: parent.right; width: 16; height: parent.height; color: parent.color }
      Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: panel.theme.line }

      Text {
        x: 22
        y: 22
        textFormat: Text.PlainText
        text: "Help"
        font.family: panel.theme.uiFont
        font.pixelSize: 19
        font.weight: Font.DemiBold
        color: panel.theme.text
      }
      Field {
        id: search
        objectName: "helpSearch"
        x: 12
        y: 58
        width: parent.width - 24
        height: 34
        theme: panel.theme
        icon: panel.theme.icons.search
        placeholder: "Search Help"
        onEdited: function(text) { panel.query = text }
        onEscaped: { if (panel.query) { text = ""; panel.query = "" } else panel.close() }
      }
      Flickable {
        x: 10
        y: search.y + search.height + 10
        width: parent.width - 20
        height: parent.height - y - 12
        contentHeight: navCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: navCol
          width: parent.width
          spacing: 2
          Repeater {
            model: panel.sections
            delegate: Rectangle {
              id: navRow
              required property var modelData
              readonly property bool chosen: !panel.searching && panel.section === modelData.id
              objectName: "helpSection_" + modelData.id
              width: parent.width
              height: 32
              radius: 8
              color: chosen ? panel.theme.pressed : navHover.hovered ? panel.theme.hover : "transparent"
              Icon {
                theme: panel.theme
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: panel.theme.icons[navRow.modelData.icon] || ""
                size: 15
                color: navRow.chosen ? panel.theme.text : panel.theme.muted
              }
              Text {
                x: 38
                width: parent.width - 46
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: navRow.modelData.label
                font.family: panel.theme.uiFont
                font.pixelSize: 13
                font.weight: navRow.chosen ? Font.DemiBold : Font.Normal
                color: panel.theme.text
              }
              HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
              TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: { search.text = ""; panel.query = ""; panel.section = navRow.modelData.id }
              }
            }
          }
        }
      }
    }

    // ---- the section, or what's found ----
    Column {
      id: head
      x: nav.width + 32
      y: 24
      width: parent.width - x - 64
      spacing: 4
      Text {
        objectName: "helpTitle"
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: panel.searching ? (panel.found.length === 0 ? "Nothing found" : panel.found.length + " found for “" + panel.query.trim() + "”") : panel.current.label
        font.family: panel.theme.uiFont
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: panel.theme.text
      }
      Text {
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: panel.searching ? (panel.found.length === 0 ? "Try other words, or fewer." : "") : panel.current.note
        visible: text !== ""
        font.family: panel.theme.uiFont
        font.pixelSize: 13
        color: panel.theme.muted
      }
    }
    IconButton {
      objectName: "helpClose"
      anchors.right: parent.right
      anchors.rightMargin: 14
      y: 14
      theme: panel.theme
      icon: panel.theme.icons.close
      onClicked: panel.close()
    }

    Flickable {
      id: flick
      objectName: "helpFlick"
      x: nav.width + 32
      y: head.y + head.height + 16
      width: parent.width - x - 28
      height: parent.height - y - 8
      contentHeight: body.height + 28
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

      Column {
        id: body
        width: flick.width - 10
        spacing: 0

        // A section: its groups, each with its rows.
        Repeater {
          model: panel.searching ? [] : panel.current.groups
          delegate: Column {
            id: groupCol
            required property var modelData
            width: body.width
            GroupTitle { text: groupCol.modelData.title; visible: panel.current.groups.length > 1 }
            Repeater {
              model: groupCol.modelData.rows
              delegate: HelpRow { required property var modelData; row: modelData }
            }
          }
        }
        // What's found: each row with where it's from.
        Repeater {
          model: panel.found
          delegate: Column {
            id: foundCol
            required property var modelData
            required property int index
            readonly property string sectionLabel: (panel.sections.filter(function(x) { return x.id === foundCol.modelData.section })[0] || { label: "" }).label
            readonly property string place: sectionLabel + (foundCol.modelData.group && foundCol.modelData.group !== sectionLabel ? "  ·  " + foundCol.modelData.group : "")
            width: body.width
            GroupTitle {
              text: foundCol.place
              visible: foundCol.index === 0 || panel.found[foundCol.index - 1].section !== foundCol.modelData.section || panel.found[foundCol.index - 1].group !== foundCol.modelData.group
            }
            HelpRow { row: foundCol.modelData.row }
          }
        }
      }
    }
  }
}
