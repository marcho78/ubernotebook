import QtQuick
import QtQuick.Controls
import "../Contacts.js" as Contacts

// Someone's card on a page in Pages (/contact): who from People, their
// numbers and emails (a click copies one; Email opens your mail app), their
// birthday, address and website. Not picked yet, it asks who: what's typed
// finds them in People (or makes them, with that name). Its tools: Open in
// People (where they're changed), someone else, and its colors (an accent
// and its background, Pages' or your own).
DataCard {
  id: cb
  kind: "contact"

  readonly property var ws: editor ? editor.calendarSource : null
  readonly property var person: { var r = ws ? ws.contactsRevision : 0; return ws && info.contact ? ws.contactById(info.contact) : null }
  readonly property bool picked: info.contact !== ""
  property bool choosing: false
  property string query: ""
  readonly property var found: { var r = ws ? ws.contactsRevision : 0; return ws && (choosing || !picked) ? Contacts.find(ws.contacts, query, 6) : [] }
  function sample() { return person ? Contacts.nameOf(person) : (info.name || "Contact") }
  function focusPick() { choosing = true; Qt.callLater(function() { pick.focusField() }) }
  onLoaded: { if (!picked) query = "" }
  // (Their name kept with the block too, for when they're gone from People.)
  onPersonChanged: if (person && !readOnly && Contacts.nameOf(person) !== info.name) Qt.callLater(function() { if (cb.person && Contacts.nameOf(cb.person) !== cb.info.name) cb.change({ name: Contacts.nameOf(cb.person) }) })

  function choose(c) {
    choosing = false
    query = ""
    change({ contact: c.id, name: Contacts.nameOf(c) })
  }
  function makeNew(name) {
    if (!ws || !name.trim()) return
    var c = { id: Contacts.newId(), name: name.trim(), phones: [], emails: [] }
    ws.saveContact(c)
    choose(ws.contactById(c.id) || c)
    act("openPerson", c.id)
  }

  width: available
  height: card.height

  Rectangle {
    id: card
    width: cb.width
    height: (cb.picked && !cb.choosing ? body.height : chooser.height) + 24
    radius: 10
    color: cb.fill
    border.width: 1
    border.color: Qt.alpha(cb.words, cb.pointerIn ? 0.16 : 0.09)

    // Who: found as it's typed.
    Column {
      id: chooser
      visible: !cb.picked || cb.choosing
      x: 12
      y: 12
      width: parent.width - 24
      spacing: 4
      Row {
        spacing: 10
        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: cb.theme ? cb.theme.icons.person : ""
          font.family: cb.theme ? cb.theme.iconFont : ""
          font.pixelSize: 18
          color: cb.accent
        }
        Field {
          id: pick
          objectName: "contactPick"
          visible: !cb.readOnly
          theme: cb.theme
          width: chooser.width - 30
          height: 34
          placeholder: "Who? A name, an email or a number in People"
          onEdited: function(text) { cb.query = text }
          onAccepted: { if (cb.found.length) cb.choose(cb.found[0]); else if (text.trim()) cb.makeNew(text) }
          onEscaped: { cb.choosing = false; cb.query = "" }
        }
      }
      Text {
        visible: cb.picked && !cb.person && !cb.choosing
        leftPadding: 30
        textFormat: Text.PlainText
        text: (cb.info.name ? cb.info.name + " isn't" : "They aren't") + " in People any more."
        font.family: cb.editor ? cb.editor.uiFamily : ""
        font.pixelSize: 13
        color: cb.faint
      }
      Repeater {
        model: cb.found
        delegate: Rectangle {
          id: hit
          required property var modelData
          objectName: "contactHit"
          width: chooser.width
          height: 40
          radius: 7
          color: hitHover.hovered ? Qt.alpha(cb.words, 0.07) : "transparent"
          Avatar { x: 4; anchors.verticalCenter: parent.verticalCenter; theme: cb.theme; person: hit.modelData; size: 28 }
          Column {
            x: 42
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 8
            Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: Contacts.nameOf(hit.modelData); font.family: cb.editor ? cb.editor.uiFamily : ""; font.pixelSize: 13; color: cb.words }
            Text { visible: text !== ""; width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: Contacts.subtitle(hit.modelData); font.family: cb.editor ? cb.editor.uiFamily : ""; font.pixelSize: 11; color: cb.faint }
          }
          HoverHandler { id: hitHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: cb.choose(hit.modelData) }
        }
      }
      Rectangle {
        objectName: "contactNew"
        visible: cb.query.trim() !== "" && !cb.readOnly
        width: chooser.width
        height: 34
        radius: 7
        color: newHover.hovered ? Qt.alpha(cb.words, 0.07) : "transparent"
        Text {
          x: 12
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "+  New contact \u201c" + cb.query.trim() + "\u201d"
          font.family: cb.editor ? cb.editor.uiFamily : ""
          font.pixelSize: 13
          color: cb.accent
        }
        HoverHandler { id: newHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: cb.makeNew(cb.query) }
      }
    }

    // The card.
    Column {
      id: body
      visible: cb.picked && !cb.choosing && cb.person !== null
      x: 14
      y: 12
      width: parent.width - 28
      spacing: 8
      Row {
        spacing: 12
        Avatar { theme: cb.theme; person: cb.person; size: 44 }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: body.width - 56 - 90
          Text {
            objectName: "contactName"
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: Contacts.nameOf(cb.person)
            font.family: cb.editor ? cb.editor.uiFamily : ""
            font.pixelSize: 17
            font.weight: Font.DemiBold
            color: cb.look.color ? cb.accent : cb.words
          }
          Text {
            visible: text !== ""
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: cb.person && (cb.person.title || cb.person.company) ? Contacts.subtitle(cb.person) : ""
            font.family: cb.editor ? cb.editor.uiFamily : ""
            font.pixelSize: 13
            color: cb.faint
          }
        }
      }
      Column {
        width: body.width
        Repeater {
          model: cb.person ? cb.person.phones.map(function(p) { return { icon: "phone", value: p.value, label: p.label, email: false } })
            .concat(cb.person.emails.map(function(e) { return { icon: "mail", value: e.value, label: e.label, email: true } }))
            .concat(cb.person.birthday ? [{ icon: "cake", value: Contacts.birthdayInfo(cb.person, new Date()).date, label: "birthday", email: false }] : [])
            .concat(cb.person.address ? [{ icon: "place", value: cb.person.address, label: "", email: false }] : [])
            .concat(cb.person.website ? [{ icon: "web", value: cb.person.website, label: "", email: false, web: true }] : []) : []
          delegate: Rectangle {
            id: way
            required property var modelData
            objectName: "contactWay"
            width: body.width
            height: 32
            radius: 6
            color: wayHover.hovered ? Qt.alpha(cb.words, 0.06) : "transparent"
            Text {
              x: 6
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: cb.theme ? cb.theme.icons[way.modelData.icon] : ""
              font.family: cb.theme ? cb.theme.iconFont : ""
              font.pixelSize: 14
              color: cb.accent
            }
            Text {
              x: 30
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - x - 120
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: way.modelData.value
              font.family: cb.editor ? cb.editor.uiFamily : ""
              font.pixelSize: 14
              font.features: { "tnum": 1 }
              color: cb.words
            }
            Text {
              anchors.right: wayTools.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              visible: !wayHover.hovered
              textFormat: Text.PlainText
              text: way.modelData.label
              font.family: cb.editor ? cb.editor.uiFamily : ""
              font.pixelSize: 12
              color: cb.faint
            }
            Row {
              id: wayTools
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: wayHover.hovered
              IconButton {
                visible: way.modelData.email || way.modelData.web === true
                theme: cb.theme; icon: cb.theme ? (way.modelData.email ? cb.theme.icons.mail : cb.theme.icons.openExternal) : ""; size: 26; iconSize: 13; tint: cb.words
                tip: way.modelData.email ? "Email them" : "Open it"
                onClicked: cb.act(way.modelData.email ? "email" : "web", way.modelData.value)
              }
              IconButton {
                objectName: "contactCopy"
                theme: cb.theme; icon: cb.theme ? cb.theme.icons.copy : ""; size: 26; iconSize: 13; tint: cb.words
                tip: "Copy it"
                onClicked: cb.act("copy", way.modelData.value)
              }
            }
            HoverHandler { id: wayHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
              gesturePolicy: TapHandler.ReleaseWithinBounds
              onTapped: function(p) { if (!wayTools.contains(wayTools.mapFromItem(way, p.position.x, p.position.y))) cb.act("copy", way.modelData.value) }
            }
          }
        }
      }
    }

    // Its tools: Open in People, someone else, its colors.
    Row {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 6
      visible: !cb.readOnly && cb.picked && !cb.choosing && (cb.pointerIn || cb.trying !== null)
      IconButton {
        objectName: "contactOpen"
        visible: cb.person !== null
        theme: cb.theme; icon: cb.theme ? cb.theme.icons.contacts : ""; size: 28; iconSize: 14; tint: cb.words
        tip: "Open in People (to change them)"
        onClicked: cb.act("openPerson", cb.info.contact)
      }
      IconButton {
        objectName: "contactChange"
        theme: cb.theme; icon: cb.theme ? cb.theme.icons.swap : ""; size: 28; iconSize: 14; tint: cb.words
        tip: "Someone else"
        onClicked: cb.focusPick()
      }
      IconButton {
        id: paint
        objectName: "contactColors"
        theme: cb.theme; icon: cb.theme ? cb.theme.icons.palette : ""; size: 28; iconSize: 14; tint: cb.words
        tip: "Its colors"
        onClicked: cb.askColors(paint)
      }
    }
  }
}
