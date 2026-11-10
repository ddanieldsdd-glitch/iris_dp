// Genera assets/viewer3d/vendor/three.iris.js: three.js y sus addons en un
// solo script clásico. Con módulos ES, WKWebView y WebView2 bloquean los
// `import` entre archivos en file:// por CORS; un script clásico carga igual
// que siempre. Uso: `npm ci && npm run build` desde esta carpeta.
import { build } from 'esbuild';
import { readFileSync, copyFileSync } from 'node:fs';

const { version } = JSON.parse(readFileSync('node_modules/three/package.json', 'utf8'));
await build({
  entryPoints: ['three_entry.js'],
  bundle: true,
  minify: true,
  format: 'iife',
  globalName: 'THREE',
  target: ['safari15', 'chrome100'],
  legalComments: 'none',
  banner: { js: `/* three.js ${version} + addons · MIT · generado por tools/viewer3d/build.mjs */` },
  outfile: '../../assets/viewer3d/vendor/three.iris.js',
});
copyFileSync('node_modules/three/LICENSE', '../../assets/viewer3d/vendor/THREE_LICENSE.txt');
