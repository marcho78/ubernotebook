import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace
import "../Collection.js" as Collection
import "../Dates.js" as Dates
import "../Contacts.js" as Contacts

// The Library (the sidebar's Library): everything put on the pages, newest
// first: links (bookmark cards, and links written in text), files, videos,
// pictures, audio notes, meetings and sketches (Collection.js). Its kinds
// to pick from, words to find a thing by (its name, its link, its page). A
// click on one opens its page, there; Open opens the link or the file in
// its app, and Copy copies a link.
Item {
  id: lv

  property var theme: null
  property var workspace: null
  // DocView: opening pages, the toast.
  property var view: null
  // The kind shown ("" for all) and the words looked for.
  property string kind: ""
  property string query: ""
  // How many are shown (more, a click on "Show more").
  property int limit: 150

  readonly property var all: { var r = workspace ? workspace.revision : 0; return workspace ? Workspace.collected(workspace.index) : [] }
  readonly property var counts: Collection.counts(all)
  readonly property var shown: Collection.filter(all, kind, query)
  readonly property int pageCount: { var by = {}; all.forEach(function(r) { by[r.page] = true }); return Object.keys(by).length }
  onKindChanged: limit = 150
  onQueryChanged: limit = 150

  function focusSearch() { search.focusField() }
  function reset(kindId) { kind = kindId || ""; query = ""; search.text = ""; flick.contentY = 0 }

  function openThing(r) { view.open(r.page, false, { block: r.block }) }
  function canOpen(r) { return r.kind === "link" ? r.url !== "" : r.kind === "email" ? (r.src !== "" || r.url !== "") : r.kind === "person" ? r.person !== "" : r.src !== "" }
  function openOutside(r) {
    if (!workspace || !canOpen(r)) return
    if (r.kind === "person") { view.openPeople(r.person); return }
    // An email kept on a page: its .eml in your mail app; an address: a new
    // one to it; a file: in its app (not a web browser's), a calendar's
    // events and a contact card's people here.
    if (r.src) view.openFileHere(r.src, r.title || r.src)
    else workspace.files.openUrl(r.url)
  }
  function copyLink(r) {
    if (!workspace || !r.url) return
    var what = r.kind === "email" ? r.url.replace(/^mailto:/, "") : r.url
    workspace.files.copyText(what)
    if (view) view.toast(r.kind === "email" ? "Copied " + what : "Copied the link")
  }
  // A person's name and what's under it as People has them now.
  function personOf(r) { var x = workspace ? workspace.contactsRevision : 0; return r.kind === "person" && workspace ? workspace.contactById(r.person) : null }
  function when(r) {
    var d = r.when ? new Date(r.when) : null
    if (!d || isNaN(d.getTime())) return ""
    var now = new Date()
    var label = Dates.SHORT_MONTHS[d.getMonth()] + " " + d.getDate()
    return d.getFullYear() === now.getFullYear() ? label : label + ", " + d.getFullYear()
  }

  Rectangle { anchors.fill: parent; color: lv.theme.background }

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
      y: 48
      width: Math.min(760, flick.width - 48)
      spacing: 14

      // What it is, and how much is in it.
      Column {
        width: parent.width
        spacing: 4
        Text {
          textFormat: Text.PlainText
          text: "Library"
          font.family: lv.theme.uiFont
          font.pixelSize: 28
          font.weight: Font.DemiBold
          color: lv.theme.text
        }
        Text {
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          text: lv.all.length === 0 ? "Everything you put on your pages, in one place."
            : "Everything you put on your pages: " + lv.all.length + (lv.all.length === 1 ? " thing" : " things") + " on " + lv.pageCount + (lv.pageCount === 1 ? " page" : " pages") + "."
          font.family: lv.theme.uiFont
          font.pixelSize: 13
          color: lv.theme.muted
        }
      }

      Field {
        id: search
        objectName: "librarySearch"
        theme: lv.theme
        width: parent.width
        icon: lv.theme.icons.search
        placeholder: "Find by name, link or page"
        visible: lv.all.length > 0
        onEdited: function(text) { lv.query = text }
        onEscaped: { text = ""; lv.query = "" }
      }

      // Its kinds: those there are.
      Flow {
        width: parent.width
        spacing: 6
        visible: lv.all.length > 0
        Chip {
          objectName: "libraryAll"
          theme: lv.theme
          text: "All  " + lv.counts.all
          checked: lv.kind === ""
          onClicked: lv.kind = ""
        }
        Repeater {
          model: Collection.KINDS.filter(function(k) { return lv.counts[k.id] > 0 })
          delegate: Chip {
            required property var modelData
            objectName: "libraryKind"
            readonly property string kindId: modelData.id
            theme: lv.theme
            icon: lv.theme.icons[modelData.icon] || ""
            text: modelData.label + "  " + lv.counts[modelData.id]
            checked: lv.kind === modelData.id
            onClicked: lv.kind = lv.kind === modelData.id ? "" : modelData.id
          }
        }
      }

      Text {
        visible: lv.all.length === 0 || lv.shown.length === 0
        width: parent.width
        topPadding: 8
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: lv.all.length === 0
          ? "Nothing here yet. Bookmarks, links, files, PDFs, videos, pictures, audio notes, meetings, sketches, people and emails (and email addresses) you put on your pages show up here, with the page each one is on."
          : lv.query ? "Nothing matches \u201c" + lv.query + "\u201d" + (lv.kind ? " in " + Collection.kindOf(lv.kind).label.toLowerCase() : "") + "."
          : "Nothing here."
        font.family: lv.theme.uiFont
        font.pixelSize: 14
        color: lv.theme.muted
      }

      // The things: a click opens its page, there.
      Column {
        width: parent.width
        spacing: 2
        Repeater {
          model: lv.shown.slice(0, lv.limit)
          delegate: Rectangle {
            id: row
            required property var modelData
            objectName: "libraryRow"
            readonly property bool hovered: rowHover.hovered
            width: body.width
            height: 58
            radius: 8
            color: hovered ? lv.theme.hover : "transparent"

            // A picture of it (a picture, a video's still, a page's picture),
            // else its icon.
            Rectangle {
              id: thumb
              x: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 42
              height: 42
              radius: 7
              clip: true
              color: Qt.alpha(lv.theme.text, lv.theme.dark ? 0.08 : 0.06)
              Avatar {
                visible: row.modelData.kind === "person" && lv.personOf(row.modelData) !== null
                anchors.centerIn: parent
                theme: lv.theme
                person: lv.personOf(row.modelData)
                size: 34
              }
              Image {
                id: pic
                anchors.fill: parent
                source: row.modelData.thumb && lv.workspace ? lv.workspace.assetUrl(row.modelData.thumb) : ""
                sourceSize.width: 84
                sourceSize.height: 84
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
              }
              Icon {
                anchors.centerIn: parent
                visible: pic.status !== Image.Ready && !(row.modelData.kind === "person" && lv.personOf(row.modelData) !== null)
                theme: lv.theme
                text: lv.theme.icons[Collection.iconOf(row.modelData)] || ""
                size: 19
                color: row.modelData.kind === "link" ? lv.theme.accent : lv.theme.muted
              }
              // A video: a play mark on its still.
              Rectangle {
                visible: row.modelData.kind === "video" && pic.visible
                anchors.centerIn: parent
                width: 20
                height: 20
                radius: 10
                color: Qt.alpha("#000000", 0.55)
                Icon { anchors.centerIn: parent; theme: lv.theme; text: lv.theme.icons.play; size: 12; color: "white" }
              }
            }

            Column {
              x: thumb.x + thumb.width + 12
              anchors.verticalCenter: parent.verticalCenter
              width: tools.x - x - 10
              spacing: 3
              Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: { var p = lv.personOf(row.modelData); return p ? Contacts.nameOf(p) : row.modelData.title }
                font.family: lv.theme.uiFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: lv.theme.text
              }
              Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                readonly property string what: { var p = lv.personOf(row.modelData); return p && Contacts.subtitle(p) ? Contacts.subtitle(p) : Collection.detail(row.modelData) }
                text: (what ? what + "  \u00b7  " : "") + "on " + (row.modelData.pageIcon ? row.modelData.pageIcon + " " : "") + (row.modelData.pageTitle || "Untitled")
                font.family: lv.theme.uiFont
                font.pixelSize: 12
                color: lv.theme.muted
              }
            }

            // When, and (under the pointer) Open and Copy.
            Row {
              id: tools
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2
              Text {
                visible: !row.hovered
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 4
                textFormat: Text.PlainText
                text: lv.when(row.modelData)
                font.family: lv.theme.uiFont
                font.pixelSize: 12
                color: lv.theme.muted
              }
              IconButton {
                objectName: "libraryCopy"
                visible: row.hovered && (row.modelData.kind === "link" || (row.modelData.kind === "email" && row.modelData.url !== ""))
                theme: lv.theme; icon: lv.theme.icons.copy; size: 30; iconSize: 15
                tip: row.modelData.kind === "email" ? "Copy the email" : "Copy the link"
                onClicked: lv.copyLink(row.modelData)
              }
              IconButton {
                objectName: "libraryOpen"
                visible: row.hovered && lv.canOpen(row.modelData)
                theme: lv.theme; icon: row.modelData.kind === "person" ? lv.theme.icons.contacts : row.modelData.kind === "email" ? lv.theme.icons.mail : lv.theme.icons.openExternal; size: 30; iconSize: 15
                tip: row.modelData.kind === "link" ? "Open the link" : row.modelData.kind === "email" ? (row.modelData.src ? "Open it in your mail app" : "Email them") : row.modelData.kind === "person" ? "Open in People" : "Open it in its app"
                onClicked: lv.openOutside(row.modelData)
              }
            }

            HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
              onTapped: function(p) {
                var q = tools.mapFromItem(row, p.position.x, p.position.y)
                if (tools.contains(q)) return
                lv.openThing(row.modelData)
              }
            }
            ToolTip.visible: rowHover.hovered && !tools.contains(tools.mapFromItem(row, rowHover.point.position.x, rowHover.point.position.y))
            ToolTip.delay: 900
            ToolTip.text: row.modelData.url ? row.modelData.url : "Go to it on its page"
          }
        }
      }

      Chip {
        objectName: "libraryMore"
        visible: lv.shown.length > lv.limit
        theme: lv.theme
        text: "Show more (" + (lv.shown.length - lv.limit) + ")"
        onClicked: lv.limit += 150
      }
    }
  }
}
