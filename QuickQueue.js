// QuickQueue.js - quick notes made before Pages has loaded (Service.qml):
// each waits with the profile it was made in (its notes folder), and is
// only ever written into that one; another profile opening first, they go
// to its Quick notes notebook, while it's still open (never lost, never in
// another's).
//
// Shared with tests/quickqueue.test.cjs, so keep it plain JavaScript with no
// QML or Node APIs.
.pragma library

// The queue with one more: [{ text, root }].
function add(list, text, root) {
  return (list || []).concat([{ text: String(text || ""), root: String(root || "") }])
}

// Those of the notes folder `root` (to write now), and the rest (kept for
// when theirs is open again): { mine: [text], rest: [{ text, root }] }.
function take(list, root) {
  var mine = []
  var rest = []
  ;(list || []).forEach(function(e) {
    if (e && e.root && e.root === root) mine.push(e.text)
    else if (e && e.root) rest.push(e)
  })
  return { mine: mine, rest: rest }
}
