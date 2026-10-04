# MathJax, for Uber Notebook's equations

`tex-svg.mjs` is [MathJax](https://www.mathjax.org/) 3.2.2 (`mathjax-full`),
its TeX input and SVG output only, bundled into one ECMAScript module that
runs in Qt's JavaScript engine: Uber Notebook draws equations with it, in a
worker thread (`app/MathWorker.mjs`), with nothing else to install.

It's built from `build/` (`npm install`, then `npm run build`), with the TeX
packages `entry.js` names: base, ams, newcommand, noundefined, boldsymbol,
braket, cancel and color.

MathJax is Copyright (c) 2017-2022 The MathJax Consortium, under the Apache
License 2.0 (`LICENSE`). Two of its files are changed as it's bundled
(`build/build.mjs`), so it runs in Qt's engine:

- `js/util/Styles.js`: `Styles.connect` is `Styles.connectRules` (in Qt every
  function has a read-only `connect`, for signals).
- `js/input/tex/Stack.js`: `item.env = this.env` is `item._env = this.env`
  (what the setter sets; through the setter it fails in Qt the first time).
