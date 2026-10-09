.pragma library

// What's open over the notes (a popup anywhere in a view's tree, or an
// overlay that closes like one: closesForSwitch), closed: another profile
// is opening, and what's in it is the profile before's. `keep`: left open
// (Settings, where the switch may be made). How many were closed.
function closeAll(root, keep) {
  var closed = 0
  function walk(o, depth) {
    if (!o || typeof o !== "object" || depth > 120) return
    if (keep && keep.indexOf(o) >= 0) return
    var popup = o.modal !== undefined && typeof o.close === "function"
    if ((popup || o.closesForSwitch === true) && o.visible === true) { o.close(); closed++ }
    // (An item's own, a popup's content, and what a Loader made: a popup
    // made by one isn't among its children.)
    var kids = o.contentData !== undefined && o.contentData !== null ? o.contentData : o.data
    if (kids) for (var i = 0; i < kids.length; i++) walk(kids[i], depth + 1)
    if (o.sourceComponent !== undefined && o.item && typeof o.item === "object" && o.item.parent !== o) walk(o.item, depth + 1)
  }
  walk(root, 0)
  return closed
}
