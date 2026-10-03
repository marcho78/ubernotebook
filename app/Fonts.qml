import QtQuick

// The fonts Uber Notebook brings with it: handwriting (Caveat, Patrick Hand), a
// typewriter (Special Elite), a marker for labels (Permanent Marker) and a
// book face (Lora). `loaded` counts up as each one is ready.
Item {
  id: fonts
  visible: false
  property int loaded: 0

  FontLoader { source: "../fonts/Caveat.ttf"; onStatusChanged: if (status === FontLoader.Ready) fonts.loaded++ }
  FontLoader { source: "../fonts/PatrickHand-Regular.ttf"; onStatusChanged: if (status === FontLoader.Ready) fonts.loaded++ }
  FontLoader { source: "../fonts/SpecialElite-Regular.ttf"; onStatusChanged: if (status === FontLoader.Ready) fonts.loaded++ }
  FontLoader { source: "../fonts/PermanentMarker-Regular.ttf"; onStatusChanged: if (status === FontLoader.Ready) fonts.loaded++ }
  FontLoader { source: "../fonts/Lora.ttf"; onStatusChanged: if (status === FontLoader.Ready) fonts.loaded++ }
  FontLoader { source: "../fonts/Lora-Italic.ttf"; onStatusChanged: if (status === FontLoader.Ready) fonts.loaded++ }
}
