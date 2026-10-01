import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace

// The sidebar of Pages: the switch back to notebooks, search, a new page,
// and every page as a tree (a page's arrow shows the pages inside it; + adds
// one, ⋯ has its menu), the trash and the settings at the foot.
Rectangle {
  id: bar

  property var theme: null
  property var view: null

  readonly property var rows: {
    var r = view.workspace ? view.workspace.revision : 0
    var o = view.openRows
    return view.workspace ? Workspace.rows(view.workspace.index, o) : []
  }
  readonly property var favorites: {
    var r = view.workspace ? view.workspace.revision : 0
    return view.workspace ? Workspace.favorites(view.workspace.index) : []
  }
  readonly property int trashCount: {
    var r = view.workspace ? view.workspace.revision : 0
    return view.workspace ? Workspace.trashed(view.workspace.index).length : 0
  }

  color: theme.dark ? Qt.darker(theme.background, 1.12) : Qt.darker(theme.background, 1.035)

  Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: bar.theme.line }

  component Row2: Rectangle {
    id: r2
    property string icon: ""
    property string text: ""
    property string hint: ""
    signal clicked()
    width: parent ? parent.width : 200
    height: 30
    radius: 6
    color: rowHover.hovered ? bar.theme.hover : "transparent"
    Icon {
      theme: bar.theme
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      text: r2.icon
      size: 15
      color: bar.theme.muted
    }
    Text {
      textFormat: Text.PlainText
      x: 38
      anchors.verticalCenter: parent.verticalCenter
      text: r2.text
      font.family: bar.theme.uiFont
      font.pixelSize: 13
      color: bar.theme.text
      opacity: 0.85
    }
    Text {
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: r2.hint
      font.family: bar.theme.uiFont
      font.pixelSize: 11
      color: bar.theme.faint
    }
    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: r2.clicked() }
  }

  Column {
    id: head
    x: 8
    y: 10
    width: parent.width - 16
    spacing: 2

    Item {
      width: parent.width
      height: 40
      SpaceSwitch {
        theme: bar.theme
        space: "pages"
        anchors.verticalCenter: parent.verticalCenter
        x: 4
        onPicked: function(space) { if (space === "notebooks") bar.view.notebooksRequested() }
      }
      IconButton {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        theme: bar.theme
        icon: bar.theme.icons.hideSidebar
        size: 28
        iconSize: 15
        tip: "Hide the sidebar  Ctrl+\\"
        onClicked: bar.view.sidebarShown = false
      }
    }
    Item { width: 1; height: 4 }
    Row2 { icon: bar.theme.icons.search; text: "Search"; hint: "Ctrl+P"; onClicked: bar.view.openFind() }
    Row2 { icon: bar.theme.icons.newPage; text: "New page"; hint: "Ctrl+N"; onClicked: bar.view.newPage("") }
  }

  // Favorites: the pages starred, at the top.
  Column {
    id: favs
    x: 8
    width: parent.width - 16
    anchors.top: head.bottom
    anchors.topMargin: bar.favorites.length ? 16 : 0
    visible: bar.favorites.length > 0
    spacing: 0
    Text {
      textFormat: Text.PlainText
      leftPadding: 12
      bottomPadding: 6
      text: "Favorites"
      font.family: bar.theme.uiFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      font.letterSpacing: 0.4
      color: bar.theme.muted
    }
    Repeater {
      model: bar.favorites
      delegate: Rectangle {
        required property var modelData
        readonly property var e: bar.view.workspace.index.pages[modelData] || ({ title: "", icon: "" })
        readonly property bool current: bar.view.page && bar.view.page.id === modelData
        width: favs.width
        height: 30
        radius: 6
        color: current ? bar.theme.pressed : favHover.hovered ? bar.theme.hover : "transparent"
        Text {
          id: favIcon
          textFormat: Text.PlainText
          x: 12
          anchors.verticalCenter: parent.verticalCenter
          text: parent.e.icon || "\u{1f4c4}"
          font.family: "Noto Color Emoji"
          font.pixelSize: 14
        }
        Text {
          textFormat: Text.PlainText
          x: 36
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - 8
          elide: Text.ElideRight
          text: parent.e.title || "Untitled"
          font.family: bar.theme.uiFont
          font.pixelSize: 13
          font.weight: parent.current ? Font.DemiBold : Font.Normal
          color: bar.theme.text
        }
        HoverHandler { id: favHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: bar.view.open(modelData) }
      }
    }
  }

  Text {
    id: pagesLabel
    textFormat: Text.PlainText
    x: 20
    anchors.top: favs.visible ? favs.bottom : head.bottom
    anchors.topMargin: 16
    text: "Pages"
    font.family: bar.theme.uiFont
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 0.4
    color: bar.theme.muted
  }

  ListView {
    id: tree
    anchors.top: pagesLabel.bottom
    anchors.topMargin: 6
    anchors.bottom: foot.top
    anchors.bottomMargin: 6
    x: 8
    width: parent.width - 16
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: bar.rows
    delegate: Rectangle {
      id: rowItem
      required property var modelData
      required property int index
      readonly property bool current: bar.view.page && bar.view.page.id === modelData.id
      width: tree.width
      height: 30
      radius: 6
      color: current ? bar.theme.pressed : treeHover.hovered ? bar.theme.hover : "transparent"

      // The arrow: the pages inside it, shown or not.
      Rectangle {
        id: arrow
        x: 4 + rowItem.modelData.depth * 14
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        radius: 4
        color: arrowHover.hovered ? bar.theme.pressed : "transparent"
        visible: rowItem.modelData.hasChildren || treeHover.hovered
        Icon {
          anchors.centerIn: parent
          theme: bar.theme
          text: rowItem.modelData.open ? bar.theme.icons.down : bar.theme.icons.right
          size: 14
          color: bar.theme.muted
          opacity: rowItem.modelData.hasChildren ? 1 : 0.35
        }
        HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: bar.view.toggleRow(rowItem.modelData.id) }
      }
      Text {
        id: rowIcon
        textFormat: Text.PlainText
        x: arrow.x + 22
        anchors.verticalCenter: parent.verticalCenter
        text: rowItem.modelData.icon || "\u{1f4c4}"
        font.family: "Noto Color Emoji"
        font.pixelSize: 14
        opacity: rowItem.modelData.icon ? 1 : 0.7
      }
      Text {
        textFormat: Text.PlainText
        x: rowIcon.x + 24
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - (treeHover.hovered ? 56 : 8)
        elide: Text.ElideRight
        text: rowItem.modelData.title || "Untitled"
        font.family: bar.theme.uiFont
        font.pixelSize: 13
        font.weight: rowItem.current ? Font.DemiBold : Font.Normal
        color: rowItem.modelData.title ? bar.theme.text : bar.theme.muted
      }
      Row {
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        visible: treeHover.hovered
        IconButton {
          theme: bar.theme; icon: bar.theme.icons.more; size: 24; iconSize: 14; tip: "Delete, move\u2026"
          onClicked: bar.view.openRowMenu(rowItem.modelData.id, rowItem)
        }
        IconButton {
          theme: bar.theme; icon: bar.theme.icons.plus; size: 24; iconSize: 14; tip: "A page inside it"
          onClicked: bar.view.newPage(rowItem.modelData.id)
        }
      }
      HoverHandler { id: treeHover }
      TapHandler { onTapped: bar.view.open(rowItem.modelData.id) }
    }

    Text {
      textFormat: Text.PlainText
      visible: tree.count === 0 && bar.view.workspace && bar.view.workspace.ready
      x: 12
      y: 6
      width: tree.width - 24
      wrapMode: Text.Wrap
      text: "No pages yet. Make one with New page."
      font.family: bar.theme.uiFont
      font.pixelSize: 12
      color: bar.theme.muted
    }
  }

  Column {
    id: foot
    x: 8
    width: parent.width - 16
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    spacing: 2
    Rectangle { width: parent.width; height: 1; color: bar.theme.line }
    Item { width: 1; height: 4 }
    Row2 {
      id: importRow
      icon: bar.theme.icons.export
      text: bar.view.workspace && bar.view.workspace.importing ? "Importing\u2026 " + bar.view.workspace.importCount : "Import\u2026"
      onClicked: bar.view.openImport(importRow)
    }
    Row2 { icon: bar.theme.icons.trash; text: "Trash"; hint: bar.trashCount > 0 ? String(bar.trashCount) : ""; onClicked: bar.view.openTrash() }
    Row2 { icon: bar.theme.icons.cog; text: "Settings"; hint: "Ctrl+,"; onClicked: bar.view.settingsRequested() }
  }
}
