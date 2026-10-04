// Builds ../tex-svg.mjs and the parts it imports (../tex-svg-*.mjs) from
// entry.js (npm install, then npm run build).
//
// MathJax is split into files of at most MAX bytes each (the Omarchy plugin
// marketplace's security scan reads files up to 512 KiB): esbuild's code
// splitting, with a few of MathJax's own modules as extra entry points so
// their code goes into parts of its own, and the glyphs of the TeX font's
// normal variant (one file of 620 KB) in parts too. Each part is a plain
// ES module the others import; the extra entry points' own files are thin
// re-exports nothing imports, so they're removed. What it draws is
// unchanged (check.mjs compares it with the single-file build).
//
// Qt's JavaScript engine needs two changes to MathJax 3.2.2, made here as
// it's bundled (the build stops if the code they change isn't there):
// - Every function has a read-only `connect` in Qt (for signals), so
//   MathJax's Styles.connect table can't be set: it's renamed.
// - Setting a stack item's env through its setter fails the first time:
//   what the setter sets (`_env`) is set instead.
import * as esbuild from 'esbuild';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const OUT = process.env.OUT || '..';
const MAX = 480 * 1024;
const NORMAL = 'node_modules/mathjax-full/js/output/svg/fonts/tex/normal.js';
const NORMAL_PARTS = 2;

function change(file, from, to) {
  return async (args) => {
    const src = await fs.promises.readFile(args.path, 'utf8');
    if (from instanceof RegExp ? !from.test(src) : src.indexOf(from) < 0) throw new Error(file + ' has changed: check the Qt fix for it');
    return { contents: src.replace(from, to), loader: 'js' };
  };
}

// The normal variant's glyphs (AddPaths(font, paths, content)), read by
// running normal.js with stand-ins for what it requires.
function normalData() {
  const src = fs.readFileSync(NORMAL, 'utf8');
  let got = null;
  const context = { exports: {}, require: (p) => {
    if (p === '../../FontData.js') return { AddPaths: (font, paths, content) => { got = { paths, content }; return font; } };
    if (p === '../../../common/fonts/tex/normal.js') return { normal: {} };
    throw new Error('normal.js requires ' + p + ': check the split');
  } };
  vm.runInNewContext(src, context);
  if (!got || Object.keys(got.paths).length < 100) throw new Error('normal.js has changed: check the split');
  return got;
}

// The glyphs in NORMAL_PARTS files of their own (gen/), and normal.js adding
// them to the font one part after another, then its combined characters.
const gen = path.resolve('gen');
fs.mkdirSync(gen, { recursive: true });
const data = normalData();
const keys = Object.keys(data.paths);
const per = Math.ceil(keys.length / NORMAL_PARTS);
const parts = [];
for (let i = 0; i < NORMAL_PARTS; i++) {
  const part = {};
  for (const k of keys.slice(i * per, (i + 1) * per)) part[k] = data.paths[k];
  const file = path.join(gen, 'normal-paths-' + (i + 1) + '.cjs');
  fs.writeFileSync(file, '"use strict";\nexports.paths = ' + JSON.stringify(part) + ';\n');
  parts.push(file);
}
const normalJs = [
  '"use strict";',
  'Object.defineProperty(exports, "__esModule", { value: true });',
  'exports.normal = void 0;',
  'var FontData_js_1 = require("../../FontData.js");',
  'var normal_js_1 = require("../../../common/fonts/tex/normal.js");',
  ...parts.map((file) => '(0, FontData_js_1.AddPaths)(normal_js_1.normal, require(' + JSON.stringify(file) + ').paths, {});'),
  'exports.normal = (0, FontData_js_1.AddPaths)(normal_js_1.normal, {}, ' + JSON.stringify(data.content) + ');',
  ''
].join('\n');

const forQt = {
  name: 'for-qt',
  setup(build) {
    build.onLoad({ filter: /mathjax-full[\\/]js[\\/]util[\\/]Styles\.js$/ }, change('Styles.js', /\.connect\b/g, '.connectRules'));
    build.onLoad({ filter: /mathjax-full[\\/]js[\\/]input[\\/]tex[\\/]Stack\.js$/ }, change('Stack.js', 'item.env = this.env;', 'item._env = this.env;'));
    build.onLoad({ filter: /mathjax-full[\\/]js[\\/]output[\\/]svg[\\/]fonts[\\/]tex[\\/]normal\.js$/ }, async () => ({ contents: normalJs, loader: 'js', resolveDir: path.resolve(path.dirname(NORMAL)) }));
  }
};

// The parts: the glyphs; the rest of the font; TeX's input; the SVG output.
const extra = {
  'part-glyphs-1': parts[0],
  'part-glyphs-2': parts[1],
  'part-font': 'node_modules/mathjax-full/js/output/svg/fonts/tex.js',
  'part-tex': 'node_modules/mathjax-full/js/input/tex.js',
  'part-svg': 'node_modules/mathjax-full/js/output/svg.js'
};
const tmp = fs.mkdtempSync(path.join(OUT, '.build-'));
const result = await esbuild.build({
  entryPoints: { 'tex-svg': 'entry.js', ...extra }, bundle: true, format: 'esm', target: 'es2017', minify: true,
  splitting: true, outdir: tmp, outExtension: { '.js': '.mjs' }, chunkNames: 'tex-svg-[hash]',
  legalComments: 'none', plugins: [forQt], metafile: true, logLevel: 'warning'
});

// What tex-svg.mjs needs: itself and the parts it imports, and theirs.
const outputs = result.metafile.outputs;
const byName = {};
for (const file of Object.keys(outputs)) byName[path.basename(file)] = file;
const needed = new Set();
(function walk(file) {
  if (needed.has(file)) return;
  needed.add(file);
  for (const imp of outputs[file].imports) {
    if (imp.external) throw new Error('an external import: ' + imp.path);
    walk(byName[path.basename(imp.path)] || imp.path);
  }
})(byName['tex-svg.mjs']);
for (const name of Object.keys(extra)) if (needed.has(byName[name + '.mjs'])) throw new Error(name + '.mjs is imported: check the split');
// Every part small enough, then in place (the old parts out first).
for (const file of needed) {
  const size = fs.statSync(file).size;
  if (size > MAX) throw new Error(path.basename(file) + ' is ' + size + ' bytes, over ' + MAX);
}
for (const old of fs.readdirSync(OUT)) if (/^tex-svg(-[A-Z0-9]+)?\.mjs$/.test(old)) fs.unlinkSync(path.join(OUT, old));
for (const file of needed) fs.renameSync(file, path.join(OUT, path.basename(file)));
fs.rmSync(tmp, { recursive: true, force: true });
fs.rmSync(gen, { recursive: true, force: true });
for (const file of [...needed].map((f) => path.basename(f)).sort()) console.log('built ' + path.join(OUT, file) + ' (' + fs.statSync(path.join(OUT, file)).size + ' bytes)');
