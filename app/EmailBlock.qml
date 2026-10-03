import QtQuick
import QtQuick.Controls
import "../Email.js" as Email
import "../Files.js" as Files
import "../Dates.js" as Dates
import "../Collection.js" as Collection

// An email on a page in Pages (/email, or an .eml dropped on it): its
// subject, who it's from and to, when, its first lines and its attachments;
// Show email reads it in full (its HTML made safe: no scripts, styles or
// pictures from the web; links kept). An attachment opens in its app (it's
// written out into Pages/assets the first time); the email itself, in your
// mail app. Its colors are Pages' or your own: an accent and its background.
DataCard {
  id: eb
  kind: "email"

  readonly property var ws: editor ? editor.calendarSource : null
  readonly property bool has: info.src !== ""
  readonly property bool expanded: info.open === true
  // The message in full, read when it's shown: rich text to draw, its words.
  property string body: ""
  property string bodyWords: ""
  // (Qt's rich text takes a link's color from the link itself.)
  readonly property string linkHex: String(accent)
  readonly property string shownBody: body.replace(/<a href=/g, "<a style=\"color:" + linkHex + ";\" href=")
  // Its icon: quiet, unless the block has a color of its own.
  readonly property color iconColor: look.color ? accent : faint
  property bool reading: false
  function sample() { return info.subject || "Email" }

  onLoaded: if (expanded && has && body === "") readBody()
  onExpandedChanged: if (expanded && has && body === "") readBody()
  function readBody() {
    if (!ws || reading) return
    reading = true
    var src = info.src
    ws.readEmail(src, function(m) {
      eb.reading = false
      if (eb.info.src !== src) return
      eb.body = m ? Email.displayHtml(m, String(eb.faint)) : ""
      eb.bodyWords = m ? Email.bodyText(m) : ""
      if (!m) eb.body = "<i>The email couldn't be read.</i>"
    })
  }

  function when(iso, full) {
    var d = iso ? new Date(iso) : null
    if (!d || isNaN(d.getTime())) return ""
    var now = new Date()
    var day = Dates.SHORT_MONTHS[d.getMonth()] + " " + d.getDate() + (d.getFullYear() !== now.getFullYear() ? ", " + d.getFullYear() : "")
    return full ? Dates.SHORT_DAYS[d.getDay()] + " " + day + ", " + Qt.formatTime(d, "HH:mm") : day
  }

  width: available
  height: card.height

  Rectangle {
    id: card
    width: eb.width
    height: eb.has ? content.height + 28 : 58
    radius: 10
    color: eb.look.background ? eb.fill : (eb.editor ? Qt.alpha(eb.ink, eb.dark ? 0.04 : 0.025) : "transparent")
    border.width: 1
    border.color: Qt.alpha(eb.words, eb.pointerIn ? 0.18 : 0.11)

    // Not added yet: pick one.
    Row {
      visible: !eb.has
      x: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: eb.theme ? eb.theme.icons.mail : ""
        font.family: eb.theme ? eb.theme.iconFont : ""
        font.pixelSize: 18
        color: eb.iconColor
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: eb.readOnly ? "An email, not added yet" : "Choose an email (.eml), or drop one on the page"
        font.family: eb.editor ? eb.editor.uiFamily : ""
        font.pixelSize: 14
        color: eb.faint
      }
    }
    TapHandler { enabled: !eb.has && !eb.readOnly; onTapped: eb.act("pick", null) }
    HoverHandler { enabled: !eb.has && !eb.readOnly; cursorShape: Qt.PointingHandCursor }

    Column {
      id: content
      visible: eb.has
      x: 16
      y: 14
      width: card.width - 32
      spacing: 0

      // Its subject, when, who from and to.
      Item {
        width: parent.width
        height: subjectText.height
        Text {
          x: 0
          y: 1
          textFormat: Text.PlainText
          text: eb.theme ? eb.theme.icons.mail : ""
          font.family: eb.theme ? eb.theme.iconFont : ""
          font.pixelSize: 16
          color: eb.iconColor
        }
        Text {
          id: subjectText
          objectName: "emailSubject"
          x: 26
          width: parent.width - x - dateText.width - (tools.visible ? tools.width + 4 : 0) - 12
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: eb.info.subject || "(no subject)"
          font.family: eb.editor ? eb.editor.uiFamily : ""
          font.pixelSize: 15
          font.weight: Font.DemiBold
          color: eb.words
        }
        Text {
          id: dateText
          anchors.right: tools.visible ? tools.left : parent.right
          anchors.rightMargin: tools.visible ? 6 : 0
          anchors.verticalCenter: subjectText.verticalCenter
          textFormat: Text.PlainText
          text: eb.when(eb.info.date, false)
          font.family: eb.editor ? eb.editor.uiFamily : ""
          font.pixelSize: 12
          color: eb.faint
        }
        // Under the pointer: in your mail app, its colors.
        Row {
          id: tools
          anchors.right: parent.right
          anchors.verticalCenter: subjectText.verticalCenter
          visible: !eb.readOnly && (eb.pointerIn || eb.trying !== null)
          IconButton {
            objectName: "emailOpen"
            theme: eb.theme; icon: eb.theme ? eb.theme.icons.openExternal : ""; size: 26; iconSize: 13; tint: eb.words
            tip: "Open it in your mail app"
            onClicked: eb.act("open", null)
          }
          IconButton {
            id: paint
            objectName: "emailColors"
            theme: eb.theme; icon: eb.theme ? eb.theme.icons.palette : ""; size: 26; iconSize: 13; tint: eb.words
            tip: "Its colors"
            onClicked: eb.askColors(paint)
          }
        }
      }
      Text {
        objectName: "emailWho"
        x: 26
        width: parent.width - x
        topPadding: 3
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: (Email.shortName(eb.info.from) || "?") + (eb.info.to ? "  \u2192  " + Email.shortNames(eb.info.to, 3) : "")
        font.family: eb.editor ? eb.editor.uiFamily : ""
        font.pixelSize: 13
        color: eb.faint
      }

      // Folded: its first lines, its attachments, Show email.
      Text {
        objectName: "emailPreview"
        visible: !eb.expanded && eb.info.preview !== ""
        x: 26
        width: parent.width - x
        topPadding: 8
        maximumLineCount: 2
        elide: Text.ElideRight
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: eb.info.preview
        font.family: eb.editor ? eb.editor.family : ""
        font.pixelSize: 14
        lineHeight: 1.2
        color: Qt.alpha(eb.words, 0.78)
      }

      // Open: who, in full; then what it says.
      Column {
        visible: eb.expanded
        x: 26
        width: parent.width - x
        topPadding: 10
        spacing: 2
        Repeater {
          model: [{ k: "From", v: eb.info.from }, { k: "To", v: eb.info.to }, { k: "Cc", v: eb.info.cc }, { k: "Date", v: eb.when(eb.info.date, true) }].filter(function(r) { return r.v })
          delegate: Row {
            required property var modelData
            width: parent.width
            spacing: 10
            Text {
              width: 44
              textFormat: Text.PlainText
              text: parent.modelData.k
              font.family: eb.editor ? eb.editor.uiFamily : ""
              font.pixelSize: 12
              color: eb.faint
            }
            Text {
              width: parent.width - 54
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
              text: parent.modelData.v
              font.family: eb.editor ? eb.editor.uiFamily : ""
              font.pixelSize: 12
              color: Qt.alpha(eb.words, 0.85)
            }
          }
        }
        Item { width: 1; height: 8 }
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(eb.words, 0.1) }
        Item { width: 1; height: 10 }
        Text {
          objectName: "emailBody"
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.RichText
          text: eb.reading && eb.body === "" ? "<i>Reading\u2026</i>" : eb.shownBody
          font.family: eb.editor ? eb.editor.family : ""
          font.pixelSize: 14
          lineHeight: 1.25
          color: eb.words
          linkColor: eb.accent
          onLinkActivated: function(link) { if (/^(https?:|mailto:)/i.test(link)) eb.act("link", link) }
          HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
      }

      // Its attachments: a click opens one.
      Flow {
        visible: eb.info.attachments.length > 0
        x: 26
        width: parent.width - x
        topPadding: 10
        spacing: 6
        Repeater {
          model: eb.info.attachments
          delegate: Rectangle {
            id: chip
            required property var modelData
            required property int index
            objectName: "emailAttachment"
            width: chipRow.width + 18
            height: 28
            radius: 7
            color: chipHover.hovered ? Qt.alpha(eb.words, 0.1) : Qt.alpha(eb.words, 0.05)
            border.width: 1
            border.color: Qt.alpha(eb.words, 0.1)
            Row {
              id: chipRow
              anchors.centerIn: parent
              spacing: 6
              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: eb.theme ? (eb.theme.icons[Collection.iconOf({ kind: "file", file: Files.kindOf(chip.modelData.name) })] || eb.theme.icons.attach) : ""
                font.family: eb.theme ? eb.theme.iconFont : ""
                font.pixelSize: 13
                color: eb.faint
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
                text: chip.modelData.name
                font.family: eb.editor ? eb.editor.uiFamily : ""
                font.pixelSize: 12
                color: eb.words
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: chip.modelData.size ? Files.sizeLabel(chip.modelData.size) : ""
                font.family: eb.editor ? eb.editor.uiFamily : ""
                font.pixelSize: 11
                color: eb.faint
              }
            }
            HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: eb.act("attachment", chip.index) }
            ToolTip.visible: chipHover.hovered
            ToolTip.delay: 600
            ToolTip.text: "Open it"
          }
        }
      }

      // Show email / Hide it.
      Text {
        objectName: "emailToggle"
        x: 26
        topPadding: 10
        textFormat: Text.PlainText
        text: eb.expanded ? "Hide email" : "Show email"
        font.family: eb.editor ? eb.editor.uiFamily : ""
        font.pixelSize: 13
        font.weight: Font.Medium
        color: toggleHover.hovered ? eb.words : eb.faint
        HoverHandler { id: toggleHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: eb.change({ open: !eb.expanded }) }
      }
    }
  }
}
