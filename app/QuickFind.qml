import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace
import "../Tags.js" as Tags

// Search in Pages (Ctrl+P): recent pages, or every page with the words you
// type in its title or on it, with the words around them; "#" and a tag's
// name, the tags first.
Pop {
  id: pop

  property var workspace: null
  property string query: ""
  property var found: []
  property int current: 0
  property bool searching: false

  signal pageChosen(string id)
  signal tagChosen(string name)

  // Another profile opening (a command, an agent): what was found in this
  // one gone, and the search closed.
  Connections {
    target: pop.workspace ? pop.workspace.files : null
    ignoreUnknownSignals: true
    function onSwitchingChanged() {
      if (!pop.workspace.files.switching) return
      searchTimer.stop()
      pop.query = ""
      pop.found = []
      pop.searching = false
      field.text = ""
      // (Still opening, too.)
      if (pop.visible) pop.close()
    }
  }

  width: Math.min(600, (parent ? parent.width : 600) - 40)
  height: Math.min(480, (parent ? parent.height : 480) - 80)
  padding: 12
  modal: true
  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, pop.theme && pop.theme.dark ? 0.4 : 0.2) }

  // Recent pages when nothing's typed.
  readonly property var recent: {
    var r = workspace ? workspace.revision : 0
    if (!workspace) return []
    var ix = workspace.index
    return Object.keys(ix.pages).filter(function(id) { return !Workspace.inTrash(ix, id) && !Workspace.inTemplates(ix, id) })
      .sort(function(a, b) { return ix.pages[a].modified < ix.pages[b].modified ? 1 : -1 })
      .slice(0, 12)
      .map(function(id) { return { id: id, title: ix.pages[id].title, icon: ix.pages[id].icon, snippet: null } })
  }
  // Tags with what's typed after "#".
  readonly property var tagHits: {
    var r = workspace ? workspace.revision : 0
    var q = query.trim()
    if (!workspace || q.charAt(0) !== "#") return []
    var list = Workspace.tagList(workspace.index)
    var by = {}
    list.forEach(function(t) { by[t.name] = t })
    return Tags.matching(list.map(function(t) { return t.name }), q, 6).map(function(n) { return { tag: n, title: by[n].label, icon: "", snippet: null, hint: by[n].blocks + (by[n].blocks === 1 ? " block" : " blocks") + " on " + by[n].pages + (by[n].pages === 1 ? " page" : " pages") } })
  }
  readonly property var results: query.trim() ? tagHits.concat(found) : recent

  function start() {
    x = ((parent ? parent.width : width) - width) / 2
    y = 60
    query = ""
    found = []
    current = 0
    field.text = ""
    open()
    field.focusField()
  }

  Timer {
    id: searchTimer
    interval: 160
    onTriggered: {
      var q = pop.query.trim()
      if (!q) { pop.found = []; return }
      pop.searching = true
      pop.workspace.search(q, function(list) {
        if (pop.query.trim() !== q) return
        pop.found = list
        pop.current = 0
        pop.searching = false
      })
    }
  }

  function take(i) {
    if (i < 0 || i >= results.length) return
    if (results[i].tag) { var name = results[i].tag; close(); tagChosen(name); return }
    var id = results[i].id
    close()
    pageChosen(id)
  }

  contentItem: Column {
    spacing: 8
    Field {
      id: field
      theme: pop.theme
      width: parent.width
      height: 40
      fontSize: 15
      icon: pop.theme.icons.search
      placeholder: "Search your pages"
      onEdited: function(text) { pop.query = text; searchTimer.restart() }
      onAccepted: pop.take(pop.current)
      onEscaped: pop.close()
      onDownPressed: pop.current = Math.min(pop.results.length - 1, pop.current + 1)
      onUpPressed: pop.current = Math.max(0, pop.current - 1)
    }
    Text {
      textFormat: Text.PlainText
      leftPadding: 6
      text: pop.query.trim() ? (pop.searching ? "Looking\u2026" : pop.results.length ? "Pages" : "Nothing found") : "Recent"
      font.family: pop.theme.uiFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      color: pop.theme.muted
    }
    ListView {
      id: list
      width: parent.width
      height: pop.height - 2 * pop.padding - 40 - 8 - 20
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: pop.results
      currentIndex: pop.current
      onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
      delegate: Rectangle {
        required property var modelData
        required property int index
        readonly property var where: {
          var r = pop.workspace ? pop.workspace.revision : 0
          if (modelData.tag) return modelData.hint
          return pop.workspace ? Workspace.path(pop.workspace.index, modelData.id).slice(0, -1).map(function(p) { return p.title || "Untitled" }).join(" / ") : ""
        }
        width: list.width
        height: modelData.snippet || where ? 50 : 34
        radius: 7
        color: index === pop.current ? pop.theme.hover : "transparent"
        Text {
          id: icon
          textFormat: Text.PlainText
          x: 10
          y: 8
          text: modelData.tag ? "#" : modelData.icon || "\u{1f4c4}"
          font.family: modelData.tag ? pop.theme.uiFont : "Noto Color Emoji"
          font.pixelSize: 15
        }
        Text {
          textFormat: Text.PlainText
          x: 38
          y: 7
          width: parent.width - x - 10
          elide: Text.ElideRight
          text: (modelData.title || "Untitled") + (where ? "  \u2014  " + where : "")
          font.family: pop.theme.uiFont
          font.pixelSize: 13
          color: pop.theme.text
        }
        Text {
          textFormat: Text.StyledText
          visible: !!modelData.snippet
          x: 38
          y: 27
          width: parent.width - x - 10
          elide: Text.ElideRight
          text: modelData.snippet ? pop.escapeHtml(modelData.snippet.before) + "<b>" + pop.escapeHtml(modelData.snippet.match) + "</b>" + pop.escapeHtml(modelData.snippet.after) : ""
          font.family: pop.theme.uiFont
          font.pixelSize: 12
          color: pop.theme.muted
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) pop.current = index }
        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: pop.take(index) }
      }
    }
  }

  function escapeHtml(text) {
    return String(text || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }
}
