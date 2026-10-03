import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace
import "../Templates.js" as Templates

// Templates (the sidebar's foot), in place of a page: yours, then
// Omanote's, each a card with its icon, its name and what it's for, found
// by words in those. A click on one makes a new page from it; Edit opens one of yours, to change it
// like any page (its description is at its top). New template makes an
// empty one; a page's ⋯ menu saves one from a page.
Item {
  id: tv

  property var theme: null
  property var workspace: null
  // DocView: new pages, opening pages.
  property var view: null

  readonly property var mine: { var r = workspace ? workspace.revision : 0; return workspace ? Workspace.templates(workspace.index) : [] }
  readonly property var builtIn: Templates.TEMPLATES.filter(function(t) { return t.id !== "blank" })
  // The words looked for: those with all of them in their name or what they're for.
  property string query: ""
  readonly property var words: query.toLowerCase().split(/\s+/).filter(function(w) { return w })
  readonly property var mineShown: mine.filter(function(t) { return tv.matches(t.title + " " + tv.fill(t.title) + " " + tv.about(t)) })
  readonly property var builtInShown: builtIn.filter(function(t) { return tv.matches(t.label + " " + t.hint) })
  function matches(text) { var hay = String(text).toLowerCase(); return words.every(function(w) { return hay.indexOf(w) >= 0 }) }
  readonly property int columns: Math.max(1, Math.floor((body.width + 12) / 250))
  readonly property real cardWidth: (body.width - (columns - 1) * 12) / columns

  function reset() { flick.contentY = 0; query = ""; search.text = "" }
  function focusSearch() { search.focusField() }
  function fill(text) {
    return Templates.fill(text, false, new Date(), function(d, pattern) { return Qt.formatDate(Templates.parse(d), pattern) })
  }
  // What one of yours is for: its description, else how it starts.
  function about(t) {
    if (t.description) return fill(t.description)
    var words = workspace && workspace.texts[t.id] ? String(workspace.texts[t.id]).trim() : ""
    // (A page's text starts with its title: that's on the card already.)
    if (t.title && words.indexOf(t.title) === 0) words = words.slice(t.title.length)
    return fill(words).replace(/\s+/g, " ").trim().slice(0, 160)
  }
  function inside(id) { var r = workspace ? workspace.revision : 0; return workspace ? Workspace.withDescendants(workspace.index, id).length - 1 : 0 }

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
      y: 48
      width: Math.min(880, flick.width - 48)
      spacing: 14

      Item {
        width: parent.width
        height: heading.height
        Column {
          id: heading
          width: parent.width - newButton.width - 16
          spacing: 4
          Text {
            textFormat: Text.PlainText
            text: "Templates"
            font.family: tv.theme.uiFont
            font.pixelSize: 28
            font.weight: Font.DemiBold
            color: tv.theme.text
          }
          Text {
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: "Pages that start laid out. Click one for a new page from it."
            font.family: tv.theme.uiFont
            font.pixelSize: 13
            color: tv.theme.muted
          }
        }
        IconButton {
          id: newButton
          objectName: "newTemplate"
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: 6
          theme: tv.theme; icon: tv.theme.icons.plus; label: "New template"; size: 30; iconSize: 14
          onClicked: tv.view.newTemplate()
        }
      }

      Field {
        id: search
        objectName: "templateSearch"
        theme: tv.theme
        width: parent.width
        icon: tv.theme.icons.search
        placeholder: "Find a template by its name or what it's for"
        onEdited: function(text) { tv.query = text }
        onEscaped: { text = ""; tv.query = "" }
        // Enter: a new page from the one found first.
        onAccepted: { var t = tv.mineShown[0] ? tv.mineShown[0].id : tv.builtInShown[0] ? tv.builtInShown[0].id : ""; if (t) tv.view.newPageWith(t) }
      }
      Text {
        objectName: "templateNone"
        visible: tv.words.length > 0 && tv.mineShown.length === 0 && tv.builtInShown.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "No template has \u201c" + tv.query.trim() + "\u201d in its name or what it's for."
        font.family: tv.theme.uiFont
        font.pixelSize: 13
        color: tv.theme.muted
      }

      Item { width: 1; height: 6; visible: mineLabel.visible }
      SectionLabel { id: mineLabel; visible: tv.words.length === 0 || tv.mineShown.length > 0; text: "Yours" + (tv.mineShown.length ? "  " + tv.mineShown.length : "") }
      Text {
        visible: tv.mine.length === 0 && tv.words.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "None yet. Make a page the way you want new ones to start, then Save as template in its ⋯ menu; or New template."
        font.family: tv.theme.uiFont
        font.pixelSize: 13
        color: tv.theme.muted
      }
      Grid {
        columns: tv.columns
        columnSpacing: 12
        rowSpacing: 12
        Repeater {
          model: tv.mineShown
          delegate: Card {
            required property var modelData
            templateId: modelData.id
            yours: true
            icon: modelData.icon || "\u{1f4c4}"
            title: tv.fill(modelData.title)
            about: tv.about(modelData)
            meta: { var n = tv.inside(modelData.id); return n > 0 ? n + (n === 1 ? " page" : " pages") + " in it" : "" }
          }
        }
      }

      Item { width: 1; height: 10; visible: builtInLabel.visible }
      SectionLabel { id: builtInLabel; visible: tv.builtInShown.length > 0; text: "Omanote's" + (tv.words.length ? "  " + tv.builtInShown.length : "") }
      Grid {
        columns: tv.columns
        columnSpacing: 12
        rowSpacing: 12
        Repeater {
          model: tv.builtInShown
          delegate: Card {
            required property var modelData
            templateId: modelData.id
            yours: false
            icon: Templates.ICONS[modelData.id] || "\u{1f4c4}"
            title: modelData.label
            about: modelData.hint
          }
        }
      }

      Item { width: 1; height: 6 }
      Text {
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "In a template, {{date}}, {{weekday}}, {{time}}, {{month}}, {{year}} and {{week}} are filled in when it's used."
        font.family: tv.theme.uiFont
        font.pixelSize: 12
        color: tv.theme.faint
      }
    }
  }

  component SectionLabel: Text {
    textFormat: Text.PlainText
    font.family: tv.theme.uiFont
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 0.4
    color: tv.theme.muted
  }

  // A template: its icon, name and what it's for; a click, a new page from it.
  component Card: Rectangle {
    id: card
    property string templateId: ""
    property bool yours: false
    property string icon: ""
    property string title: ""
    property string about: ""
    property string meta: ""
    objectName: "templateCard"
    width: tv.cardWidth
    height: 118
    radius: 10
    color: Qt.alpha(tv.theme.text, cardHover.hovered ? 0.05 : 0.025)
    border.width: 1
    border.color: Qt.alpha(tv.theme.text, cardHover.hovered ? 0.2 : 0.1)

    HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
      onTapped: function(point) {
        // (Edit is its own.)
        if (card.yours && editButton.contains(editButton.mapFromItem(card, point.position.x, point.position.y))) return
        tv.view.newPageWith(card.templateId)
      }
    }

    Text {
      x: 16
      y: 14
      textFormat: Text.PlainText
      text: card.icon
      font.family: "Noto Color Emoji"
      font.pixelSize: 20
    }
    // One of yours: to change it.
    IconButton {
      id: editButton
      objectName: "templateEdit"
      visible: card.yours && cardHover.hovered
      anchors.right: parent.right
      anchors.rightMargin: 8
      y: 8
      theme: tv.theme; icon: tv.theme.icons.edit; label: "Edit"; size: 26; iconSize: 12
      onClicked: tv.view.open(card.templateId)
    }
    Column {
      x: 16
      y: 48
      width: card.width - 32
      spacing: 4
      Text {
        objectName: "templateCardTitle"
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: card.title
        font.family: tv.theme.uiFont
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: tv.theme.text
      }
      Text {
        objectName: "templateCardAbout"
        width: parent.width
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: card.about
        font.family: tv.theme.uiFont
        font.pixelSize: 12
        lineHeight: 1.15
        color: tv.theme.muted
      }
      Text {
        visible: card.meta !== ""
        textFormat: Text.PlainText
        text: card.meta
        font.family: tv.theme.uiFont
        font.pixelSize: 11
        color: tv.theme.faint
      }
    }
  }
}
