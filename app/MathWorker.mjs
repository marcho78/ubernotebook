// Draws equations off the window's thread: MathJax (vendor/mathjax), in a
// WorkerScript. { key, tex, display } comes back as { key, svg } (what
// MathJax drew: a mistake in the LaTeX is drawn too, in red) or { key,
// error } (it couldn't draw at all).
import { render } from "../vendor/mathjax/tex-svg.mjs"

// (A drawing of more than MAX_SVG characters isn't sent back: Equations.js
// wouldn't draw it anyway, and it isn't copied to the window's thread.)
var MAX_SVG = 1000000

WorkerScript.onMessage = function(m) {
  var out = { key: m.key }
  try {
    out.svg = render(m.tex, m.display === true)
    if (out.svg.length > MAX_SVG) { delete out.svg; out.error = "Too much to draw" }
  } catch (e) {
    out.error = String(e && e.message ? e.message : e)
  }
  WorkerScript.sendMessage(out)
}
