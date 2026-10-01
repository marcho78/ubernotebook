// Covers.js - what a notebook looks like on the shelf: the color and
// material of its cover, how it's bound, and how its title is put on it.
//
// Shared by the notebook (app/*.qml) and tests/library.test.cjs, so keep it
// plain JavaScript with no QML or Node APIs.
.pragma library
.import "Papers.js" as Papers

var COLORS = [
  { id: "navy", label: "Navy", color: "#22324f" },
  { id: "black", label: "Black", color: "#1b1b1d" },
  { id: "forest", label: "Forest", color: "#27463a" },
  { id: "burgundy", label: "Burgundy", color: "#5b1f2c" },
  { id: "mustard", label: "Mustard", color: "#c89330" },
  { id: "sky", label: "Sky", color: "#6c9cc5" },
  { id: "coral", label: "Coral", color: "#d4705a" },
  { id: "lavender", label: "Lavender", color: "#8b79c0" },
  { id: "sage", label: "Sage", color: "#8aa585" },
  { id: "sand", label: "Sand", color: "#d6c09b" },
  { id: "charcoal", label: "Charcoal", color: "#393c41" },
  { id: "accent", label: "Omarchy theme", color: "" }
]

// shader: the material's number in shaders/cover.frag. label: how the title
// goes on: "foil" (stamped in gold, or pressed into a light cover), "label"
// (written on a paper label), "stamp" (printed straight onto kraft), "box"
// (the composition book's name box).
var MATERIALS = [
  { id: "leather", label: "Leather", shader: 0, title: "foil", band: true },
  { id: "linen", label: "Linen", shader: 1, title: "label", band: false },
  { id: "kraft", label: "Kraft", shader: 2, title: "stamp", band: false },
  { id: "plain", label: "Smooth", shader: 3, title: "label", band: false },
  { id: "composition", label: "Composition", shader: 4, title: "box", band: false }
]

var BINDINGS = [
  { id: "spiral", label: "Spiral" },
  { id: "stitched", label: "Stitched" },
  { id: "hardcover", label: "Hardcover" }
]

function byId(list, id) {
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
  return list[0]
}

function color(id) { return byId(COLORS, id) }
function material(id) { return byId(MATERIALS, id) }
function binding(id) { return byId(BINDINGS, id) }

// Everything the cover needs to draw, from a notebook's cover choice
// { color, material, band } and the theme's accent.
function resolve(cover, accent) {
  var c = cover || {}
  var col = color(c.color)
  var mat = material(c.material)
  var base = col.id === "accent" ? (Papers.hex(accent) || "#6c9cc5") : col.color
  if (mat.id === "kraft" && !c.color) base = "#b48a55"
  var dark = Papers.luminance(base) < 0.45
  var out = {
    color: base,
    colorId: col.id,
    material: mat.id,
    shader: mat.shader,
    titleStyle: mat.title,
    band: c.band === undefined ? mat.band : c.band === true,
    dark: dark,
    // The cover's edges and the inside of it.
    edge: Papers.mix(base, "#000000", 0.35),
    inside: Papers.mix(base, "#f4efe4", 0.78),
    // Gold foil on a dark cover; pressed in, a shade darker, on a light one.
    foil: dark ? "#d8bb74" : Papers.mix(base, "#000000", 0.42),
    stamp: Papers.mix(base, "#1a1208", 0.72),
    band_: Papers.mix(base, "#000000", 0.55),
    // A paper label: cream, with the title written on it.
    labelPaper: "#f6f1e4",
    labelInk: "#23262d",
    // What reads on the cover itself (pages count, etc.).
    text: Papers.readable(base, "#f5f1e8", "#1d1f24")
  }
  return out
}
