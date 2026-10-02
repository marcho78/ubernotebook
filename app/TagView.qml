import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace
import "../Tags.js" as Tags
import "../Html.js" as Html

// A tag in Pages (a tag clicked, in a line or the sidebar): every block with
// it, page by page, the page changed last first. A to-do ticks here; a click
// on a block opens its page there; a link in it opens what it links to. The
// tag's color, renaming it (two tags made one, if it's renamed to one there
// is) and taking it off every page are at the top.
Item {
  id: tv

  property var theme: null
  property var workspace: null
  // DocView: opening pages and tags, and how text is drawn on a page.
  property var view: null
  property string name: ""

  // [{ id, title, icon, blocks: [{ uid, type, html, checked, indent }] }]
  property var groups: []
  property bool loading: false
  readonly property var info: {
    var r = workspace ? workspace.revision : 0
    var list = workspace ? Workspace.tagList(workspace.index) : []
    return list.filter(function(t) { return t.name === tv.name })[0] || { name: tv.name, label: "#" + tv.name, pages: 0, blocks: 0 }
  }
  readonly property int blockCount: { var n = 0; groups.forEach(function(g) { n += g.blocks.length }); return n }

  signal colorRequested(var anchor)
  signal renameRequested(var anchor)
  signal removeRequested()

  function load() {
    if (!workspace || !name) { groups = []; return }
    loading = true
    var want = name
    var ids = Workspace.pagesTagged(workspace.index, want)
    workspace.readPages(ids, function(pages) {
      if (tv.name !== want) return
      var byId = {}
      pages.forEach(function(p) { byId[p.id] = p })
      tv.groups = ids.filter(function(id) { return byId[id] }).map(function(id) {
        var e = tv.workspace.index.pages[id] || {}
        return { id: id, title: e.title || byId[id].title || "", icon: e.icon || byId[id].icon || "", blocks: Workspace.taggedBlocks(byId[id], want) }
      }).filter(function(g) { return g.blocks.length > 0 })
      tv.loading = false
    })
  }

  onNameChanged: load()

  // Pages change while it's shown (a to-do ticked, a tag added elsewhere):
  // read again, a moment after.
  Connections {
    target: tv.workspace
    function onRevisionChanged() { if (tv.visible && tv.name) reloadTimer.restart() }
    function onSaved(id) { if (tv.visible && tv.name) reloadTimer.restart() }
  }
  Timer { id: reloadTimer; interval: 250; onTriggered: tv.load() }

  // A to-do ticked here: on its page.
  function toggle(pageId, uid, checked) {
    workspace.editPage(pageId, function(page) {
      var b = page.blocks[uid]
      if (!b || b.type !== "check") return false
      b.checked = checked
    })
  }

  Rectangle { anchors.fill: parent; color: tv.theme.background }

  Flickable {
    id: flick
    anchors.fill: parent
    contentWidth: width
    contentHeight: body.height + 120
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: body
      x: Math.max(24, (flick.width - width) / 2)
      y: 56
      width: Math.min(720, flick.width - 48)
      spacing: 18

      // The tag, how much has it, and what's done to it.
      Item {
        width: parent.width
        height: 64
        Rectangle {
          id: pill
          readonly property var look: tv.view ? tv.view.tagLook(tv.name) : ({ color: "#555555", background: "#eeeeee" })
          y: 4
          width: pillText.implicitWidth + 28
          height: 40
          radius: 10
          color: look.background
          Text {
            id: pillText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: tv.info.label
            font.family: tv.theme.uiFont
            font.pixelSize: 22
            font.weight: Font.DemiBold
            color: pill.look.color
          }
        }
        Text {
          anchors.left: pill.right
          anchors.leftMargin: 14
          anchors.verticalCenter: pill.verticalCenter
          textFormat: Text.PlainText
          readonly property var colorFrom: { var k = tv.view ? tv.view.tagColorsKey : ""; return tv.workspace ? Workspace.tagColorOf(tv.workspace.index.tagColors || {}, tv.name).from : "" }
          text: (tv.loading && tv.groups.length === 0 ? "" : tv.blockCount + (tv.blockCount === 1 ? " block" : " blocks") + " on " + tv.groups.length + (tv.groups.length === 1 ? " page" : " pages"))
            + (colorFrom && colorFrom !== tv.name ? "  \u00b7  its color from #" + colorFrom : "")
          font.family: tv.theme.uiFont
          font.pixelSize: 13
          color: tv.theme.muted
        }
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: pill.verticalCenter
          spacing: 4
          IconButton {
            id: colorButton
            objectName: "tagColor"
            theme: tv.theme; icon: tv.theme.icons.palette; tip: "The tag's color"
            onClicked: tv.colorRequested(colorButton)
          }
          IconButton {
            id: renameButton
            objectName: "tagRename"
            theme: tv.theme; icon: tv.theme.icons.pen; tip: "Rename it everywhere"
            onClicked: tv.renameRequested(renameButton)
          }
          IconButton {
            objectName: "tagRemove"
            theme: tv.theme; icon: tv.theme.icons.trash; tip: "Take it off every page"
            active: tv.blockCount > 0
            onClicked: tv.removeRequested()
          }
        }
      }

      Text {
        visible: !tv.loading && tv.groups.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "No block has " + tv.info.label + " any more."
        font.family: tv.theme.uiFont
        font.pixelSize: 14
        color: tv.theme.muted
      }

      Repeater {
        model: tv.groups
        delegate: Column {
          id: group
          required property var modelData
          width: body.width
          spacing: 2

          // The page: a click opens it.
          Rectangle {
            width: parent.width
            height: 34
            radius: 7
            color: pageHover.hovered ? tv.theme.hover : "transparent"
            Text {
              id: pageIcon
              x: 8
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: group.modelData.icon || "\u{1f4c4}"
              font.family: "Noto Color Emoji"
              font.pixelSize: 15
            }
            Text {
              x: 36
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - x - 8
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: group.modelData.title || "Untitled"
              font.family: tv.theme.uiFont
              font.pixelSize: 14
              font.weight: Font.DemiBold
              color: tv.theme.text
            }
            HoverHandler { id: pageHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: tv.view.open(group.modelData.id) }
          }

          // Its blocks with the tag.
          Repeater {
            model: group.modelData.blocks
            delegate: Rectangle {
              id: row
              required property var modelData
              readonly property bool check: modelData.type === "check"
              readonly property bool heading: /^h[123]$/.test(modelData.type)
              objectName: "tagged"
              x: 26 + Math.min(4, modelData.indent) * 18
              width: group.width - x
              height: Math.max(32, words.contentHeight + 12)
              radius: 7
              color: rowHover.hovered ? tv.theme.hover : "transparent"

              // A to-do's box (ticks here), or a list's dot.
              Rectangle {
                id: box
                objectName: "tagCheck"
                visible: row.check
                x: 6
                y: 9
                width: 15
                height: 15
                radius: 4
                color: row.modelData.checked ? tv.theme.accent : "transparent"
                border.width: row.modelData.checked ? 0 : 1.5
                border.color: Qt.alpha(tv.theme.text, 0.45)
                Text {
                  anchors.centerIn: parent
                  visible: row.modelData.checked
                  textFormat: Text.PlainText
                  text: "\u2713"
                  font.pixelSize: 11
                  font.weight: Font.Bold
                  color: tv.theme.background
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                  gesturePolicy: TapHandler.ReleaseWithinBounds
                  onTapped: tv.toggle(group.modelData.id, row.modelData.uid, !row.modelData.checked)
                }
              }
              Text {
                visible: !row.check && (row.modelData.type === "bullet" || row.modelData.type === "number" || row.modelData.type === "toggle")
                x: 9
                y: 6
                textFormat: Text.PlainText
                text: "\u2022"
                font.pixelSize: 15
                color: tv.theme.muted
              }
              Text {
                id: words
                x: 30
                y: 6
                width: parent.width - x - 8
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                text: tv.view ? tv.view.blockHtml(row.modelData.html) : ""
                font.family: tv.view ? tv.view.family : tv.theme.uiFont
                font.pixelSize: row.heading ? 16 : 14
                font.weight: row.heading ? Font.DemiBold : Font.Normal
                font.strikeout: row.check && row.modelData.checked
                color: row.check && row.modelData.checked ? tv.theme.muted : tv.theme.text
                onLinkActivated: function(link) { tv.view.openFromTag(link) }
                HoverHandler { cursorShape: words.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
              }
              HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
              TapHandler {
                onTapped: function(point) {
                  if (words.linkAt(point.position.x - words.x, point.position.y - words.y)) return
                  tv.view.open(group.modelData.id, false, { block: row.modelData.uid })
                }
              }
            }
          }
        }
      }
    }
  }
}
