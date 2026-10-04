// Builds ../tex-svg.mjs from entry.js (npm install, then npm run build).
//
// Qt's JavaScript engine needs two changes to MathJax 3.2.2, made here as
// it's bundled (the build stops if the code they change isn't there):
// - Every function has a read-only `connect` in Qt (for signals), so
//   MathJax's Styles.connect table can't be set: it's renamed.
// - Setting a stack item's env through its setter fails the first time:
//   what the setter sets (`_env`) is set instead.
import * as esbuild from 'esbuild';
import fs from 'node:fs';

function change(file, from, to) {
  return async (args) => {
    const src = await fs.promises.readFile(args.path, 'utf8');
    if (from instanceof RegExp ? !from.test(src) : src.indexOf(from) < 0) throw new Error(file + ' has changed: check the Qt fix for it');
    return { contents: src.replace(from, to), loader: 'js' };
  };
}

const forQt = {
  name: 'for-qt',
  setup(build) {
    build.onLoad({ filter: /mathjax-full[\\/]js[\\/]util[\\/]Styles\.js$/ }, change('Styles.js', /\.connect\b/g, '.connectRules'));
    build.onLoad({ filter: /mathjax-full[\\/]js[\\/]input[\\/]tex[\\/]Stack\.js$/ }, change('Stack.js', 'item.env = this.env;', 'item._env = this.env;'));
  }
};

await esbuild.build({
  entryPoints: ['entry.js'], bundle: true, format: 'esm', target: 'es2017', minify: true,
  legalComments: 'none', outfile: '../tex-svg.mjs', plugins: [forQt], logLevel: 'warning'
});
console.log('built ../tex-svg.mjs');
