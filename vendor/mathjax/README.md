# MathJax, for Uber Notebook's equations

`tex-svg.mjs` (and the parts it imports, `tex-svg-*.mjs`) is
[MathJax](https://www.mathjax.org/) 3.2.2 (`mathjax-full`), its TeX input and
SVG output only, bundled as ECMAScript modules that run in Qt's JavaScript
engine: Uber Notebook draws equations with it, in a worker thread
(`app/MathWorker.mjs`), with nothing else to install.

It's built from `build/` (`npm install`, then `npm run build`), with the TeX
packages `entry.js` names: base, ams, newcommand, noundefined, boldsymbol,
braket, cancel and color. The build is in parts of at most 480 KB each (the
Omarchy plugin marketplace's security scan reads files up to 512 KiB):
esbuild's code splitting, with the TeX font's normal glyphs (one file of
620 KB in MathJax) in two parts of their own. What it draws is the same as
the single-file build's, character for character (checked on every glyph of
that font, and on equations of every kind). The build is deterministic: the
same versions give the same files, their names included.

MathJax is Copyright (c) 2017-2022 The MathJax Consortium, under the Apache
License 2.0 (`LICENSE`). Three of its files are changed as it's bundled
(`build/build.mjs`):

- `js/util/Styles.js`: `Styles.connect` is `Styles.connectRules` (in Qt every
  function has a read-only `connect`, for signals).
- `js/input/tex/Stack.js`: `item.env = this.env` is `item._env = this.env`
  (what the setter sets; through the setter it fails in Qt the first time).
- `js/output/svg/fonts/tex/normal.js`: its glyphs are added to the font in
  two parts (the same glyphs, the same font), so it fits in two files.
