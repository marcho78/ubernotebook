import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../Covers.js" as Covers

// The shelf: every notebook, lying on the desk cover up. Click one to open it;
// right-click for its cover, exporting or putting it in the trash. The search
// at the top looks through every page of every notebook.
Item {
  id: shelf

  property var theme: null
  property var store: null
  // The service: the profiles, for the switch at the top.
  property var service: null
  property string shortcutHint: ""

  signal openRequested(var notebook, rect from)
  signal newRequested()
  signal editRequested(var notebook)
  signal deleteRequested(var notebook)
  signal settingsRequested()
  // What's new in a newer version (the corner says there's one).
  signal releaseNotesRequested()
  signal resultOpened(string notebookId, string pageId, string query)
  // Pages (or notebooks, where it is): the switch at the top.
  signal spaceRequested(string space)

  readonly property var notebooks: store ? store.notebooks : []
  readonly property real tileW: 188
  readonly property real tileH: 258
  property string query: ""
  property var results: []
  property bool searching: false

  // Where a notebook's cover is, in another item's coordinates.
  function coverRect(id, target) {
    for (var i = 0; i < grid.children.length; i++) {
      var tile = grid.children[i]
      if (tile.notebookId === id && tile.cover) return tile.cover.mapToItem(target, 0, 0, tile.cover.width, tile.cover.height)
    }
    return Qt.rect(0, 0, 0, 0)
  }

  function focusSearch() { search.focusField() }

  Timer {
    id: searchTimer
    interval: 180
    onTriggered: {
      var q = shelf.query.trim()
      if (!q) { shelf.results = []; shelf.searching = false; return }
      shelf.searching = true
      shelf.store.search(q, function(found) {
        if (shelf.query.trim() !== q) return
        shelf.results = found
        shelf.searching = false
      })
    }
  }

  // ---- the header ---------------------------------------------------------------------

  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    height: 86

    Column {
      anchors.left: parent.left
      anchors.leftMargin: 34
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0
      Text {
        textFormat: Text.PlainText
        text: "Notebooks"
        font.family: shelf.theme.markerFont
        font.pixelSize: 30
        color: shelf.theme.text
      }
      // The profile open (a click: the others), and how many notebooks it has.
      Row {
        spacing: 8
        topPadding: 4
        ProfileSwitch {
          id: profileSwitch
          theme: shelf.theme
          service: shelf.service
          visible: shelf.service !== null && shelf.service.profiles !== undefined && shelf.service.profiles !== null
          anchors.verticalCenter: parent.verticalCenter
          onManageRequested: shelf.settingsRequested()
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: shelf.notebooks.length === 1 ? "1 notebook" : shelf.notebooks.length + " notebooks"
          font.family: shelf.theme.uiFont
          font.pixelSize: 12
          color: shelf.theme.muted
        }
      }
    }

    Field {
      id: search
      theme: shelf.theme
      width: Math.min(420, parent.width - 760)
      visible: width > 160
      anchors.centerIn: parent
      height: 38
      radius: 19
      icon: shelf.theme.icons.search
      placeholder: "Search every page"
      onEdited: function(text) { shelf.query = text; searchTimer.restart() }
      onEscaped: { text = ""; shelf.query = ""; shelf.results = [] }
      onAccepted: if (shelf.results.length) shelf.resultOpened(shelf.results[0].notebookId, shelf.results[0].pageId, shelf.query)
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: 24
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      SpaceSwitch {
        theme: shelf.theme
        space: "notebooks"
        anchors.verticalCenter: parent.verticalCenter
        onPicked: function(space) { shelf.spaceRequested(space) }
      }
      Item { width: 8; height: 1 }
      IconButton { theme: shelf.theme; icon: shelf.theme.icons.notebookPlus; label: "New notebook"; tip: "Ctrl+Shift+N"; onClicked: shelf.newRequested() }
      IconButton { theme: shelf.theme; icon: shelf.theme.icons.cog; tip: "Settings  Ctrl+,"; onClicked: shelf.settingsRequested() }
    }
  }

  // ---- the notebooks ------------------------------------------------------------------

  Flickable {
    id: flick
    anchors.top: header.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    visible: shelf.query.trim() === ""
    contentHeight: grid.height + 80
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Flow {
      id: grid
      readonly property int columns: Math.max(1, Math.floor((flick.width - 60) / (shelf.tileW + 46)))
      width: columns * (shelf.tileW + 46)
      x: (flick.width - width) / 2
      y: 18
      spacing: 0

      Repeater {
        model: shelf.notebooks
        delegate: Item {
          id: tile
          required property var modelData
          required property int index
          readonly property string notebookId: modelData.id
          property alias cover: coverItem
          width: shelf.tileW + 46
          height: shelf.tileH + 74

          Item {
            id: lift
            x: 23
            y: hover.hovered ? 4 : 10
            width: shelf.tileW
            height: shelf.tileH
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
              id: shadowShape
              anchors.fill: parent
              radius: 8
              color: "black"
              visible: false
            }
            MultiEffect {
              source: shadowShape
              anchors.fill: shadowShape
              shadowEnabled: true
              shadowColor: shelf.theme.shadow
              shadowBlur: 1.0
              shadowVerticalOffset: hover.hovered ? 16 : 9
              shadowHorizontalOffset: 2
              shadowOpacity: hover.hovered ? 0.9 : 0.7
              autoPaddingEnabled: true
              Behavior on shadowVerticalOffset { NumberAnimation { duration: 180 } }
            }

            Cover {
              id: coverItem
              anchors.fill: parent
              closed: true
              look: Covers.resolve(tile.modelData.cover, String(shelf.theme.accent))
              title: tile.modelData.title
              binding: tile.modelData.binding
              pages: tile.modelData.pageCount
              fonts: shelf.theme.coverFonts
              seed: (tile.index * 0.137) % 1
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: lift.horizontalCenter
            y: lift.y + lift.height + 16
            text: (tile.modelData.pageCount === 1 ? "1 page" : tile.modelData.pageCount + " pages") + "  \u00b7  " + shelf.ago(tile.modelData.modified)
            font.family: shelf.theme.uiFont
            font.pixelSize: 12
            color: shelf.theme.muted
          }

          HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
          TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: shelf.openRequested(tile.modelData, coverItem.mapToItem(shelf, 0, 0, coverItem.width, coverItem.height))
          }
          TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: function(point) {
              menu.target = tile.modelData
              menu.x = point.position.x
              menu.y = point.position.y
              menu.parent = tile
              menu.open()
            }
          }
        }
      }

      // A new notebook, still in its wrapper.
      Item {
        width: shelf.tileW + 46
        height: shelf.tileH + 74
        Rectangle {
          x: 23
          y: newHover.hovered ? 4 : 10
          width: shelf.tileW
          height: shelf.tileH
          radius: 10
          color: newHover.hovered ? shelf.theme.hover : "transparent"
          border.width: 2
          border.color: newHover.hovered ? Qt.alpha(shelf.theme.accent, 0.8) : shelf.theme.line
          Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          Column {
            anchors.centerIn: parent
            spacing: 8
            Icon { theme: shelf.theme; text: shelf.theme.icons.plus; size: 34; color: newHover.hovered ? shelf.theme.accent : shelf.theme.muted; anchors.horizontalCenter: parent.horizontalCenter }
            Text { textFormat: Text.PlainText; text: "New notebook"; font.family: shelf.theme.uiFont; font.pixelSize: 13; color: shelf.theme.muted; anchors.horizontalCenter: parent.horizontalCenter }
          }
        }
        HoverHandler { id: newHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: shelf.newRequested() }
      }
    }
  }

  Pop {
    id: menu
    theme: shelf.theme
    focus: false
    property var target: null
    contentItem: Column {
      spacing: 2
      MenuRow { theme: shelf.theme; icon: shelf.theme.icons.open; text: "Open"; onClicked: { menu.close(); shelf.openRequested(menu.target, shelf.coverRect(menu.target.id, shelf)) } }
      MenuRow { theme: shelf.theme; icon: shelf.theme.icons.cog; text: "Cover, paper and pen\u2026"; onClicked: { menu.close(); shelf.editRequested(menu.target) } }
      MenuRow { theme: shelf.theme; icon: shelf.theme.icons.export; text: "Export as Markdown"; onClicked: { menu.close(); shelf.store.exportNotebook(menu.target.id) } }
      Rectangle { width: parent.width; height: 1; color: shelf.theme.line }
      MenuRow { theme: shelf.theme; icon: shelf.theme.icons.trash; text: "Put in the trash\u2026"; danger: true; onClicked: { menu.close(); shelf.deleteRequested(menu.target) } }
    }
  }

  // A newer version, if there's one; who makes Uber Notebook, on X.
  SideFooter {
    objectName: "shelfFooter"
    x: 22
    width: 250
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 14
    z: 2
    theme: shelf.theme
    service: shelf.service
    onNotesRequested: shelf.releaseNotesRequested()
  }

  // ---- search results ---------------------------------------------------------------------

  ListView {
    id: resultsList
    anchors.top: header.bottom
    anchors.topMargin: 8
    anchors.bottom: parent.bottom
    width: Math.min(720, parent.width - 60)
    anchors.horizontalCenter: parent.horizontalCenter
    visible: shelf.query.trim() !== ""
    clip: true
    spacing: 6
    model: shelf.results
    boundsBehavior: Flickable.StopAtBounds

    header: Text {
      textFormat: Text.PlainText
      width: resultsList.width
      height: 30
      text: shelf.searching && shelf.results.length === 0 ? "Looking\u2026"
        : shelf.results.length === 0 ? "Nothing on any page says \u201c" + shelf.query.trim() + "\u201d"
        : shelf.results.length === 1 ? "1 page" : shelf.results.length + " pages"
      font.family: shelf.theme.uiFont
      font.pixelSize: 13
      color: shelf.theme.muted
    }

    delegate: Rectangle {
      id: result
      required property var modelData
      width: resultsList.width
      height: 74
      radius: 12
      color: resultHover.hovered ? shelf.theme.surfaceHigh : shelf.theme.surface
      border.width: 1
      border.color: shelf.theme.line

      Rectangle {
        x: 14
        width: 30
        height: 42
        radius: 4
        anchors.verticalCenter: parent.verticalCenter
        color: Covers.resolve(result.modelData.cover, String(shelf.theme.accent)).color
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.2)
      }
      Column {
        x: 58
        width: parent.width - 74
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Text {
          width: parent.width
          text: shelf.escapeHtml(result.modelData.pageTitle) + "   <font color=\"" + shelf.theme.muted + "\">" + result.modelData.notebookTitle.replace(/&/g, "&amp;").replace(/</g, "&lt;") + ", page " + (result.modelData.pageNumber) + "</font>"
          textFormat: Text.StyledText
          elide: Text.ElideRight
          font.family: shelf.theme.uiFont
          font.pixelSize: 14
          font.weight: Font.Medium
          color: shelf.theme.text
        }
        Text {
          width: parent.width
          text: shelf.escapeHtml(result.modelData.snippet.before) + "<b><font color=\"" + shelf.theme.accent + "\">" + shelf.escapeHtml(result.modelData.snippet.match) + "</font></b>" + shelf.escapeHtml(result.modelData.snippet.after)
          textFormat: Text.StyledText
          elide: Text.ElideRight
          font.family: shelf.theme.uiFont
          font.pixelSize: 13
          color: shelf.theme.muted
        }
      }
      HoverHandler { id: resultHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: shelf.resultOpened(result.modelData.notebookId, result.modelData.pageId, shelf.query.trim()) }
    }
  }

  // ---- the first time ------------------------------------------------------------------------

  Text {
    textFormat: Text.PlainText
    visible: shelf.notebooks.length === 0 && shelf.store && shelf.store.ready
    anchors.horizontalCenter: parent.horizontalCenter
    y: header.height + shelf.tileH + 130
    text: "Your first notebook is waiting. Pick a cover."
    font.family: shelf.theme.handFont
    font.pixelSize: 26
    color: shelf.theme.muted
  }

  function escapeHtml(text) {
    return String(text || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  // "just now", "5 min ago", "yesterday", "12 Mar".
  function ago(iso) {
    var t = Date.parse(iso)
    if (!isFinite(t)) return ""
    var s = (Date.now() - t) / 1000
    if (s < 60) return "just now"
    if (s < 3600) return Math.floor(s / 60) + " min ago"
    if (s < 86400) return Math.floor(s / 3600) + " h ago"
    if (s < 172800) return "yesterday"
    if (s < 7 * 86400) return Qt.formatDate(new Date(t), "dddd")
    return Qt.formatDate(new Date(t), new Date(t).getFullYear() === new Date().getFullYear() ? "d MMM" : "d MMM yyyy")
  }
}
