// MathJax's TeX input and SVG output, without a browser (its own small DOM),
// for Qt's JavaScript engine: render(tex, display) is the formula as an
// <svg>, its glyphs in it ("local" font cache), drawn in currentColor.
import {mathjax} from 'mathjax-full/js/mathjax.js';
import {TeX} from 'mathjax-full/js/input/tex.js';
import {SVG} from 'mathjax-full/js/output/svg.js';
import {liteAdaptor} from 'mathjax-full/js/adaptors/liteAdaptor.js';
import {RegisterHTMLHandler} from 'mathjax-full/js/handlers/html.js';
import 'mathjax-full/js/input/tex/base/BaseConfiguration.js';
import 'mathjax-full/js/input/tex/ams/AmsConfiguration.js';
import 'mathjax-full/js/input/tex/newcommand/NewcommandConfiguration.js';
import 'mathjax-full/js/input/tex/noundefined/NoUndefinedConfiguration.js';
import 'mathjax-full/js/input/tex/boldsymbol/BoldsymbolConfiguration.js';
import 'mathjax-full/js/input/tex/braket/BraketConfiguration.js';
import 'mathjax-full/js/input/tex/cancel/CancelConfiguration.js';
import 'mathjax-full/js/input/tex/color/ColorConfiguration.js';

const adaptor = liteAdaptor();
RegisterHTMLHandler(adaptor);
const tex = new TeX({packages: ['base', 'ams', 'newcommand', 'noundefined', 'boldsymbol', 'braket', 'cancel', 'color']});
const svg = new SVG({fontCache: 'local'});
const doc = mathjax.document('', {InputJax: tex, OutputJax: svg});

export const version = mathjax.version;

export function render(latex, display) {
  const node = doc.convert(String(latex), {display: !!display, em: 16, ex: 8, containerWidth: 1280});
  return adaptor.innerHTML(node);
}
