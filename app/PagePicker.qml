import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace

// Picks a page: to link to, or to move something into. Type to find one by
// its title; the arrows and Enter pick it.
Pop {
  id: pop

  property var workspace: null
  property string title: "Link to page"
  // A page that can't be picked (and the pages inside it): the one being moved.
  property string exclude: ""
  // Whether the top of the workspace can be picked ("" as the page).
  property bool allowTop: false
  property string query: ""
  property int current: 0

  signal picked(string id)

  width: 380
  height: 420
  padding: 10

  readonly property var results: {
    var r = workspace ? workspace.revision : 0
    if (!workspace) return []
    var ix = workspace.index
    var out = []
    var skip = exclude ? Workspace.withDescendants(ix, exclude) : []
    if (query.trim()) {
      Workspace.findTitles(ix, query, 40).forEach(function(id) {
        if (skip.indexOf(id) < 0) out.push({ id: id, depth: 0, title: ix.pages[id].title, icon: ix.pages[id].icon, path: Workspace.path(ix, id).slice(0, -1).map(function(p) { return p.title || "Untitled" }).join(" / ") })
      })
    } else {
      if (allowTop) out.push({ id: "", depth: 0, title: "The top of Pages", icon: "", path: "" })
      var all = {}
      for (var id in ix.pages) all[id] = true
      Workspace.rows(ix, all).forEach(function(row) {
        if (skip.indexOf(row.id) < 0) out.push({ id: row.id, depth: row.depth, title: row.title, icon: row.icon, path: "" })
      })
    }
    return out
  }

  function openAt(anchorItem, heading) {
    title = heading || title
    parent = anchorItem
    x = (anchorItem.width - width) / 2
    y = Math.min(40, anchorItem.height - height)
    query = ""
    field.text = ""
    current = 0
    open()
    field.focusField()
  }

  function take(i) {
    if (i < 0 || i >= results.length) return
    var id = results[i].id
    close()
    picked(id)
  }

  contentItem: Column {
    spacing: 8
    Text {
      textFormat: Text.PlainText
      text: pop.title
      font.family: pop.theme.uiFont
      font.pixelSize: 13
      font.weight: Font.DemiBold
      color: pop.theme.text
    }
    Field {
      id: field
      theme: pop.theme
      width: parent.width
      height: 34
      icon: pop.theme.icons.search
      placeholder: "Find a page"
      onEdited: function(text) { pop.query = text; pop.current = 0 }
      onAccepted: pop.take(pop.current)
      onEscaped: pop.close()
      onDownPressed: pop.current = Math.min(pop.results.length - 1, pop.current + 1)
      onUpPressed: pop.current = Math.max(0, pop.current - 1)
    }
    ListView {
      id: list
      width: parent.width
      height: pop.height - 2 * pop.padding - 34 - 8 - 26
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: pop.results
      currentIndex: pop.current
      onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
      delegate: Rectangle {
        required property var modelData
        required property int index
        width: list.width
        height: modelData.path ? 44 : 32
        radius: 6
        color: index === pop.current ? pop.theme.hover : "transparent"
        Text {
          id: icon
          textFormat: Text.PlainText
          x: 8 + modelData.depth * 14
          y: 8
          text: modelData.id === "" ? "\u{1f3e0}" : modelData.icon || "\u{1f4c4}"
          font.family: "Noto Color Emoji"
          font.pixelSize: 14
        }
        Text {
          textFormat: Text.PlainText
          x: icon.x + 24
          y: 7
          width: parent.width - x - 8
          elide: Text.ElideRight
          text: modelData.title || "Untitled"
          font.family: pop.theme.uiFont
          font.pixelSize: 13
          color: pop.theme.text
        }
        Text {
          textFormat: Text.PlainText
          visible: modelData.path !== ""
          x: icon.x + 24
          y: 25
          width: parent.width - x - 8
          elide: Text.ElideRight
          text: modelData.path
          font.family: pop.theme.uiFont
          font.pixelSize: 11
          color: pop.theme.muted
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) pop.current = index }
        TapHandler { onTapped: pop.take(index) }
      }
      Text {
        textFormat: Text.PlainText
        visible: list.count === 0
        x: 8
        y: 6
        text: pop.query ? "No page is called that." : "No pages to pick."
        font.family: pop.theme.uiFont
        font.pixelSize: 12
        color: pop.theme.muted
      }
    }
  }
}
