import QtQuick
import QtQuick.Controls
import "../Contacts.js" as Contacts
import "../Workspace.js" as Workspace

// People (the sidebar's People): everyone in Pages/contacts.json, A to Z,
// found by what's typed (a name, a company, an email, a number). As a list
// beside the one picked, or as cards (the header switches; it's kept). The
// one picked is a card: their name and what they do, then each number and
// email with what it is (a click copies it; Email opens your mail app),
// their birthday, address, website, notes, and the pages they're named on.
// Edit turns the card into a form (each field named above it; Save keeps it
// as one step, Cancel leaves it as it was); New person opens it empty.
// Import takes a .vcf (a phone, Google, iCloud, Outlook) or a .csv and fills
// in those already here rather than adding them twice; ⋯ exports everyone.
// Delete is taken back with Undo.
Item {
  id: pv

  property var theme: null
  property var workspace: null
  // DocView: opening pages, the toast, picking a file, settings.
  property var view: null

  property string selected: ""
  property string query: ""
  // The form: someone's copy while it's written in (a new person's too).
  property bool editing: false
  property bool isNew: false
  property var draft: null
  property var errors: ({})
  // The name as it's typed in the form (the card's heading follows it).
  property string draftName: ""
  // (The form's rows, to put the cursor in one just added.)
  property var phoneRows: null
  property var emailRows: null

  // A list beside the one picked, or cards (kept in Settings).
  readonly property string savedLayout: view && view.settings && view.settings.peopleLayout === "cards" ? "cards" : "list"
  property string layoutMode: savedLayout
  function setLayout(l) {
    layoutMode = l
    if (view && view.service) view.service.setSetting("peopleLayout", l)
  }

  readonly property var all: { var r = workspace ? workspace.contactsRevision : 0; return workspace ? Contacts.sorted(workspace.contacts) : [] }
  readonly property var shown: { var r = workspace ? workspace.contactsRevision : 0; return workspace ? Contacts.find(workspace.contacts, query) : [] }
  readonly property var person: { var r = workspace ? workspace.contactsRevision : 0; return workspace && selected ? workspace.contactById(selected) : null }
  readonly property bool showingPerson: editing || person !== null
  readonly property bool twoPane: layoutMode === "list" && width >= 820
  readonly property var bday: Contacts.birthdayInfo(person, new Date())

  // Where it all goes across.
  readonly property real contentW: Math.min(1120, width - 48)
  readonly property real leftX: Math.max(24, (width - contentW) / 2)
  readonly property bool headerShown: twoPane || !showingPerson

  // Where they're named: [{ page, pageTitle, pageIcon, block }].
  readonly property var namedOn: {
    var r = workspace ? workspace.revision : 0
    if (!workspace || !selected) return []
    var seen = {}
    return Workspace.collected(workspace.index).filter(function(x) {
      if (x.kind !== "person" || x.person !== pv.selected || seen[x.page]) return false
      seen[x.page] = true
      return true
    })
  }

  // ---- going about ---------------------------------------------------------------------------

  function show(id) {
    editing = false
    isNew = false
    draft = null
    errors = ({})
    selected = id || ""
    detailFlick.contentY = 0
    if (!id) Qt.callLater(function() { search.focusField() })
    else pv.forceActiveFocus()
  }
  function focusSearch() { search.focusField() }

  function copy(o) { return JSON.parse(JSON.stringify(o)) }

  function newPerson() {
    selected = ""
    isNew = true
    draft = { id: Contacts.newId(), name: "", company: "", title: "", phones: [{ label: "mobile", value: "" }], emails: [{ label: "work", value: "" }], birthday: "", address: "", website: "", notes: "" }
    draftName = ""
    errors = ({})
    editing = true
    detailFlick.contentY = 0
    Qt.callLater(function() { formName.input.forceActiveFocus() })
  }
  function startEdit() {
    if (!person) return
    var d = copy(person)
    if (!d.phones.length) d.phones.push({ label: "mobile", value: "" })
    if (!d.emails.length) d.emails.push({ label: "work", value: "" })
    draft = d
    draftName = d.name
    errors = ({})
    isNew = false
    editing = true
    Qt.callLater(function() { formName.input.forceActiveFocus() })
  }
  function cancelEdit() {
    if (isNew) { show(""); return }
    editing = false
    draft = null
    errors = ({})
    pv.forceActiveFocus()
  }

  // The form, checked: what's wrong is said under its field; else it's kept.
  function save() {
    if (!draft || !workspace) return
    var d = copy(draft)
    var errs = {}
    d.name = d.name.trim()
    d.phones = d.phones.filter(function(p) { return String(p.value).trim() })
    d.emails = d.emails.filter(function(e) { return String(e.value).trim() })
    draft.phones.forEach(function(p, i) { if (String(p.value).trim() && !Contacts.cleanPhone(p.value)) errs["phone" + i] = "That isn't a phone number (digits, spaces, + ( ) - .)" })
    draft.emails.forEach(function(e, i) { if (String(e.value).trim() && !Contacts.cleanEmail(e.value)) errs["email" + i] = "That isn't an email (like name@example.com)" })
    if (d.birthday.trim() && !Contacts.cleanBirthday(d.birthday.trim())) errs.birthday = "A date like 1990-04-12, or --04-12 without the year"
    if (d.website.trim() && !Contacts.cleanWebsite(d.website.trim())) errs.website = "A link like https://example.com"
    if (!d.name && !d.phones.length && !d.emails.length && !d.company.trim()) errs.name = "Give them a name (or a number, an email, a company)"
    if (Object.keys(errs).length) { errors = errs; return }
    d.birthday = Contacts.cleanBirthday(d.birthday.trim())
    d.website = Contacts.cleanWebsite(d.website.trim())
    workspace.saveContact(d)
    var made = isNew
    editing = false
    isNew = false
    draft = null
    errors = ({})
    selected = d.id
    pv.forceActiveFocus()
    if (made && workspace.contactById(d.id)) view.toast("Added " + Contacts.nameOf(workspace.contactById(d.id)))
  }

  // The form's fields as they're typed (the copy's changed in place, so
  // nothing's drawn again under the cursor); a row added or taken off, or a
  // label picked, draws it again.
  function setField(field, value) {
    if (!draft) return
    draft[field] = value
    if (field === "name") draftName = value
  }
  function setRow(list, i, value) { if (draft && draft[list][i]) draft[list][i].value = value }
  function relabel(list, i, label) { var d = copy(draft); d[list][i].label = label; draft = d }
  function addRow(list) {
    var d = copy(draft)
    d[list].push({ label: list === "phones" ? "mobile" : "work", value: "" })
    draft = d
    var at = d[list].length - 1
    Qt.callLater(function() {
      var rows = list === "phones" ? pv.phoneRows : pv.emailRows
      var it = rows ? rows.itemAt(at) : null
      if (it) it.focusValue()
    })
  }
  function removeRow(list, i) { var d = copy(draft); d[list].splice(i, 1); draft = d }

  function remove() {
    if (!person || !workspace) return
    var name = Contacts.nameOf(person)
    workspace.setContacts(Contacts.without(workspace.contacts, person.id))
    show("")
    view.toastUndo("Deleted " + name, function() { pv.workspace.undoContacts() })
  }

  function importFile() { view.pickContacts(null) }

  focus: true
  Keys.onPressed: function(e) {
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    if (pv.editing && ctrl && (e.key === Qt.Key_S || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { e.accepted = true; pv.save() }
    else if (pv.editing && e.key === Qt.Key_Escape) { e.accepted = true; pv.cancelEdit() }
    else if (!pv.editing && pv.person && e.key === Qt.Key_Escape) { e.accepted = true; pv.show("") }
  }

  Rectangle { anchors.fill: parent; color: pv.theme.background }

  // A .vcf or a .csv dropped here: its people, put in.
  DropArea {
    anchors.fill: parent
    onEntered: function(drag) { drag.accepted = drag.hasUrls }
    onDropped: function(drop) {
      for (var i = 0; i < drop.urls.length && i < 10; i++) {
        var path = decodeURIComponent(String(drop.urls[i]).replace(/^file:\/\//, ""))
        if (/\.(vcf|vcard|csv)$/i.test(path)) pv.view.importContactsFrom(path)
      }
    }
  }

  // ---- pieces --------------------------------------------------------------------------------

  // A button with words: outlined; the main one in the page's ink.
  component Button_: Rectangle {
    id: btn
    property string text: ""
    property string icon: ""
    property bool primary: false
    signal clicked()
    implicitWidth: btnRow.implicitWidth + 24
    implicitHeight: 32
    radius: 8
    color: primary ? (btnTap.pressed ? Qt.alpha(pv.theme.text, 0.75) : btnHover.hovered ? Qt.alpha(pv.theme.text, 0.86) : pv.theme.text)
      : btnTap.pressed ? pv.theme.pressed : btnHover.hovered ? pv.theme.hover : "transparent"
    border.width: primary ? 0 : 1
    border.color: pv.theme.line
    Row {
      id: btnRow
      anchors.centerIn: parent
      spacing: 6
      Text {
        visible: btn.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: btn.icon
        font.family: pv.theme.iconFont
        font.pixelSize: 14
        color: btn.primary ? pv.theme.background : pv.theme.text
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: btn.text
        font.family: pv.theme.uiFont
        font.pixelSize: 13
        font.weight: Font.Medium
        color: btn.primary ? pv.theme.background : pv.theme.text
      }
    }
    HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: btnTap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: btn.clicked() }
  }

  // A thin line between parts of the card.
  component Rule: Rectangle { height: 1; color: pv.theme.line }

  // A part of the card's name.
  component GroupTitle: Text {
    topPadding: 18
    bottomPadding: 6
    textFormat: Text.PlainText
    font.family: pv.theme.uiFont
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 0.5
    font.capitalization: Font.AllUppercase
    color: pv.theme.muted
  }

  // A line of the card: what it is, it (and a line under it); a click copies
  // it; Copy (and Email, Open) under the pointer.
  component InfoRow: Rectangle {
    id: row
    property string key: ""
    property string value: ""
    property string sub: ""
    property bool mail: false
    property string link: ""
    width: parent ? parent.width : 300
    height: Math.max(40, valueCol.height + 14)
    radius: 8
    color: rowHover.hovered ? pv.theme.hover : "transparent"
    Text {
      x: 10
      y: 12
      width: 100
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: row.key
      font.family: pv.theme.uiFont
      font.pixelSize: 13
      color: pv.theme.muted
    }
    Column {
      id: valueCol
      x: 118
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - x - rowTools.width - 10
      spacing: 1
      Text {
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: row.value
        font.family: pv.theme.uiFont
        font.pixelSize: 14
        font.features: { "tnum": 1 }
        color: pv.theme.text
      }
      Text {
        visible: row.sub !== ""
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: row.sub
        font.family: pv.theme.uiFont
        font.pixelSize: 12
        color: pv.theme.muted
      }
    }
    Row {
      id: rowTools
      anchors.right: parent.right
      anchors.rightMargin: 4
      anchors.verticalCenter: parent.verticalCenter
      opacity: rowHover.hovered ? 1 : 0
      IconButton {
        visible: row.mail
        objectName: "personMail"
        theme: pv.theme; icon: pv.theme.icons.mail; size: 30; iconSize: 14; tip: "Email them"
        onClicked: pv.view.mailTo(row.value)
      }
      IconButton {
        visible: row.link !== ""
        theme: pv.theme; icon: pv.theme.icons.openExternal; size: 30; iconSize: 14; tip: "Open it"
        onClicked: pv.workspace.files.openUrl(row.link)
      }
      IconButton {
        objectName: "personCopy"
        theme: pv.theme; icon: pv.theme.icons.copy; size: 30; iconSize: 14; tip: "Copy it"
        onClicked: pv.view.copyText(row.value)
      }
    }
    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: function(p) { if (!rowTools.contains(rowTools.mapFromItem(row, p.position.x, p.position.y))) pv.view.copyText(row.value) }
    }
  }

  // A field in the form: its name above it, what's wrong under it.
  component FormField: Column {
    id: ff
    property string label: ""
    property alias input: fin
    property string text: ""
    property string placeholder: ""
    property string error: ""
    signal edited(string value)
    spacing: 6
    Text {
      visible: ff.label !== ""
      textFormat: Text.PlainText
      text: ff.label
      font.family: pv.theme.uiFont
      font.pixelSize: 12
      font.weight: Font.Medium
      color: pv.theme.muted
    }
    Rectangle {
      width: ff.width
      height: 38
      radius: 8
      color: pv.theme.background
      border.width: 1
      border.color: ff.error ? pv.theme.urgent : fin.activeFocus ? Qt.alpha(pv.theme.accent, 0.9) : pv.theme.line
      TextInput {
        id: fin
        x: 11
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 22
        clip: true
        selectByMouse: true
        text: ff.text
        font.family: pv.theme.uiFont
        font.pixelSize: 14
        color: pv.theme.text
        selectionColor: Qt.alpha(pv.theme.accent, 0.35)
        selectedTextColor: pv.theme.text
        onTextEdited: ff.edited(text)
        Text {
          visible: fin.text === ""
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: ff.placeholder
          font: fin.font
          color: pv.theme.faint
        }
      }
      HoverHandler { cursorShape: Qt.IBeamCursor }
    }
    Text {
      visible: ff.error !== ""
      width: ff.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: ff.error
      font.family: pv.theme.uiFont
      font.pixelSize: 12
      color: pv.theme.urgent
    }
  }

  // ---- the top: People, how many, how they're shown, Import, New ---------------------------------

  Item {
    id: head
    visible: pv.headerShown
    x: pv.leftX
    y: 20
    width: pv.contentW
    height: 44
    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "People"
        font.family: pv.theme.uiFont
        font.pixelSize: 24
        font.weight: Font.DemiBold
        color: pv.theme.text
      }
      Text {
        id: countText
        objectName: "peopleCount"
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 3
        textFormat: Text.PlainText
        text: pv.all.length === 0 ? "" : pv.query ? pv.shown.length + " of " + pv.all.length : String(pv.all.length)
        font.family: pv.theme.uiFont
        font.pixelSize: 14
        color: pv.theme.muted
      }
    }
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8
      // List or cards.
      Rectangle {
        visible: pv.all.length > 0
        anchors.verticalCenter: parent.verticalCenter
        width: layoutRow.width + 4
        height: 32
        radius: 8
        color: "transparent"
        border.width: 1
        border.color: pv.theme.line
        Row {
          id: layoutRow
          anchors.centerIn: parent
          Repeater {
            model: [{ id: "list", icon: "bullets", tip: "As a list" }, { id: "cards", icon: "grid", tip: "As cards" }]
            delegate: Rectangle {
              id: seg
              required property var modelData
              readonly property bool on: pv.layoutMode === modelData.id
              objectName: modelData.id === "list" ? "peopleLayoutList" : "peopleLayoutCards"
              width: 28
              height: 26
              radius: 6
              color: seg.on ? pv.theme.pressed : segHover.hovered ? pv.theme.hover : "transparent"
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: pv.theme.icons[seg.modelData.icon]
                font.family: pv.theme.iconFont
                font.pixelSize: 14
                color: seg.on ? pv.theme.text : pv.theme.muted
              }
              HoverHandler { id: segHover; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: pv.setLayout(seg.modelData.id) }
              ToolTip.visible: segHover.hovered
              ToolTip.delay: 600
              ToolTip.text: seg.modelData.tip
            }
          }
        }
      }
      Button_ {
        objectName: "peopleImport"
        anchors.verticalCenter: parent.verticalCenter
        text: "Import"
        onClicked: pv.importFile()
      }
      Button_ {
        objectName: "peopleNew"
        anchors.verticalCenter: parent.verticalCenter
        icon: pv.theme.icons.plus
        text: "New person"
        onClicked: pv.newPerson()
      }
      IconButton {
        id: moreButton
        objectName: "peopleMore"
        anchors.verticalCenter: parent.verticalCenter
        theme: pv.theme; icon: pv.theme.icons.more; size: 32; iconSize: 15
        tip: "Export, undo"
        onClicked: peopleMenu.open()
        Pop {
          id: peopleMenu
          theme: pv.theme
          focus: false
          width: 250
          x: moreButton.width - width
          y: moreButton.height + 6
          contentItem: Column {
            spacing: 2
            MenuRow { width: parent.width; theme: pv.theme; icon: pv.theme.icons.export; text: "Import contacts\u2026"; hint: ".vcf or .csv"; onClicked: { peopleMenu.close(); pv.importFile() } }
            MenuRow { objectName: "peopleExport"; width: parent.width; theme: pv.theme; icon: pv.theme.icons.export; text: "Export everyone\u2026"; hint: "as a .vcf"; active: pv.all.length > 0; onClicked: { peopleMenu.close(); pv.view.exportContacts() } }
            MenuRow { width: parent.width; theme: pv.theme; icon: pv.theme.icons.undo; text: "Undo"; active: pv.workspace && pv.workspace.contactsUndo.length > 0; onClicked: { peopleMenu.close(); pv.workspace.undoContacts() } }
          }
        }
      }
    }
  }

  // No one yet: what to do.
  Column {
    objectName: "peopleEmpty"
    visible: pv.all.length === 0 && !pv.editing
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.max(140, pv.height * 0.28)
    width: Math.min(420, pv.width - 48)
    spacing: 10
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      textFormat: Text.PlainText
      text: "No one here yet"
      font.family: pv.theme.uiFont
      font.pixelSize: 17
      font.weight: Font.DemiBold
      color: pv.theme.text
    }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: "Import contacts from your phone, Google, iCloud or Outlook (a .vcf or .csv, or drop the file here), or add someone. Then type @ and their name on any page."
      font.family: pv.theme.uiFont
      font.pixelSize: 13
      lineHeight: 1.25
      color: pv.theme.muted
    }
    Item { width: 1; height: 4 }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 8
      Button_ { text: "Import contacts"; onClicked: pv.importFile() }
      Button_ { primary: true; icon: pv.theme.icons.plus; text: "New person"; onClicked: pv.newPerson() }
    }
  }

  // ---- as a list -------------------------------------------------------------------------------

  Item {
    id: listSide
    visible: pv.all.length > 0 && pv.layoutMode === "list" && (pv.twoPane || !pv.showingPerson)
    x: pv.leftX
    y: head.y + head.height + 14
    width: pv.twoPane ? 300 : pv.contentW
    height: pv.height - y

    Field {
      id: search
      objectName: "peopleSearch"
      theme: pv.theme
      width: parent.width
      height: 36
      icon: pv.theme.icons.search
      placeholder: "Search people"
      onEdited: function(text) { pv.query = text }
      onEscaped: { text = ""; pv.query = "" }
      onAccepted: if (pv.shown.length) pv.show(pv.shown[0].id)
    }

    ListView {
      id: list
      objectName: "peopleList"
      y: search.height + 10
      width: parent.width
      height: parent.height - y
      clip: true
      spacing: 1
      boundsBehavior: Flickable.StopAtBounds
      model: pv.layoutMode === "list" ? pv.shown : []
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: Rectangle {
        id: lrow
        required property var modelData
        objectName: "personRow"
        width: list.width
        height: 52
        radius: 8
        color: pv.selected === modelData.id ? pv.theme.pressed : lrowHover.hovered ? pv.theme.hover : "transparent"
        Avatar { x: 8; anchors.verticalCenter: parent.verticalCenter; theme: pv.theme; person: lrow.modelData; size: 34 }
        Column {
          x: 52
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - 10
          spacing: 1
          Text {
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: Contacts.nameOf(lrow.modelData)
            font.family: pv.theme.uiFont
            font.pixelSize: 14
            font.weight: Font.Medium
            color: pv.theme.text
          }
          Text {
            visible: text !== ""
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: Contacts.subtitle(lrow.modelData)
            font.family: pv.theme.uiFont
            font.pixelSize: 12
            color: pv.theme.muted
          }
        }
        HoverHandler { id: lrowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: pv.show(lrow.modelData.id) }
      }
      Text {
        visible: list.count === 0 && pv.query !== ""
        width: list.width
        topPadding: 12
        leftPadding: 8
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "No one matches \u201c" + pv.query + "\u201d."
        font.family: pv.theme.uiFont
        font.pixelSize: 13
        color: pv.theme.muted
      }
    }
  }

  // ---- as cards --------------------------------------------------------------------------------

  Item {
    id: cardsSide
    visible: pv.all.length > 0 && pv.layoutMode === "cards" && !pv.showingPerson
    x: pv.leftX
    y: head.y + head.height + 14
    width: pv.contentW
    height: pv.height - y

    Field {
      id: cardSearch
      objectName: "peopleCardSearch"
      theme: pv.theme
      width: Math.min(420, parent.width)
      height: 36
      icon: pv.theme.icons.search
      placeholder: "Search people"
      text: pv.query
      onEdited: function(text) { pv.query = text }
      onEscaped: { text = ""; pv.query = "" }
      onAccepted: if (pv.shown.length) pv.show(pv.shown[0].id)
    }

    GridView {
      id: grid
      objectName: "peopleGrid"
      y: cardSearch.height + 14
      width: parent.width + 12
      height: parent.height - y
      clip: true
      readonly property int cols: Math.max(1, Math.floor(width / 272))
      cellWidth: Math.floor(width / cols)
      cellHeight: 104
      boundsBehavior: Flickable.StopAtBounds
      model: pv.layoutMode === "cards" ? pv.shown : []
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: Item {
        id: cell
        required property var modelData
        readonly property string reach: modelData.phones.length ? modelData.phones[0].value : modelData.emails.length ? modelData.emails[0].value : ""
        objectName: "personCard"
        width: grid.cellWidth
        height: grid.cellHeight
        Rectangle {
          id: card
          width: parent.width - 12
          height: parent.height - 12
          radius: 10
          color: cardHover.hovered ? pv.theme.surfaceHigh : pv.theme.surface
          border.width: 1
          border.color: cardHover.hovered ? Qt.alpha(pv.theme.text, 0.22) : pv.theme.line
          Behavior on color { ColorAnimation { duration: 90 } }
          Avatar { x: 14; anchors.verticalCenter: parent.verticalCenter; theme: pv.theme; person: cell.modelData; size: 42 }
          Column {
            x: 68
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 14
            spacing: 2
            Text {
              width: parent.width
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: Contacts.nameOf(cell.modelData)
              font.family: pv.theme.uiFont
              font.pixelSize: 14
              font.weight: Font.Medium
              color: pv.theme.text
            }
            Text {
              visible: text !== ""
              width: parent.width
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: cell.modelData.title && cell.modelData.company ? cell.modelData.title + ", " + cell.modelData.company : cell.modelData.company || cell.modelData.title
              font.family: pv.theme.uiFont
              font.pixelSize: 12
              color: pv.theme.muted
            }
            Text {
              visible: cell.reach !== ""
              width: parent.width
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: cell.reach
              font.family: pv.theme.uiFont
              font.pixelSize: 12
              font.features: { "tnum": 1 }
              color: pv.theme.muted
            }
          }
          HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: pv.show(cell.modelData.id) }
        }
      }
      Text {
        visible: grid.count === 0 && pv.query !== ""
        topPadding: 12
        textFormat: Text.PlainText
        text: "No one matches \u201c" + pv.query + "\u201d."
        font.family: pv.theme.uiFont
        font.pixelSize: 13
        color: pv.theme.muted
      }
    }
  }

  // ---- the one picked: a card ------------------------------------------------------------------

  Flickable {
    id: detailFlick
    visible: pv.showingPerson || (pv.twoPane && pv.all.length > 0)
    x: pv.twoPane ? listSide.x + listSide.width + 28 : 0
    y: pv.twoPane ? listSide.y : 0
    width: pv.twoPane ? pv.leftX + pv.contentW - x : pv.width
    height: pv.height - y
    contentHeight: detail.y + detail.height + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Text {
      visible: !pv.showingPerson
      x: 4
      y: 10
      textFormat: Text.PlainText
      text: "Pick someone to see their card."
      font.family: pv.theme.uiFont
      font.pixelSize: 13
      color: pv.theme.faint
    }

    Column {
      id: detail
      visible: pv.showingPerson
      // (Clear of the scroll bar at the right.)
      x: pv.twoPane ? 0 : Math.max(24, (detailFlick.width - width) / 2)
      y: pv.twoPane ? 0 : 20
      width: pv.twoPane ? Math.min(680, detailFlick.width - 14) : Math.min(680, detailFlick.width - 48)
      spacing: 14

      Chip {
        objectName: "peopleBack"
        visible: !pv.twoPane
        theme: pv.theme
        icon: pv.theme.icons.left
        text: "People"
        onClicked: pv.editing && !pv.isNew ? pv.cancelEdit() : pv.show("")
      }

      Rectangle {
        id: card
        objectName: "personCard_"
        width: parent.width
        height: cardCol.height + 44
        radius: 12
        color: pv.theme.surface
        border.width: 1
        border.color: pv.theme.line

        Column {
          id: cardCol
          x: 24
          y: 22
          width: card.width - 48
          spacing: 0

          // Who: their face, name and what they do; Edit (or Cancel, Save).
          Item {
            width: parent.width
            height: 60
            Avatar {
              anchors.verticalCenter: parent.verticalCenter
              theme: pv.theme
              person: pv.editing ? { name: pv.draftName, emails: [], phones: [], company: "" } : pv.person
              size: 56
            }
            Column {
              x: 72
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - x - actions.width - 12
              spacing: 2
              Text {
                objectName: "personHeading"
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: pv.editing ? (pv.draftName.trim() || (pv.isNew ? "New person" : "No name")) : Contacts.nameOf(pv.person)
                font.family: pv.theme.uiFont
                font.pixelSize: 20
                font.weight: Font.DemiBold
                color: pv.theme.text
              }
              Text {
                visible: text !== ""
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: pv.editing ? (pv.isNew ? "Fill in what you know. Ctrl+S saves, Esc cancels." : "Ctrl+S saves, Esc cancels.")
                  : pv.person ? (pv.person.title && pv.person.company ? pv.person.title + " at " + pv.person.company : pv.person.company || pv.person.title) : ""
                font.family: pv.theme.uiFont
                font.pixelSize: 13
                color: pv.theme.muted
              }
            }
            Row {
              id: actions
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6
              Button_ { objectName: "personEdit"; visible: !pv.editing; text: "Edit"; onClicked: pv.startEdit() }
              IconButton {
                id: personMore
                objectName: "personMore"
                visible: !pv.editing
                anchors.verticalCenter: parent.verticalCenter
                theme: pv.theme; icon: pv.theme.icons.more; size: 32; iconSize: 15
                tip: "Delete"
                onClicked: personMenu.open()
                Pop {
                  id: personMenu
                  theme: pv.theme
                  focus: false
                  width: 260
                  x: personMore.width - width
                  y: personMore.height + 6
                  contentItem: Column {
                    MenuRow { objectName: "personDelete"; width: parent.width; theme: pv.theme; icon: pv.theme.icons.trash; text: "Delete " + (pv.person ? Contacts.nameOf(pv.person) : ""); hint: "Undo puts them back"; danger: true; onClicked: { personMenu.close(); pv.remove() } }
                  }
                }
              }
              Button_ { objectName: "personCancel"; visible: pv.editing; text: "Cancel"; onClicked: pv.cancelEdit() }
              Button_ { objectName: "personSave"; visible: pv.editing; primary: true; text: pv.isNew ? "Add person" : "Save"; onClicked: pv.save() }
            }
          }

          // ---- reading ----

          Column {
            id: reading
            visible: !pv.editing && pv.person !== null
            width: parent.width
            readonly property var c: pv.person

            Item { width: 1; height: 16 }
            Rule { width: parent.width }

            GroupTitle { text: "Contact" }
            Repeater {
              model: reading.c ? reading.c.phones : []
              delegate: InfoRow { required property var modelData; objectName: "personPhone"; key: modelData.label; value: modelData.value }
            }
            Repeater {
              model: reading.c ? reading.c.emails : []
              delegate: InfoRow { required property var modelData; objectName: "personEmail"; key: modelData.label; value: modelData.value; mail: true }
            }
            Text {
              visible: reading.c !== null && reading.c.phones.length + reading.c.emails.length === 0
              leftPadding: 10
              bottomPadding: 6
              textFormat: Text.PlainText
              text: "No number or email yet."
              font.family: pv.theme.uiFont
              font.pixelSize: 13
              color: pv.theme.faint
            }

            Column {
              visible: reading.c !== null && (reading.c.birthday !== "" || reading.c.address !== "" || reading.c.website !== "")
              width: parent.width
              Rule { width: parent.width }
              GroupTitle { text: "Details" }
              InfoRow {
                visible: pv.bday !== null
                key: "birthday"
                value: pv.bday ? pv.bday.date : ""
                sub: pv.bday ? (pv.bday.turns ? "Turns " + pv.bday.turns + " " + pv.bday.next : "Birthday " + pv.bday.next) : ""
              }
              InfoRow { visible: reading.c !== null && reading.c.address !== ""; key: "address"; value: reading.c ? reading.c.address : "" }
              InfoRow { visible: reading.c !== null && reading.c.website !== ""; key: "website"; value: reading.c ? reading.c.website.replace(/^https?:\/\//, "") : ""; link: reading.c ? reading.c.website : "" }
            }

            Column {
              visible: reading.c !== null && reading.c.notes !== ""
              width: parent.width
              Rule { width: parent.width }
              GroupTitle { text: "Notes" }
              Text {
                objectName: "personNotes"
                width: parent.width
                leftPadding: 10
                rightPadding: 10
                bottomPadding: 4
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: reading.c ? reading.c.notes : ""
                font.family: pv.theme.uiFont
                font.pixelSize: 14
                lineHeight: 1.3
                color: pv.theme.text
              }
            }

            Rule { width: parent.width }
            GroupTitle { text: "On your pages" }
            Text {
              visible: pv.namedOn.length === 0
              leftPadding: 10
              textFormat: Text.PlainText
              text: "Not named on a page yet. Type @ and their name on one."
              font.family: pv.theme.uiFont
              font.pixelSize: 13
              color: pv.theme.faint
            }
            Repeater {
              model: pv.namedOn
              delegate: Rectangle {
                id: on
                required property var modelData
                objectName: "personPage"
                width: reading.width
                height: 38
                radius: 8
                color: onHover.hovered ? pv.theme.hover : "transparent"
                Text {
                  x: 10
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 40
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: (on.modelData.pageIcon ? on.modelData.pageIcon + "  " : "") + (on.modelData.pageTitle || "Untitled")
                  font.family: pv.theme.uiFont
                  font.pixelSize: 14
                  color: pv.theme.text
                }
                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: 10
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: pv.theme.icons.right
                  font.family: pv.theme.iconFont
                  font.pixelSize: 12
                  color: pv.theme.faint
                }
                HoverHandler { id: onHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: pv.view.open(on.modelData.page, false, { block: on.modelData.block }) }
              }
            }
          }

          // ---- the form ----

          Column {
            id: form
            objectName: "personForm"
            visible: pv.editing && pv.draft !== null
            width: parent.width
            spacing: 16
            readonly property real half: (width - 12) / 2

            Item { width: 1; height: 2 }
            Rule { width: parent.width }

            FormField {
              id: formName
              objectName: "formName"
              width: parent.width
              label: "Name"
              placeholder: "e.g. Sam Rivera"
              text: pv.draft ? pv.draft.name : ""
              error: pv.errors.name || ""
              onEdited: function(v) { pv.setField("name", v) }
            }
            Row {
              spacing: 12
              FormField {
                objectName: "formTitle"
                width: form.half
                label: "Job title"
                placeholder: "e.g. Designer"
                text: pv.draft ? pv.draft.title : ""
                onEdited: function(v) { pv.setField("title", v) }
              }
              FormField {
                objectName: "formCompany"
                width: form.half
                label: "Company"
                placeholder: "e.g. Acme"
                text: pv.draft ? pv.draft.company : ""
                onEdited: function(v) { pv.setField("company", v) }
              }
            }

            // Numbers, then emails: what each is (a menu), it, taken off with ×.
            Repeater {
              model: [{ list: "phones", title: "Phone numbers", add: "Add a phone number", hint: "e.g. +1 555 123 4567", labels: Contacts.PHONE_LABELS, err: "phone" },
                      { list: "emails", title: "Emails", add: "Add an email", hint: "e.g. sam@example.com", labels: Contacts.EMAIL_LABELS, err: "email" }]
              delegate: Column {
                id: grp
                required property var modelData
                width: form.width
                spacing: 6
                Text {
                  textFormat: Text.PlainText
                  text: grp.modelData.title
                  font.family: pv.theme.uiFont
                  font.pixelSize: 12
                  font.weight: Font.Medium
                  color: pv.theme.muted
                }
                Repeater {
                  id: rows
                  model: pv.draft ? pv.draft[grp.modelData.list] : []
                  Component.onCompleted: { if (grp.modelData.list === "phones") pv.phoneRows = rows; else pv.emailRows = rows }
                  delegate: Row {
                    id: entry
                    required property var modelData
                    required property int index
                    objectName: grp.modelData.list === "phones" ? "formPhone" : "formEmail"
                    function focusValue() { valueField.input.forceActiveFocus() }
                    spacing: 8
                    // What it is: mobile, work...
                    Rectangle {
                      id: labelButton
                      objectName: "formLabel"
                      width: 100
                      height: 38
                      radius: 8
                      color: labelHover.hovered ? pv.theme.hover : pv.theme.background
                      border.width: 1
                      border.color: pv.theme.line
                      Text {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: entry.modelData.label
                        font.family: pv.theme.uiFont
                        font.pixelSize: 13
                        color: pv.theme.text
                      }
                      Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: pv.theme.icons.down
                        font.family: pv.theme.iconFont
                        font.pixelSize: 11
                        color: pv.theme.muted
                      }
                      HoverHandler { id: labelHover; cursorShape: Qt.PointingHandCursor }
                      TapHandler { onTapped: labelMenu.open() }
                      Pop {
                        id: labelMenu
                        theme: pv.theme
                        focus: false
                        width: 150
                        y: labelButton.height + 4
                        contentItem: Column {
                          Repeater {
                            model: grp.modelData.labels
                            delegate: MenuRow {
                              required property var modelData
                              width: parent.width
                              theme: pv.theme
                              text: modelData
                              checked: entry.modelData.label === modelData
                              onClicked: { labelMenu.close(); pv.relabel(grp.modelData.list, entry.index, modelData) }
                            }
                          }
                        }
                      }
                    }
                    FormField {
                      id: valueField
                      objectName: grp.modelData.list === "phones" ? "formPhoneValue" : "formEmailValue"
                      width: form.width - 100 - 8 - 38 - 8
                      placeholder: grp.modelData.hint
                      text: entry.modelData.value
                      error: pv.errors[grp.modelData.err + entry.index] || ""
                      onEdited: function(v) { pv.setRow(grp.modelData.list, entry.index, v) }
                    }
                    IconButton {
                      objectName: "formRemove"
                      theme: pv.theme; icon: pv.theme.icons.close; size: 38; iconSize: 13
                      tip: "Take it off"
                      onClicked: pv.removeRow(grp.modelData.list, entry.index)
                    }
                  }
                }
                Text {
                  objectName: grp.modelData.list === "phones" ? "formAddPhone" : "formAddEmail"
                  topPadding: 2
                  textFormat: Text.PlainText
                  text: "+ " + grp.modelData.add
                  font.family: pv.theme.uiFont
                  font.pixelSize: 13
                  font.weight: Font.Medium
                  color: addHover.hovered ? pv.theme.text : pv.theme.muted
                  HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                  TapHandler { onTapped: pv.addRow(grp.modelData.list) }
                }
              }
            }

            Row {
              spacing: 12
              FormField {
                objectName: "formBirthday"
                width: form.half
                label: "Birthday"
                placeholder: "1990-04-12, or --04-12"
                text: pv.draft ? pv.draft.birthday : ""
                error: pv.errors.birthday || ""
                onEdited: function(v) { pv.setField("birthday", v) }
              }
              FormField {
                objectName: "formWebsite"
                width: form.half
                label: "Website"
                placeholder: "https://..."
                text: pv.draft ? pv.draft.website : ""
                error: pv.errors.website || ""
                onEdited: function(v) { pv.setField("website", v) }
              }
            }
            FormField {
              objectName: "formAddress"
              width: parent.width
              label: "Address"
              placeholder: "Street, city"
              text: pv.draft ? pv.draft.address : ""
              onEdited: function(v) { pv.setField("address", v) }
            }
            Column {
              width: parent.width
              spacing: 6
              Text {
                textFormat: Text.PlainText
                text: "Notes"
                font.family: pv.theme.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
                color: pv.theme.muted
              }
              Rectangle {
                width: parent.width
                height: Math.max(84, notesEdit.contentHeight + 20)
                radius: 8
                color: pv.theme.background
                border.width: 1
                border.color: notesEdit.activeFocus ? Qt.alpha(pv.theme.accent, 0.9) : pv.theme.line
                TextEdit {
                  id: notesEdit
                  objectName: "formNotes"
                  x: 11
                  y: 10
                  width: parent.width - 22
                  wrapMode: TextEdit.Wrap
                  textFormat: TextEdit.PlainText
                  selectByMouse: true
                  font.family: pv.theme.uiFont
                  font.pixelSize: 14
                  color: pv.theme.text
                  selectionColor: Qt.alpha(pv.theme.accent, 0.35)
                  text: pv.draft ? pv.draft.notes : ""
                  onTextChanged: if (activeFocus) pv.setField("notes", text)
                  Text {
                    visible: notesEdit.text === ""
                    textFormat: Text.PlainText
                    text: "How you know them, what to remember\u2026"
                    font: notesEdit.font
                    color: pv.theme.faint
                  }
                }
                HoverHandler { cursorShape: Qt.IBeamCursor }
              }
            }
          }
        }
      }
    }
  }
}
