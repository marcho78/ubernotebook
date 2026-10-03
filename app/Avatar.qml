import QtQuick
import "../Contacts.js" as Contacts

// A person's initials in a quiet circle (a person's outline for someone
// with nothing to go by yet).
Rectangle {
  id: av

  property var theme: null
  property var person: null
  property real size: 34

  // No one yet (a new person, no name): a person's outline, not initials.
  readonly property bool nobody: !person || (!person.name && !(person.emails || []).length && !(person.phones || []).length && !person.company)

  width: size
  height: size
  radius: size / 2
  color: theme ? Qt.alpha(theme.text, theme.dark ? 0.13 : 0.09) : "#dddddd"
  Text {
    visible: av.nobody && av.theme !== null
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: av.theme ? av.theme.icons.person : ""
    font.family: av.theme ? av.theme.iconFont : ""
    font.pixelSize: Math.round(av.size * 0.48)
    color: av.theme ? av.theme.muted : "#888888"
  }
  Text {
    visible: !av.nobody
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: Contacts.initials(av.person)
    font.family: av.theme ? av.theme.uiFont : ""
    font.pixelSize: Math.max(9, Math.round(av.size * 0.38))
    font.weight: Font.DemiBold
    color: av.theme ? Qt.alpha(av.theme.text, 0.72) : "#444444"
  }
}
