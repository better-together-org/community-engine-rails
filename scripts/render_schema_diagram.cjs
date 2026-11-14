#!/usr/bin/env node
'use strict';

// Renders db/community-engine-db.dbml to docs/diagrams/exports/{svg,png}/ce_full_schema_erd.*.
// dbml-renderer turns the DBML into Graphviz DOT; neato lays all tables out in two dimensions (the stock
// left-to-right layout stacks 130 tables into one 70,000 px column); headless Chrome rasterizes the SVG.
// Dependencies are installed by bin/export_schema_diagrams into tmp/schema-diagram-tools.
//
//   node scripts/render_schema_diagram.cjs <tools-dir> <dbml> <svg-out> <png-out>

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { createRequire } = require('node:module');

const [toolsDir, dbmlPath, svgPath, pngPath] = process.argv.slice(2);
if (!pngPath) {
  console.error('usage: render_schema_diagram.cjs <tools-dir> <dbml> <svg-out> <png-out>');
  process.exit(2);
}
const toolsRequire = createRequire(path.join(path.resolve(toolsDir), 'package.json'));
const MAX_PNG_SIDE = 10000; // Chrome drops most of the drawing on larger canvases

function dotFor(dbml) {
  const cli = path.join(path.resolve(toolsDir), 'node_modules', '.bin', 'dbml-renderer');
  const dot = execFileSync(cli, ['-i', dbml, '-f', 'dot'], { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });
  // `start` fixes neato's random seed so the layout is identical on every run.
  return dot.replace('rankdir=LR;', 'overlap=prism; overlap_scaling=3; splines=true; sep="+30"; K=3; start=1;');
}

function svgFor(dot) {
  const render = toolsRequire('@aduh95/viz.js/sync');
  return render(dot, { format: 'svg', engine: 'neato' });
}

function chromePath() {
  const candidates = [process.env.CHROME_PATH, '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser'];
  const cache = path.join(process.env.HOME || '', '.cache', 'puppeteer');
  if (fs.existsSync(cache)) {
    const found = execFileSync('find', [cache, '-type', 'f', '-name', 'chrome-headless-shell'], { encoding: 'utf8' })
      .split('\n').filter(Boolean).sort().pop();
    if (found) candidates.push(found);
  }
  const chrome = candidates.find((candidate) => candidate && fs.existsSync(candidate));
  if (!chrome) throw new Error('No Chrome found; set CHROME_PATH');
  return chrome;
}

async function rasterize(svg) {
  const puppeteer = toolsRequire('puppeteer-core');
  const [, width, height] = svg.match(/<svg[^>]*width="([\d.]+)pt"[^>]*height="([\d.]+)pt"/) ||
    svg.match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/) || [];
  const scale = Math.min(1, MAX_PNG_SIDE / Math.max(Number(width), Number(height)));
  const pxWidth = Math.ceil(Number(width) * scale);
  const pxHeight = Math.ceil(Number(height) * scale);
  const browser = await puppeteer.launch({ executablePath: chromePath(), args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: pxWidth, height: pxHeight });
    // Graphviz sizes the SVG in pt; restate it in px so the viewBox scales the drawing to the viewport.
    // Inline SVG: as an <img> Chrome drops most of an SVG this large.
    const scaled = svg
      .replace(/<\?xml[^>]*\?>|<!DOCTYPE[^>]*>/g, '')
      .replace(/(<svg[^>]*?)width="[\d.]+pt"\s+height="[\d.]+pt"/, `$1width="${pxWidth}" height="${pxHeight}"`);
    await page.setContent(`<body style="margin:0;background:#fff">${scaled}</body>`, { waitUntil: 'load', timeout: 120000 });
    await page.screenshot({ path: pngPath, clip: { x: 0, y: 0, width: pxWidth, height: pxHeight } });
  } finally {
    await browser.close();
  }
}

(async () => {
  const svg = svgFor(dotFor(dbmlPath));
  fs.mkdirSync(path.dirname(svgPath), { recursive: true });
  fs.mkdirSync(path.dirname(pngPath), { recursive: true });
  fs.writeFileSync(svgPath, svg);
  await rasterize(svg);
  console.log(`Wrote ${svgPath} and ${pngPath}`);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
