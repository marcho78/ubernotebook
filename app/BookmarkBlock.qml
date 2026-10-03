import QtQuick
import QtQuick.Controls
import "../Bookmark.js" as Bookmark

// A link on a page in Pages, as a card: its page's title, a line about it,
// the site, and its picture (fetched once, when it's added, and kept in
// Pages/assets). A click opens the link. Not added yet, it asks for one:
// paste it, Enter. Its tools change the link (the page read again for it),
// fetch it again or copy it; its colors are Pages' or your own.
DataCard {
  id: bk
  kind: "bookmark"

  readonly property bool has: info.url !== ""
  readonly property bool fetching: editor !== null && editor.dataWork[uid] === true
  // Its link being changed (in the field, as it is now).
  property bool editingLink: false
  readonly property bool asking: !has || editingLink
  function sample() { return info.title || "Bookmark" }
  onLoaded: { editingLink = false; if (!has && field) field.text = "" }
  function focusLink() { field.focusField() }
  function editLink() {
    editingLink = true
    field.text = info.url
    Qt.callLater(function() { field.focusField() })
  }
  function stopEditing() { editingLink = false; field.text = "" }

  width: available
  height: card.height

  Rectangle {
    id: card
    width: bk.width
    height: !bk.asking ? Math.max(92, textCol.height + 24) : 54
    radius: 10
    color: bk.fill
    border.width: 1
    border.color: Qt.alpha(bk.words, bk.pointerIn ? 0.16 : 0.09)
    clip: true

    // Not added yet (or changed): the link to paste.
    Row {
      visible: bk.asking
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: bk.theme ? bk.theme.icons.bookmark : ""
        font.family: bk.theme ? bk.theme.iconFont : ""
        font.pixelSize: 18
        color: bk.accent
      }
      Field {
        id: field
        objectName: "bookmarkField"
        anchors.verticalCenter: parent.verticalCenter
        visible: !bk.readOnly && !bk.fetching
        theme: bk.theme
        width: card.width - 60
        height: 34
        placeholder: bk.editingLink ? "The new link, then Enter (Esc keeps it as it is)" : "Paste a link and press Enter (https://...)"
        onAccepted: {
          var u = text.trim()
          if (!u) return
          if (bk.editingLink && u === bk.info.url) { bk.stopEditing(); return }
          bk.act("fetch", { url: u })
        }
        onEscaped: if (bk.editingLink) bk.stopEditing()
        input.onActiveFocusChanged: if (!input.activeFocus && bk.editingLink && !bk.fetching) bk.stopEditing()
      }
      Text {
        visible: bk.fetching || bk.readOnly
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: bk.fetching ? "Getting the page\u2026" : "A bookmark, not added"
        font.family: bk.editor ? bk.editor.uiFamily : ""
        font.pixelSize: 13
        font.italic: true
        color: bk.faint
      }
    }

    // The card.
    Column {
      id: textCol
      visible: !bk.asking
      x: 16
      y: 12
      width: card.width - x - (pic.visible ? pic.width : 0) - 16
      spacing: 4
      Text {
        objectName: "bookmarkTitle"
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: bk.info.title || bk.info.url
        font.family: bk.editor ? bk.editor.uiFamily : ""
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: bk.words
      }
      Text {
        visible: bk.info.description !== ""
        width: parent.width
        maximumLineCount: 2
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: bk.info.description
        font.family: bk.editor ? bk.editor.uiFamily : ""
        font.pixelSize: 12
        color: bk.faint
      }
      Row {
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: bk.theme ? bk.theme.icons.link : ""
          font.family: bk.theme ? bk.theme.iconFont : ""
          font.pixelSize: 12
          color: bk.accent
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, textCol.width - 20)
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: (bk.info.site && bk.info.site !== Bookmark.domain(bk.info.url) ? bk.info.site + "  \u00b7  " : "") + bk.info.url.replace(/^https?:\/\//, "")
          font.family: bk.editor ? bk.editor.uiFamily : ""
          font.pixelSize: 12
          color: bk.look.color ? bk.accent : bk.faint
        }
      }
    }
    Image {
      id: pic
      visible: bk.has && bk.info.image !== "" && status !== Image.Error
      anchors.right: parent.right
      width: Math.min(220, card.width * 0.3)
      height: card.height
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      source: bk.has && bk.info.image && bk.editor ? bk.editor.assetUrl(bk.info.image) : ""
    }
    HoverHandler { cursorShape: !bk.asking ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler {
      enabled: !bk.asking
      onTapped: function(p) {
        var q = tools.mapFromItem(card, p.position.x, p.position.y)
        if (tools.visible && tools.contains(q)) return
        bk.act("open", null)
      }
    }
    Row {
      id: tools
      visible: !bk.asking && !bk.readOnly && (bk.pointerIn || bk.trying !== null)
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 6
      spacing: 2
      Rectangle {
        width: toolRow.implicitWidth + 4
        height: 32
        radius: 8
        color: bk.editor ? bk.editor.paper : "white"
        border.width: 1
        border.color: Qt.alpha(bk.ink, 0.12)
        Row {
          id: toolRow
          x: 2
          anchors.verticalCenter: parent.verticalCenter
          IconButton { objectName: "bookmarkEdit"; theme: bk.theme; icon: bk.theme ? bk.theme.icons.edit : ""; size: 28; iconSize: 14; tint: bk.ink; tip: "Change the link"; onClicked: bk.editLink() }
          IconButton { objectName: "bookmarkRefresh"; theme: bk.theme; icon: bk.theme ? bk.theme.icons.refresh : ""; size: 28; iconSize: 14; tint: bk.ink; tip: "Get the page again"; onClicked: bk.act("fetch", { url: bk.info.url }) }
          IconButton { objectName: "bookmarkCopy"; theme: bk.theme; icon: bk.theme ? bk.theme.icons.copy : ""; size: 28; iconSize: 14; tint: bk.ink; tip: "Copy the link"; onClicked: bk.act("copy", null) }
          IconButton { id: colorButton; objectName: "bookmarkColors"; theme: bk.theme; icon: bk.theme ? bk.theme.icons.palette : ""; size: 28; iconSize: 14; tint: bk.ink; tip: "Its colors"; onClicked: bk.askColors(colorButton) }
        }
      }
    }
  }
}
