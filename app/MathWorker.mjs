// Draws equations off the window's thread: MathJax (vendor/mathjax), in a
// WorkerScript. { key, tex, display } comes back as { key, svg } (what
// MathJax drew: a mistake in the LaTeX is drawn too, in red) or { key,
// error } (it couldn't draw at all).
import { render } from "../vendor/mathjax/tex-svg.mjs"

WorkerScript.onMessage = function(m) {
  var out = { key: m.key }
  try {
    out.svg = render(m.tex, m.display === true)
  } catch (e) {
    out.error = String(e && e.message ? e.message : e)
  }
  WorkerScript.sendMessage(out)
}
