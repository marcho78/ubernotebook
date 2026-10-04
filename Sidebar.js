.pragma library

// Pages' sidebar: what's in it is yours to choose (Settings → Appearance →
// Sidebar, or a right-click on it), its sections fold, and its long lists
// (the projects, the pages) change a row at a time.

// What can be left out of it, where it is, and what it's called. Pages and
// Settings are always there.
var ITEMS = [
  { id: "search", label: "Search", place: "top" },
  { id: "calendar", label: "Calendar", place: "top" },
  { id: "library", label: "Library", place: "top" },
  { id: "people", label: "People", place: "top" },
  { id: "today", label: "Today", place: "sections" },
  { id: "favorites", label: "Favorites", place: "sections" },
  { id: "projects", label: "Projects", place: "sections" },
  { id: "tags", label: "Tags", place: "sections" },
  { id: "import", label: "Import", place: "foot" },
  { id: "templates", label: "Templates", place: "foot" },
  { id: "archive", label: "Archive", place: "foot" },
  { id: "trash", label: "Trash", place: "foot" }
]

// The sections that fold.
var FOLDS = ["today", "favorites", "projects", "tags", "pages"]

// The ones at the top, in the middle ("sections") or at the foot.
function itemsAt(place) {
  return ITEMS.filter(function(item) { return item.place === place })
}

function label(id) {
  var item = ITEMS.filter(function(x) { return x.id === id })[0]
  return item ? item.label : ""
}

// The list (sidebarHidden, sidebarFolded) with `id` in it, or not.
function setIn(list, id, on) {
  var out = (list || []).filter(function(x) { return x !== id })
  if (on) out.push(id)
  return out
}

function toggled(list, id) {
  return setIn(list, id, (list || []).indexOf(id) < 0)
}

// How to make the rows `from` into the rows `to` (their keys, each once in
// each), in order: { op: "remove", at }, { op: "insert", at, key } and
// { op: "move", from, to }. What stays keeps its row, so a title typed or a
// page opened changes a row or two, not the whole list.
function steps(from, to) {
  var cur = (from || []).slice()
  var want = {}
  to.forEach(function(k) { want[k] = true })
  var out = []
  for (var i = cur.length - 1; i >= 0; i--) {
    if (want[cur[i]]) continue
    out.push({ op: "remove", at: i })
    cur.splice(i, 1)
  }
  for (var j = 0; j < to.length; j++) {
    if (cur[j] === to[j]) continue
    var at = cur.indexOf(to[j], j + 1)
    if (at >= 0) {
      out.push({ op: "move", from: at, to: j })
      cur.splice(at, 1)
    } else {
      out.push({ op: "insert", at: j, key: to[j] })
    }
    cur.splice(j, 0, to[j])
  }
  return out
}
