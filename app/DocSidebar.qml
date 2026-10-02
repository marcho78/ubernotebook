import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace

// The sidebar of Pages: the switch back to notebooks, search, a new page,
// and every page as a tree (a page's arrow shows the pages inside it; + adds
// one, ⋯ has its menu), the tags (a click shows every block with one), the
// trash and the settings at the foot.
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
  // The tags, by name (a tag inside another under it) or by color, as Settings has it.
  readonly property string tagSort: view.settings.tagSort === "color" ? "color" : "name"
  readonly property var tagList: {
    var r = view.workspace ? view.workspace.revision : 0
    var k = view.tagColorsKey
    return view.workspace ? Workspace.sortTags(Workspace.tagList(view.workspace.index), view.tagColorsShown, bar.tagSort) : []
  }
  property bool tagsOpen: true
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
    anchors.bottom: tagsBox.visible ? tagsBox.top : foot.top
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
      readonly property bool current: bar.view.page !== null && bar.view.page.id === modelData.id
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

  // The tags, above the foot: each with its color and how many blocks have it.
  Column {
    id: tagsBox
    objectName: "sidebarTags"
    x: 8
    width: parent.width - 16
    anchors.bottom: foot.top
    anchors.bottomMargin: 6
    visible: bar.tagList.length > 0
    spacing: 0
    Rectangle { width: parent.width; height: 1; color: bar.theme.line }
    Item { width: 1; height: 6 }
    Rectangle {
      width: parent.width
      height: 26
      radius: 6
      color: tagsHead.hovered ? bar.theme.hover : "transparent"
      Icon {
        theme: bar.theme
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        text: bar.tagsOpen ? bar.theme.icons.down : bar.theme.icons.right
        size: 13
        color: bar.theme.muted
      }
      Text {
        textFormat: Text.PlainText
        x: 24
        anchors.verticalCenter: parent.verticalCenter
        text: "Tags"
        font.family: bar.theme.uiFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.4
        color: bar.theme.muted
      }
      Text {
        textFormat: Text.PlainText
        anchors.right: sortButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: String(bar.tagList.length)
        font.family: bar.theme.uiFont
        font.pixelSize: 11
        color: bar.theme.faint
      }
      HoverHandler { id: tagsHead; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: bar.tagsOpen = !bar.tagsOpen }
      // By name or by color.
      Rectangle {
        id: sortButton
        objectName: "tagSort"
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: sortText.implicitWidth + 12
        height: 20
        radius: 10
        color: sortHover.hovered ? bar.theme.pressed : "transparent"
        Text {
          id: sortText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: bar.tagSort === "color" ? "By color" : "A\u2013Z"
          font.family: bar.theme.uiFont
          font.pixelSize: 10
          color: bar.theme.muted
        }
        HoverHandler { id: sortHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          gesturePolicy: TapHandler.ReleaseWithinBounds
          onTapped: if (bar.view.service) bar.view.service.setSetting("tagSort", bar.tagSort === "color" ? "name" : "color")
        }
        ToolTip.visible: sortHover.hovered
        ToolTip.delay: 500
        ToolTip.text: bar.tagSort === "color" ? "Sorted by color: click for A\u2013Z" : "Sorted by name: click to sort by color"
      }
    }
    ListView {
      id: tagRows
      width: parent.width
      height: bar.tagsOpen ? Math.min(bar.tagList.length * 28, Math.max(90, bar.height * 0.26)) : 0
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: bar.tagList
      delegate: Rectangle {
        id: tagRow
        required property var modelData
        readonly property bool current: bar.view.tagShown === modelData.name
        readonly property var look: { var k = bar.view.tagColorsKey; return bar.view.tagLook(modelData.name) }
        objectName: "tagRow"
        width: tagRows.width
        height: 28
        radius: 6
        color: current ? bar.theme.pressed : tagHover.hovered ? bar.theme.hover : "transparent"
        Rectangle {
          id: dot
          x: 14 + tagRow.modelData.depth * 14
          anchors.verticalCenter: parent.verticalCenter
          width: 10
          height: 10
          radius: 5
          color: tagRow.look.color
        }
        Text {
          textFormat: Text.PlainText
          x: dot.x + 20
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - (tagHover.hovered ? 34 : 34)
          elide: Text.ElideRight
          // Under the tag it's in, only its own part ("/acme").
          text: tagRow.modelData.depth > 0 ? "/" + tagRow.modelData.label.slice(tagRow.modelData.label.lastIndexOf("/") + 1) : tagRow.modelData.label
          font.family: bar.theme.uiFont
          font.pixelSize: 13
          font.weight: tagRow.current ? Font.DemiBold : Font.Normal
          color: bar.theme.text
        }
        Text {
          visible: !tagHover.hovered
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: String(tagRow.modelData.blocks)
          font.family: bar.theme.uiFont
          font.pixelSize: 11
          color: bar.theme.faint
        }
        IconButton {
          id: tagMore
          objectName: "tagMore"
          visible: tagHover.hovered
          anchors.right: parent.right
          anchors.rightMargin: 2
          anchors.verticalCenter: parent.verticalCenter
          theme: bar.theme; icon: bar.theme.icons.more; size: 24; iconSize: 14; tip: "Color, rename\u2026"
          onClicked: bar.view.openTagMenu(tagRow.modelData.name, tagRow)
        }
        HoverHandler { id: tagHover; cursorShape: Qt.PointingHandCursor }
        // (Not a click on its ⋯, which has its own.)
        TapHandler {
          onTapped: function(point) {
            var p = tagMore.mapFromItem(tagRow, point.position.x, point.position.y)
            if (tagMore.visible && tagMore.contains(p)) return
            bar.view.openTag(tagRow.modelData.name)
          }
        }
        // A right-click: its menu.
        TapHandler {
          acceptedButtons: Qt.RightButton
          onTapped: bar.view.openTagMenu(tagRow.modelData.name, tagRow)
        }
      }
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
