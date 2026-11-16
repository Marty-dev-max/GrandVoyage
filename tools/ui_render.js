// Renders the GUI-tree JSON dumped by tools/ui_harness.luau to PNG (approximates Roblox UI layout in HTML).
//   node tools/ui_render.js build/ui [backgroundImage]
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const dir = process.argv[2] || 'build/ui';
const bg = process.argv[3] || 'docs/screenshots/daybreak.png';
let W = 1600, H = 900, TOPBAR = 0;

const rgb = (c, a = 1) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;
const ud = (s, o) => (s === 0 ? `${o}px` : `calc(${(s * 100).toFixed(3)}% + ${o}px)`);

function richText(t) {
  return String(t).replace(/&/g, '&amp;').replace(/<(?!\/?(b|i|font)\b)/g, '&lt;')
    .replace(/<font color="#([0-9a-fA-F]{6})">/g, '<span style="color:#$1">').replace(/<\/font>/g, '</span>').replace(/\n/g, '<br>');
}

function render(n, parentLayout) {
  if (!n.Size && n.cls !== 'ScreenGui') return '';
  if (n.Visible === false) return '';
  if (n.name === 'Shine') return '';
  const mods = { corner: null, strokes: [], grad: null, pad: null, list: null, grid: null, scale: null, max: null };
  const kids = [];
  for (const c of (Array.isArray(n.children) ? n.children : [])) {
    if (c.cls === 'UICorner') mods.corner = c.radius;
    else if (c.cls === 'UIStroke') mods.strokes.push(c);
    else if (c.cls === 'UIGradient') { if (c.enabled !== false && !mods.grad) mods.grad = c; }
    else if (c.cls === 'UIPadding') mods.pad = c.pad;
    else if (c.cls === 'UIListLayout') mods.list = c;
    else if (c.cls === 'UIGridLayout') mods.grid = c;
    else if (c.cls === 'UIScale') mods.scale = c.scale;
    else if (c.cls === 'UITextSizeConstraint') mods.max = c.max;
    else kids.push(c);
  }
  kids.sort((a, b) => (a.LayoutOrder || 0) - (b.LayoutOrder || 0));
  const st = [];
  if (n.cls === 'ScreenGui') {
    st.push(`position:absolute;left:0;top:0;width:${W}px;height:${H}px`);
  } else {
    const [xs, xo, ys, yo] = n.Size, [px, po, py, pyo] = n.Position || [0, 0, 0, 0], [ax, ay] = n.AnchorPoint || [0, 0];
    const autoX = n.AutomaticSize === 'X' || n.AutomaticSize === 'XY', autoY = n.AutomaticSize === 'Y' || n.AutomaticSize === 'XY';
    if (parentLayout && parentLayout.cell) {
      // UIGridLayout forces every child to the cell size
      st.push(`width:${parentLayout.cell[0]}px;height:${parentLayout.cell[1]}px`);
    } else {
      st.push(autoX ? `min-width:${ud(xs, xo)};width:max-content` : `width:${ud(xs, xo)}`);
      st.push(autoY ? `min-height:${ud(ys, yo)};height:auto` : `height:${ud(ys, yo)}`);
    }
    if (parentLayout) {
      st.push('position:relative;flex:none');
    } else {
      st.push(`position:absolute;left:${ud(px, po)};top:${ud(py, pyo)}`);
    }
    const tf = [];
    if (!parentLayout && (ax || ay)) tf.push(`translate(${-ax * 100}%,${-ay * 100}%)`);
    if (n.Rotation) tf.push(`rotate(${n.Rotation}deg)`);
    if (mods.scale && mods.scale !== 1) tf.push(`scale(${mods.scale})`);
    if (tf.length) st.push(`transform:${tf.join(' ')}`);
    st.push(`z-index:${n.ZIndex || 1}`);
    const bgT = n.BackgroundTransparency ?? 0;
    if (bgT < 1) {
      const base = n.BackgroundColor3 || [255, 255, 255];
      if (mods.grad && mods.grad.colorSeq) {
        const stops = mods.grad.colorSeq.map(([t, c]) => `${rgb([c[0] * base[0] / 255, c[1] * base[1] / 255, c[2] * base[2] / 255].map(Math.round), 1 - bgT)} ${(t * 100).toFixed(1)}%`);
        st.push(`background:linear-gradient(${(mods.grad.rotation || 0) + 90}deg,${stops.join(',')})`);
      } else st.push(`background:${rgb(base, 1 - bgT)}`);
      if (mods.grad && mods.grad.transSeq && mods.grad.transSeq.some(([, v]) => v > 0.01)) {
        const ms = mods.grad.transSeq.map(([t, v]) => `rgba(0,0,0,${1 - v}) ${(t * 100).toFixed(1)}%`);
        st.push(`-webkit-mask-image:linear-gradient(${(mods.grad.rotation || 0) + 90}deg,${ms.join(',')})`);
      }
    }
    if (mods.corner) st.push(`border-radius:${mods.corner[0] ? mods.corner[0] * 100 + '%' : mods.corner[1] + 'px'}`);
    const border = mods.strokes.find(s => s.mode === 'Border' && s.enabled !== false);
    if (border) st.push(`box-shadow:0 0 0 ${border.thickness}px ${rgb(border.color, 1 - (border.transparency || 0))}`);
    if (n.ClipsDescendants || n.cls === 'ScrollingFrame') st.push('overflow:hidden');
  }
  if (mods.pad) st.push(`padding:${mods.pad[0]}px ${mods.pad[1]}px ${mods.pad[2]}px ${mods.pad[3]}px;box-sizing:border-box`);
  let layoutKind = null;
  if (mods.list) {
    layoutKind = 'list';
    const hz = mods.list.dir === 'Horizontal';
    const ha = { Left: 'flex-start', Center: 'center', Right: 'flex-end' }[mods.list.halign] || 'flex-start';
    const va = { Top: 'flex-start', Center: 'center', Bottom: 'flex-end' }[mods.list.valign] || 'flex-start';
    st.push(`display:flex;flex-direction:${hz ? 'row' : 'column'};gap:${mods.list.padding}px;${hz ? `justify-content:${ha};align-items:${va}` : `align-items:${ha};justify-content:${va}`}`);
  } else if (mods.grid) {
    layoutKind = 'grid';
    st.push(`display:flex;flex-wrap:wrap;gap:${mods.grid.cellPad[1]}px ${mods.grid.cellPad[0]}px;align-content:flex-start`);
  }
  let inner = '';
  if (n.Image) {
    // rbxassetid -> local PNG (icons / VFX textures we uploaded ourselves)
    const id = String(n.Image).replace('rbxassetid://', '');
    const file = IMAGE_FILES[id];
    if (file) {
      const tint = n.ImageColor3 ? `filter:drop-shadow(0 0 0 transparent);` : '';
      const op = 1 - (n.ImageTransparency || 0);
      inner += `<img src="data:image/png;base64,${file}" style="position:absolute;inset:0;width:100%;height:100%;object-fit:contain;opacity:${op};${tint}">`;
    }
  }
  const isText = n.Text !== undefined && n.cls !== 'ScreenGui';
  if (isText) {
    const ctx = mods.strokes.find(s => s.mode === 'Contextual' && s.enabled !== false);
    const font = n.FontFace && n.FontFace.includes('Fredoka') ? 'Fredoka One' : 'Inter';
    const weight = font === 'Inter' ? 800 : 400;
    const ta = { Left: 'left', Center: 'center', Right: 'right' }[n.TextXAlignment] || 'center';
    const va = { Top: 'flex-start', Center: 'center', Bottom: 'flex-end' }[n.TextYAlignment] || 'center';
    let textStroke = '';
    if (ctx) textStroke = `-webkit-text-stroke:${Math.min(ctx.thickness, 6)}px ${rgb(ctx.color)};paint-order:stroke fill;`;
    else if (n.TextStrokeTransparency !== undefined && n.TextStrokeTransparency < 1) textStroke = `-webkit-text-stroke:2px ${rgb(n.TextStrokeColor3 || [0, 0, 0])};paint-order:stroke fill;`;
    const txt = n.Text === '' && n.PlaceholderText ? `<span style="opacity:.5">${richText(n.PlaceholderText)}</span>` : richText(n.Text);
    inner += `<div class="t" data-scaled="${n.TextScaled ? 1 : 0}" data-max="${mods.max || 100}" style="position:absolute;inset:0;display:flex;align-items:${va};justify-content:${ta === 'left' ? 'flex-start' : ta === 'right' ? 'flex-end' : 'center'};text-align:${ta};font-family:'${font}','Noto Color Emoji';font-weight:${weight};font-size:${n.TextSize || 14}px;line-height:1.1;color:${rgb(n.TextColor3 || [0, 0, 0], 1 - (n.TextTransparency || 0))};${textStroke}white-space:${n.TextWrapped === false ? 'nowrap' : 'normal'};overflow:visible;z-index:${(n.ZIndex || 1) + 1}"><span>${txt}</span></div>`;
  }
  const childLayout = layoutKind === 'grid' ? { cell: mods.grid.cell } : layoutKind;
  for (const c of kids) inner += render(c, childLayout);
  return `<div data-name="${(n.name || '').replace(/"/g, '')}" style="${st.join(';')}">${inner}</div>`;
}

// map uploaded asset ids back to the local PNGs (assets/*/uploaded.json)
const IMAGE_FILES = {};
for (const folder of ['assets/icons', 'assets/vfx']) {
  const p = path.join(__dirname, '..', folder, 'uploaded.json');
  if (fs.existsSync(p)) {
    const m = JSON.parse(fs.readFileSync(p, 'utf8'));
    for (const [name, v] of Object.entries(m)) {
      const f = path.join(__dirname, '..', folder, name + '.png');
      if (fs.existsSync(f)) IMAGE_FILES[v.id] = fs.readFileSync(f).toString('base64');
    }
  }
}

(async () => {
  const index = JSON.parse(fs.readFileSync(path.join(dir, 'index.json'), 'utf8'));
  if (index.view) { W = index.view[0]; H = index.view[1]; }
  TOPBAR = index.topbar || 0;
  const font = fs.readFileSync(path.join(__dirname, 'fredoka-one.woff2')).toString('base64');
  const bgData = fs.existsSync(bg) ? `url(data:image/png;base64,${fs.readFileSync(bg).toString('base64')})` : '#7cc4ee';
  const browser = await chromium.launch();
  
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  for (const shot of index.shots) {
    const tree = JSON.parse(fs.readFileSync(path.join(dir, shot + '.json'), 'utf8'));
    const scale = Math.min(Math.max(H / 860, 0.55), 1.25);
    const html = `<!doctype html><html><head><style>
      @font-face{font-family:'Fredoka One';src:url(data:font/woff2;base64,${font}) format('woff2')}
      body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:${bgData} center/cover}
      #root{position:absolute;left:0;top:0;width:${W / scale}px;height:${H / scale}px;transform:scale(${scale});transform-origin:0 0}
      #root > div{width:100% !important;height:100% !important}
    </style></head><body><div id="root">${render(tree, null)}</div><div style="position:absolute;left:8px;top:${Math.max(4,(TOPBAR-40)/2)}px;display:flex;gap:6px;z-index:9999">${['R','☰','💬'].map(c=>`<div style="width:40px;height:40px;border-radius:12px;background:rgba(18,18,22,.75);color:#fff;font:700 18px sans-serif;display:flex;align-items:center;justify-content:center">${c}</div>`).join('')}</div></body></html>`;
    await page.setContent(html);
    await page.evaluate(() => document.fonts.ready);
    // TextScaled: shrink text until it fits its box
    await page.evaluate(() => {
      for (const t of document.querySelectorAll('.t[data-scaled="1"]')) {
        const box = t.parentElement.getBoundingClientRect();
        const max = +t.dataset.max;
        let size = Math.min(max, Math.max(8, box.height * 0.82));
        const span = t.firstElementChild;
        t.style.fontSize = size + 'px';
        let guard = 40;
        while (guard-- > 0 && size > 7 && (span.scrollWidth > box.width + 1 || span.getBoundingClientRect().height > box.height + 1)) {
          size *= 0.92; t.style.fontSize = size + 'px';
        }
      }
    });
    await page.screenshot({ path: path.join(dir, shot + '.png') });
    console.log('rendered', shot);
  }
  await browser.close();
})();
