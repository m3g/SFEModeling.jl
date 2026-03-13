## GUI implementation for SFEModeling — served via HTTP.jl + JSON3.jl

# ── Uploaded data cache ──────────────────────────────────────────────
const _gui_data   = Ref{Vector{Union{Nothing,Matrix{Float64}}}}([nothing])
const _gui_result = Ref{Any}(nothing)  # holds (ModelFitResult, curves) after a run

# ── HTML page ────────────────────────────────────────────────────────
const _GUI_HTML = raw"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>SFEModeling — Supercritical Extraction Fitting</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:system-ui,-apple-system,sans-serif;background:#f4f6fb;color:#23283a}
h1{text-align:center;padding:18px 0 6px;font-size:1.45rem;color:#1e3a5f}
.subtitle{text-align:center;color:#6b7280;font-size:.88rem;margin-bottom:10px}
.container{max-width:720px;margin:0 auto;padding:0 14px 40px}
fieldset{border:1px solid #d1d5db;border-radius:8px;padding:14px 16px;margin-bottom:14px;background:#fff}
legend{font-weight:600;font-size:.95rem;padding:0 6px;color:#1e3a5f}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:8px 16px}
label{font-size:.82rem;color:#4b5563;display:flex;flex-direction:column;gap:2px}
input[type=text],input[type=number],input[type=file]{
  border:1px solid #d1d5db;border-radius:4px;padding:5px 8px;font-size:.88rem;width:100%}
input:focus{outline:2px solid #3b82f6;border-color:transparent}
select{border:1px solid #d1d5db;border-radius:4px;padding:5px 8px;font-size:.88rem;width:100%;
  background:#fff;cursor:pointer}
select:focus{outline:2px solid #3b82f6;border-color:transparent}
button{cursor:pointer;border:none;border-radius:6px;padding:10px 28px;font-size:.95rem;
  font-weight:600;color:#fff;background:#2563eb;transition:background .15s}
button:hover{background:#1d4ed8}
button:disabled{background:#93c5fd;cursor:not-allowed}
.btn-row{text-align:center;margin:14px 0}
#status{text-align:center;margin:6px 0;font-size:.88rem;color:#4b5563;min-height:1.3em}
.dl-row{display:none;justify-content:center;gap:12px;margin:14px 0}
.dl-btn{display:inline-block;border-radius:6px;padding:9px 22px;font-size:.9rem;
  font-weight:600;color:#fff;background:#059669;text-decoration:none;transition:background .15s}
.dl-btn:hover{background:#047857}
table.preview{width:100%;border-collapse:collapse;font-size:.82rem;margin-top:8px}
table.preview th,table.preview td{border:1px solid #e5e7eb;padding:3px 6px;text-align:right}
table.preview th{background:#f3f4f6}
/* ── Main tabs ── */
.tabs{display:flex;border-bottom:2px solid #d1d5db;margin-bottom:16px}
.tab-btn{background:none;border:none;padding:10px 28px;font-size:.95rem;font-weight:600;
  color:#6b7280;cursor:pointer;border-bottom:3px solid transparent;margin-bottom:-2px;
  transition:color .15s,border-color .15s}
.tab-btn.active{color:#1e3a5f;border-bottom-color:#2563eb}
.tab-btn:hover:not(.active){color:#374151}
.tab-panel{display:none}
.tab-panel.active{display:block}
/* ── Curve sub-tabs ── */
.sub-tabs{display:flex;gap:4px;margin-bottom:12px;flex-wrap:wrap}
.sub-tab-btn{background:#f3f4f6;border:1px solid #d1d5db;border-radius:6px;
  padding:5px 14px;font-size:.85rem;font-weight:600;color:#4b5563;cursor:pointer;
  transition:background .12s,color .12s;color:#fff;background:none;border:none}
.sub-tab-btn{background:#f3f4f6;border:1px solid #d1d5db;border-radius:6px;
  padding:5px 16px;font-size:.88rem;font-weight:600;color:#4b5563;cursor:pointer}
.sub-tab-btn.active{background:#2563eb;color:#fff;border-color:#2563eb}
.sub-tab-btn:hover:not(.active){background:#e5e7eb}
.curve-panel{display:none}
.curve-panel.active{display:block}
/* ── Setup row ── */
.setup-row{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.setup-row label{flex-direction:row;align-items:center;gap:8px;font-size:.9rem;
  color:#374151;white-space:nowrap;font-weight:500}
.setup-row input[type=number]{width:64px}
/* ── Spinner ── */
#spinner{display:none;flex-direction:column;align-items:center;padding:60px 0;gap:20px}
.spin-ring{width:52px;height:52px;border:5px solid #e5e7eb;border-top-color:#2563eb;
  border-radius:50%;animation:spin .85s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
.spin-text{color:#4b5563;font-size:.95rem}
/* ── Output error ── */
#out-error{display:none;color:#dc2626;text-align:center;padding:20px;font-size:.9rem}
/* ── Cards ── */
.card{background:#fff;border:1px solid #d1d5db;border-radius:8px;
  padding:14px 16px;margin-bottom:14px}
.card-title{font-size:.93rem;font-weight:600;color:#1e3a5f;margin-bottom:10px}
.card.scrollable{overflow-x:auto}
/* ── Params table ── */
table.params{width:100%;border-collapse:collapse;font-size:.88rem}
table.params td{padding:5px 8px;border-bottom:1px solid #f3f4f6}
table.params tr:last-child td{border-bottom:none}
table.params td:first-child{color:#4b5563}
table.params td:nth-child(2){font-family:'Fira Code',monospace;font-weight:600;
  text-align:right;color:#1e3a5f}
table.params td:last-child{color:#9ca3af;font-size:.8rem;padding-left:8px;white-space:nowrap}
/* ── Data table ── */
table.data{width:100%;border-collapse:collapse;font-size:.82rem}
table.data th{background:#f3f4f6;padding:5px 10px;text-align:right;font-weight:600;
  color:#374151;white-space:nowrap;border-bottom:2px solid #e5e7eb}
table.data td{padding:4px 10px;text-align:right;border-bottom:1px solid #f3f4f6}
table.data tr:hover td{background:#fafafa}
.data-curve-hdr td{font-weight:700;color:#1e3a5f;background:#eff6ff !important;
  text-align:left !important;border-top:2px solid #bfdbfe}
/* ── Canvas ── */
#chart{display:block;width:100%;border-radius:8px;margin-bottom:14px}
</style>
</head>
<body>
<h1>SFEModeling &mdash; v__VERSION__</h1>
<p class="subtitle">Supercritical fluid extraction — multi-model curve fitting</p>

<div class="container">
<div class="tabs">
  <button class="tab-btn active" data-tab="data">Data</button>
  <button class="tab-btn"        data-tab="model">Model</button>
  <button class="tab-btn"        data-tab="results">Results</button>
</div>

<!-- ═══ DATA TAB ═════════════════════════════════════════════════ -->
<div id="tab-data" class="tab-panel active">

<fieldset>
<legend>Experiment Setup</legend>
<div class="setup-row">
  <label>Number of curves
    <input type="number" id="ncurves" min="1" max="10" value="1" style="width:64px"/>
  </label>
</div>
</fieldset>

<div class="sub-tabs" id="curve-tab-btns"></div>
<div id="curve-panels"></div>

<div id="status"></div>
<div class="btn-row">
  <button id="nextbtn" disabled>Next: Select Model →</button>
</div>

</div><!-- tab-data -->

<!-- ═══ MODEL TAB ════════════════════════════════════════════════ -->
<div id="tab-model" class="tab-panel">

<fieldset>
<legend>Model Selection</legend>
<label>Extraction model
  <select id="model-select">
    <option value="sovova" selected>Sovová (1994) — Broken and Intact Cells</option>
    <option value="shrinkingcore">Shrinking Core (1996) — physical diffusion/reaction</option>
    <option value="esquivel">Esquível (1999) — single exponential</option>
    <option value="zekovic">Zeković (2003) — accessible fraction + rate</option>
    <option value="pkm">PKM — Maksimovic (2012) — parallel reactions</option>
    <option value="spline">Spline (2003) — piecewise-linear CER/FER/DC</option>
  </select>
</label>
</fieldset>

<fieldset>
<legend>Optimizer Bounds</legend>
<div class="grid" id="bounds-grid">
  <!-- populated dynamically based on selected model -->
</div>
<div class="grid" style="margin-top:8px">
  <label>Max evaluations   <input type="number" id="maxevals" step="1" value="50000"/></label>
</div>
</fieldset>

<div class="btn-row">
  <button id="runbtn" disabled>Run Fitting</button>
</div>

</div><!-- tab-model -->

<!-- ═══ RESULTS TAB ═══════════════════════════════════════════════ -->
<div id="tab-results" class="tab-panel">

<div id="spinner">
  <div class="spin-ring"></div>
  <div class="spin-text">Running optimizer — this may take a minute…</div>
</div>

<div id="out-error"></div>

<div id="output-content" style="display:none">

  <div id="result-model" style="text-align:center;font-size:.88rem;color:#6b7280;margin-bottom:8px"></div>

  <canvas id="chart"></canvas>

  <div id="dlrow" class="dl-row">
    <a id="dl-txt"  href="/api/download?format=txt"  class="dl-btn" download="SFEModeling_results.txt">Download TXT</a>
    <a id="dl-xlsx" href="/api/download?format=xlsx" class="dl-btn" download="SFEModeling_results.xlsx">Download XLSX</a>
  </div>

  <div class="card">
    <div class="card-title">Fitted Parameters</div>
    <table class="params" id="params-table"></table>
  </div>

  <div class="card scrollable">
    <div class="card-title">Experimental vs Calculated</div>
    <table class="data" id="data-table"></table>
  </div>

</div><!-- output-content -->
</div><!-- tab-results -->

</div><!-- container -->
<script>
const $ = id => document.getElementById(id);

// ── Main tab switching ────────────────────────────────────────────
function showTab(name) {
  document.querySelectorAll('.tab-btn').forEach(b =>
    b.classList.toggle('active', b.dataset.tab === name));
  document.querySelectorAll('.tab-panel').forEach(p =>
    p.classList.toggle('active', p.id === 'tab-' + name));
}
document.querySelectorAll('.tab-btn').forEach(b =>
  b.addEventListener('click', () => showTab(b.dataset.tab)));
$('nextbtn').addEventListener('click', () => showTab('model'));

// ── Condition field definitions ───────────────────────────────────
const COND_FIELDS = [
  {id:'porosity',          label:'Porosity',               value:'0.4'},
  {id:'x0',               label:'x₀ (kg/kg)',             value:'0.05'},
  {id:'solid_density',    label:'Solid density (g/cm³)',  value:'1.1'},
  {id:'solvent_density',  label:'Solvent density (g/cm³)',value:'0.8'},
  {id:'flow_rate',        label:'Flow rate (cm³/min)',     value:'5.0'},
  {id:'bed_height',       label:'Bed height (cm)',         value:'20.0'},
  {id:'bed_diameter',     label:'Bed diameter (cm)',       value:'2.0'},
  {id:'particle_diameter',label:'Particle diam. (cm)',     value:'0.05'},
  {id:'solid_mass',       label:'Solid mass (g)',          value:'50.0'},
  {id:'solubility',       label:'Solubility (kg/kg)',      value:'0.005'},
];

// ── Curve state ───────────────────────────────────────────────────
let nCurves = 1;
let curveLoaded = [false];

function cid(ci, name) { return 'c' + ci + '_' + name; }

function buildCurvePanel(ci) {
  const condHtml = COND_FIELDS.map(f =>
    `<label>${f.label} <input type="number" id="${cid(ci,f.id)}" step="any" value="${f.value}"/></label>`
  ).join('');
  return `<div class="curve-panel${ci===0?' active':''}" id="cpanel${ci}">
<fieldset>
<legend>Experimental Data</legend>
<label><span>Data file (text or .xlsx) — <a href="/example_data.txt" download>example .txt</a> · <a href="/example_data.xlsx" download>example .xlsx</a></span>
  <input type="file" id="${cid(ci,'file')}" accept=".txt,.csv,.dat,.tsv,.xlsx"/>
</label>
<div id="${cid(ci,'preview')}"></div>
</fieldset>
<fieldset>
<legend>Operating Conditions</legend>
<div class="grid">${condHtml}</div>
</fieldset>
</div>`;
}

function buildCurveTabs() {
  $('curve-tab-btns').innerHTML = Array.from({length:nCurves}, (_,i) =>
    `<button class="sub-tab-btn${i===0?' active':''}" onclick="showCurveTab(${i})">Curve ${i+1}</button>`
  ).join('');
}

function showCurveTab(ci) {
  document.querySelectorAll('.sub-tab-btn').forEach((b,i) =>
    b.classList.toggle('active', i===ci));
  document.querySelectorAll('.curve-panel').forEach((p,i) =>
    p.classList.toggle('active', i===ci));
}

function updateReadyState() {
  const allReady = curveLoaded.slice(0, nCurves).every(v => v);
  $('nextbtn').disabled = !allReady;
  $('runbtn').disabled  = !allReady;
}

function attachFileListener(ci) {
  const inp = $(cid(ci, 'file'));
  if (!inp) return;
  inp.addEventListener('change', async e => {
    const file = e.target.files[0];
    if (!file) return;
    const formData = new FormData();
    formData.append('file', file);
    $('status').textContent = 'Uploading curve ' + (ci + 1) + '…';
    try {
      const res  = await fetch('/api/upload?curve=' + ci, {method:'POST', body:formData});
      const json = await res.json();
      if (json.error) { $('status').textContent = json.error; return; }
      curveLoaded[ci] = true;
      const rows  = json.data;
      const ncols = rows[0].length;
      let html = '<table class="preview"><tr><th>Time (min)</th>';
      for (let j = 1; j < ncols; j++) html += '<th>Rep ' + j + ' (g)</th>';
      html += '</tr>';
      const n = Math.min(rows.length, 3);
      for (let i = 0; i < n; i++) {
        html += '<tr>';
        for (let j = 0; j < ncols; j++) html += '<td>' + rows[i][j] + '</td>';
        html += '</tr>';
      }
      if (rows.length > n) html += '<tr><td colspan="' + ncols + '">… ' + (rows.length - n) + ' more rows</td></tr>';
      html += '</table>';
      $(cid(ci, 'preview')).innerHTML = html;
      $('status').textContent = 'Curve ' + (ci + 1) + ' loaded: ' + rows.length + ' rows × ' + rows[0].length + ' columns.';
      updateReadyState();
    } catch(err) { $('status').textContent = 'Upload failed: ' + err.message; }
  });
}

function setCurveCount(n) {
  n = Math.max(1, Math.min(10, n));
  nCurves = n;
  while (curveLoaded.length < n) curveLoaded.push(false);
  buildCurveTabs();
  $('curve-panels').innerHTML = Array.from({length:n}, (_,i) => buildCurvePanel(i)).join('');
  for (let i = 0; i < n; i++) attachFileListener(i);
  showCurveTab(0);
  updateReadyState();
}

// Initial setup
setCurveCount(1);
$('ncurves').addEventListener('change', e => setCurveCount(parseInt(e.target.value) || 1));
$('ncurves').addEventListener('input',  e => { const n = parseInt(e.target.value); if (n >= 1 && n <= 10) setCurveCount(n); });

// ── Current parameter specs for the selected model ────────────────
let currentSpecs = [];

async function updateBounds() {
  const model = $('model-select').value;
  try {
    const res   = await fetch('/api/model_params?model=' + encodeURIComponent(model));
    const specs = await res.json();
    currentSpecs = specs;
    let html = '';
    specs.forEach(s => {
      html += '<label>' + s.name + ' lower bound'
            + ' <input type="number" id="' + s.name + '_lo" step="any" value="' + s.lb + '"/></label>';
      html += '<label>' + s.name + ' upper bound'
            + ' <input type="number" id="' + s.name + '_hi" step="any" value="' + s.ub + '"/></label>';
    });
    $('bounds-grid').innerHTML = html;
  } catch(e) { console.error('Failed to load model params:', e); }
}
$('model-select').addEventListener('change', updateBounds);
updateBounds();

// ── Run fitting ──────────────────────────────────────────────────
$('runbtn').addEventListener('click', async () => {
  // Collect per-curve conditions
  const curves = [];
  for (let ci = 0; ci < nCurves; ci++) {
    const cond = {};
    for (const f of COND_FIELDS) {
      const v = parseFloat($(cid(ci, f.id)).value);
      if (isNaN(v)) { $('status').textContent = 'Invalid value for curve ' + (ci+1) + ': ' + f.id; return; }
      cond[f.id] = v;
    }
    curves.push(cond);
  }
  // Collect optimizer bounds
  const bounds = {};
  for (const s of currentSpecs) {
    const lo = parseFloat($(s.name + '_lo').value);
    const hi = parseFloat($(s.name + '_hi').value);
    if (isNaN(lo) || isNaN(hi)) { $('status').textContent = 'Invalid bounds for ' + s.name; return; }
    bounds[s.name + '_lo'] = lo;
    bounds[s.name + '_hi'] = hi;
  }
  const me = parseFloat($('maxevals').value);
  if (isNaN(me)) { $('status').textContent = 'Invalid max evaluations'; return; }

  const body = { model: $('model-select').value, maxevals: me, curves, ...bounds };
  $('runbtn').disabled = true;
  showTab('results');
  $('spinner').style.display        = 'flex';
  $('out-error').style.display      = 'none';
  $('output-content').style.display = 'none';
  try {
    const res  = await fetch('/api/run', {
      method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)
    });
    const json = await res.json();
    $('spinner').style.display = 'none';
    if (json.error) {
      $('out-error').textContent    = 'Error: ' + json.error;
      $('out-error').style.display  = 'block';
      $('runbtn').disabled = false;
      return;
    }
    $('output-content').style.display = 'block';
    $('result-model').textContent = 'Model: ' + json.model;
    renderParams(json.params);
    renderDataTable(json.charts);
    drawChart(json.charts);
    const _t = Date.now();
    $('dl-txt').href  = '/api/download?format=txt&_t='  + _t;
    $('dl-xlsx').href = '/api/download?format=xlsx&_t=' + _t;
    $('dlrow').style.display = 'flex';
  } catch(err) {
    $('spinner').style.display   = 'none';
    $('out-error').textContent   = 'Error: ' + err.message;
    $('out-error').style.display = 'block';
  }
  $('runbtn').disabled = false;
});

// ── Render fitted parameters table ───────────────────────────────
function renderParams(params) {
  $('params-table').innerHTML = params.map(p => {
    const v = typeof p.value === 'number'
      ? (Math.abs(p.value) < 0.01 || Math.abs(p.value) >= 1e4
         ? p.value.toExponential(4) : p.value.toPrecision(5))
      : String(p.value);
    return '<tr><td>' + p.name + '</td><td>' + v + '</td><td>' + (p.unit||'') + '</td></tr>';
  }).join('');
}

// ── Render exp vs calc data table ────────────────────────────────
function renderDataTable(charts) {
  let html = '';
  charts.forEach((ch, ci) => {
    const nr = ch.exp.length;
    if (charts.length > 1) {
      html += '<tr class="data-curve-hdr"><td colspan="99">Curve ' + (ci + 1) + '</td></tr>';
    }
    html += '<tr><th>Time (min)</th>';
    for (let j = 0; j < nr; j++)
      html += '<th>' + (nr > 1 ? 'Exp. rep. ' + (j+1) : 'Experimental') + ' (g)</th>';
    html += '<th>Calculated (g)</th></tr>';
    ch.t_min.forEach((t, i) => {
      html += '<tr><td>' + t.toFixed(2) + '</td>';
      ch.exp.forEach(rep => html += '<td>' + rep[i].toFixed(4) + '</td>');
      html += '<td>' + ch.cal[i].toFixed(4) + '</td></tr>';
    });
  });
  $('data-table').innerHTML = html;
}

// ── Extraction curve chart (vanilla Canvas) ───────────────────────
const CURVE_COLORS = ['#2563eb','#7c3aed','#059669','#dc2626','#d97706',
                      '#0891b2','#db2777','#65a30d','#ea580c','#8b5cf6'];

function drawChart(charts) {
  const canvas = $('chart');
  const dpr = window.devicePixelRatio || 1;
  const W   = canvas.offsetWidth;
  const H   = 300;
  canvas.width  = W * dpr;
  canvas.height = H * dpr;
  canvas.style.height = H + 'px';
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);

  const pad = {top:16, right:16, bottom:46, left:62};
  const pw = W - pad.left - pad.right;
  const ph = H - pad.top  - pad.bottom;

  const allT = charts.flatMap(ch => ch.t_min);
  const allY = charts.flatMap(ch => [...ch.cal, ...ch.exp.flat()]);
  const xMax = Math.max(...allT) * 1.04;
  const yMax = Math.max(...allY) * 1.08;
  const tx = x => pad.left + (x / xMax) * pw;
  const ty = y => pad.top  + ph - (y / yMax) * ph;

  ctx.fillStyle = '#fff';    ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = '#f9fafb'; ctx.fillRect(pad.left, pad.top, pw, ph);

  const NX = 5, NY = 4;
  ctx.strokeStyle = '#e5e7eb'; ctx.lineWidth = 1;
  for (let i = 0; i <= NX; i++) {
    const x = pad.left + i * pw / NX;
    ctx.beginPath(); ctx.moveTo(x, pad.top); ctx.lineTo(x, pad.top + ph); ctx.stroke();
  }
  for (let i = 0; i <= NY; i++) {
    const y = pad.top + i * ph / NY;
    ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(pad.left + pw, y); ctx.stroke();
  }

  ctx.fillStyle = '#374151'; ctx.font = '11px system-ui'; ctx.textAlign = 'center';
  for (let i = 0; i <= NX; i++)
    ctx.fillText((xMax * i / NX).toFixed(0), pad.left + i * pw / NX, pad.top + ph + 16);
  ctx.font = '12px system-ui';
  ctx.fillText('Time (min)', pad.left + pw / 2, H - 4);

  ctx.textAlign = 'right'; ctx.font = '11px system-ui';
  for (let i = 0; i <= NY; i++) {
    const val = yMax * (NY - i) / NY;
    ctx.fillText(val.toPrecision(3), pad.left - 6, pad.top + i * ph / NY + 4);
  }
  ctx.save();
  ctx.translate(11, pad.top + ph / 2);
  ctx.rotate(-Math.PI / 2);
  ctx.textAlign = 'center'; ctx.font = '12px system-ui';
  ctx.fillText('Extracted mass (g)', 0, 0);
  ctx.restore();

  ctx.strokeStyle = '#9ca3af'; ctx.lineWidth = 1;
  ctx.strokeRect(pad.left, pad.top, pw, ph);

  // Draw each curve
  charts.forEach((ch, ci) => {
    const color = CURVE_COLORS[ci % CURVE_COLORS.length];
    // Experimental dots (semi-transparent)
    ctx.fillStyle = color + '99';
    ch.exp.forEach(rep => {
      rep.forEach((y, i) => {
        ctx.beginPath(); ctx.arc(tx(ch.t_min[i]), ty(y), 4, 0, 2*Math.PI); ctx.fill();
      });
    });
    // Calculated line
    ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.lineJoin = 'round';
    ctx.beginPath();
    ch.t_min.forEach((t, i) => i === 0 ? ctx.moveTo(tx(t), ty(ch.cal[i]))
                                        : ctx.lineTo(tx(t), ty(ch.cal[i])));
    ctx.stroke();
  });

  // Legend
  const lx = pad.left + 10;
  let ly = pad.top + 8;
  ctx.font = '11px system-ui'; ctx.textAlign = 'left';
  charts.forEach((_, ci) => {
    const color = CURVE_COLORS[ci % CURVE_COLORS.length];
    const label = charts.length > 1 ? 'Curve ' + (ci + 1) : 'Calculated';
    ctx.strokeStyle = color; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(lx, ly + 5); ctx.lineTo(lx + 18, ly + 5); ctx.stroke();
    ctx.fillStyle = '#374151'; ctx.fillText(label, lx + 22, ly + 9);
    ly += 16;
  });
}

// ── Shutdown on window/tab close ─────────────────────────────────
window.addEventListener('beforeunload', () => navigator.sendBeacon('/api/shutdown'));

// ── Heartbeat: keep server alive while the page is open ──────────
setInterval(() => fetch('/api/ping', {method:'POST'}).catch(()=>{}), 5000);
</script>
</body>
</html>
"""

# ── Helper: parse multipart upload and return Matrix{Float64} ────
function _parse_upload(req::HTTP.Request)
    parts = HTTP.parse_multipart_form(req)
    isempty(parts) && error("No file received")
    part = first(parts)
    fname = lowercase(something(part.filename, "data.txt"))
    raw = read(part.data)  # IO → bytes

    if endswith(fname, ".xlsx")
        # Write to temp file and read with XLSX
        tmppath = tempname() * ".xlsx"
        try
            write(tmppath, raw)
            xf = XLSX.readxlsx(tmppath)
            ws = xf[1]
            cells = ws[:]
            # Auto-detect header: if first row has non-numeric values, skip it
            firstval = cells[1, 1]
            start = (firstval isa AbstractString && tryparse(Float64, firstval) === nothing) ? 2 : 1
            data = Float64.(cells[start:end, :])
        finally
            rm(tmppath; force=true)
        end
    else
        data = readdlm(IOBuffer(raw), Float64; comments=true)
    end
    return data
end

# ── App-mode browser launcher ────────────────────────────────────
# Try to open `url` in a Chromium-based browser using --app=URL so it
# appears as a frameless app window (no address bar, no tabs).
# Falls back to the system default browser if no Chromium browser is found.
#
# A per-port --user-data-dir is passed to Chromium so that each server
# instance gets its own browser process. Without this, a second launch
# hands control to the already-running Chromium process, which may just
# focus the existing window instead of opening a new one.
function _open_app_window(url::String)
    port_str   = split(url, ":")[end]
    profile_dir = joinpath(tempdir(), "sfemodeling_$port_str")
    mkpath(profile_dir)

    if Sys.iswindows()
        candidates = [
            joinpath(get(ENV, "ProgramFiles", "C:\\Program Files"),
                "Google\\Chrome\\Application\\chrome.exe"),
            joinpath(get(ENV, "ProgramFiles(x86)", "C:\\Program Files (x86)"),
                "Google\\Chrome\\Application\\chrome.exe"),
            joinpath(get(ENV, "ProgramFiles", "C:\\Program Files"),
                "Microsoft\\Edge\\Application\\msedge.exe"),
            joinpath(get(ENV, "ProgramFiles(x86)", "C:\\Program Files (x86)"),
                "Microsoft\\Edge\\Application\\msedge.exe"),
            joinpath(get(ENV, "LOCALAPPDATA", ""),
                "Google\\Chrome\\Application\\chrome.exe"),
        ]
        exe = findfirst(isfile, candidates)
        if exe !== nothing
            run(Cmd([candidates[exe], "--app=$url", "--user-data-dir=$profile_dir"]), wait=false)
        else
            run(`cmd /c start $url`, wait=false)
        end

    elseif Sys.isapple()
        candidates = [
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
            "/Applications/Chromium.app/Contents/MacOS/Chromium",
        ]
        exe = findfirst(isfile, candidates)
        if exe !== nothing
            run(Cmd([candidates[exe], "--app=$url", "--user-data-dir=$profile_dir"]), wait=false)
        else
            run(`open $url`, wait=false)
        end

    else  # Linux / BSD
        chromium_names = ["google-chrome", "google-chrome-stable",
                          "chromium-browser", "chromium",
                          "microsoft-edge", "microsoft-edge-stable",
                          "brave-browser"]
        found = nothing
        for c in chromium_names
            p = Sys.which(c)
            if p !== nothing
                found = p
                break
            end
        end
        if found !== nothing
            run(Cmd([found, "--app=$url", "--user-data-dir=$profile_dir"]), wait=false)
        else
            run(`xdg-open $url`, wait=false)
        end
    end
end

# ── Start GUI server ─────────────────────────────────────────────
function _start_gui(port::Int, launch::Bool)
    router = HTTP.Router()
    server_ref = Ref{Any}(nothing)
    last_ping  = Ref{Float64}(time())

    # Serve the HTML page (inject package version into the title)
    _versioned_html = replace(_GUI_HTML, "__VERSION__" => string(pkgversion(@__MODULE__)))
    HTTP.register!(router, "GET", "/", _ -> HTTP.Response(200, ["Content-Type" => "text/html"], _versioned_html))

    # File upload endpoint — accepts ?curve=N (0-indexed)
    HTTP.register!(router, "POST", "/api/upload", function(req)
        try
            # Parse curve index from query string (default 0)
            m = match(r"curve=(\d+)", req.target)
            ci = m !== nothing ? parse(Int, m.captures[1]) + 1 : 1  # 1-indexed for Julia

            data = _parse_upload(req)

            # Resize the data vector if needed
            while length(_gui_data[]) < ci
                push!(_gui_data[], nothing)
            end
            _gui_data[][ci] = data

            rows = [data[i, :] for i in 1:size(data, 1)]
            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(Dict("data" => rows)))
        catch e
            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(Dict("error" => sprint(showerror, e))))
        end
    end)

    # Model parameter specs endpoint
    HTTP.register!(router, "GET", "/api/model_params", function(req)
        try
            m = match(r"model=([^&]+)", req.target)
            model_name = m !== nothing ? String(m.captures[1]) : "sovova"
            model = model_from_name(model_name)
            spec = param_spec(model)
            result = [Dict("name" => s.name, "label" => s.label, "lb" => s.lb, "ub" => s.ub)
                      for s in spec]
            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(result))
        catch e
            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(Dict("error" => sprint(showerror, e))))
        end
    end)

    # Run fitting endpoint
    HTTP.register!(router, "POST", "/api/run", function(req)
        try
            p = JSON3.read(String(req.body))
            curve_conds = p[:curves]  # array of condition objects
            ncurves = length(curve_conds)

            # Validate that all curve data is uploaded
            gdata = _gui_data[]
            for ci in 1:ncurves
                if ci > length(gdata) || gdata[ci] === nothing
                    error("No data uploaded for curve $ci — upload a file first.")
                end
            end

            model_name = haskey(p, :model) ? String(p[:model]) : "sovova"
            maxevals   = Int(p[:maxevals])

            # Build ExtractionCurve objects
            curves = ExtractionCurve[
                ExtractionCurve(
                    data              = gdata[ci],
                    porosity          = Float64(curve_conds[ci][:porosity]),
                    x0                = Float64(curve_conds[ci][:x0]),
                    solid_density     = Float64(curve_conds[ci][:solid_density]),
                    solvent_density   = Float64(curve_conds[ci][:solvent_density]),
                    flow_rate         = Float64(curve_conds[ci][:flow_rate]),
                    bed_height        = Float64(curve_conds[ci][:bed_height]),
                    bed_diameter      = Float64(curve_conds[ci][:bed_diameter]),
                    particle_diameter = Float64(curve_conds[ci][:particle_diameter]),
                    solid_mass        = Float64(curve_conds[ci][:solid_mass]),
                    solubility        = Float64(curve_conds[ci][:solubility]),
                )
                for ci in 1:ncurves
            ]

            local result, params, charts
            if model_name == "sovova"
                result = fit_model(Sovova(), curves;
                    kya_bounds      = (Float64(p[:kya_lo]),       Float64(p[:kya_hi])),
                    kxa_bounds      = (Float64(p[:kxa_lo]),       Float64(p[:kxa_hi])),
                    xk_ratio_bounds = (Float64(p[:xk_ratio_lo]), Float64(p[:xk_ratio_hi])),
                    maxevals        = maxevals,
                    tracemode       = :silent,
                )
                params = vcat(
                    [Dict("name" => "xk/x₀", "value" => result.xk_ratio, "unit" => "")],
                    [Dict("name" => "kya[$i]", "value" => result.kya[i], "unit" => "1/s")
                     for i in 1:ncurves]...,
                    [Dict("name" => "kxa[$i]", "value" => result.kxa[i], "unit" => "1/s")
                     for i in 1:ncurves]...,
                    [Dict("name" => "tCER[$i]", "value" => result.tcer[i], "unit" => "s")
                     for i in 1:ncurves]...,
                    [Dict("name" => "SSR", "value" => result.objective, "unit" => "")],
                )
                charts = [begin
                    t_min, exps, cal, _ = _deinterleave(curves[i], result.ycal[i])
                    Dict("t_min" => t_min, "exp" => exps, "cal" => cal)
                end for i in 1:ncurves]
            else
                model = model_from_name(model_name)
                spec  = param_spec(model)
                pbounds = Tuple{Float64,Float64}[
                    (Float64(p[Symbol(s.name * "_lo")]), Float64(p[Symbol(s.name * "_hi")]))
                    for s in spec
                ]
                result = fit_model(model, curves;
                    param_bounds = pbounds,
                    maxevals     = maxevals,
                    tracemode    = :silent,
                )
                params = vcat(
                    [Dict("name" => s.name, "value" => result.params[i], "unit" => "")
                     for (i, s) in enumerate(result.spec)],
                    [Dict("name" => "SSR", "value" => result.objective, "unit" => "")],
                )
                charts = [begin
                    t_min, exps, cal, _ = _deinterleave(curves[i], result.ycal[i])
                    Dict("t_min" => t_min, "exp" => exps, "cal" => cal)
                end for i in 1:ncurves]
            end

            _gui_result[] = (result, curves)

            # Use the struct type name for display (e.g. "Sovova", "PKM")
            display_name = string(nameof(typeof(result.model)))

            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(Dict("charts" => charts, "params" => params, "model" => display_name)))
        catch e
            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(Dict("error" => sprint(showerror, e))))
        end
    end)

    # Heartbeat endpoint — browser pings every 5 s while the page is open
    HTTP.register!(router, "POST", "/api/ping", function(req)
        last_ping[] = time()
        return HTTP.Response(200, ["Content-Type" => "application/json"], "{}")
    end)

    # Shutdown endpoint — called via sendBeacon when the page unloads
    HTTP.register!(router, "POST", "/api/shutdown", function(req)
        @async begin
            sleep(0.1)
            srv = server_ref[]
            srv !== nothing && isopen(srv) && close(srv)
        end
        return HTTP.Response(200, ["Content-Type" => "application/json"], "{}")
    end)

    # Example data file downloads
    for (route, fname, mime) in (
        ("/example_data.txt",  "example_data.txt",  "text/plain"),
        ("/example_data.xlsx", "example_data.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
    )
        local fname, mime
        HTTP.register!(router, "GET", route, function(_)
            path = joinpath(pkgdir(@__MODULE__), "docs", "src", "assets", fname)
            isfile(path) || return HTTP.Response(404, "Example file not found")
            HTTP.Response(200,
                ["Content-Type" => mime, "Content-Disposition" => "attachment; filename=\"$fname\""],
                read(path))
        end)
    end

    # Download results endpoint
    HTTP.register!(router, "GET", "/api/download", function(req)
        cached = _gui_result[]
        cached === nothing && return HTTP.Response(400, "No results yet — run the fitting first.")
        result, curves = cached
        fmt = contains(req.target, "format=xlsx") ? "xlsx" : "txt"
        tmpfile = tempname() * "." * fmt
        try
            export_results(tmpfile, result, curves)
            body = read(tmpfile)
            mime = fmt == "xlsx" ?
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" :
                "text/plain; charset=utf-8"
            return HTTP.Response(200,
                ["Content-Type"        => mime,
                 "Content-Disposition" => "attachment; filename=\"SFEModeling_results.$fmt\"",
                 "Cache-Control"       => "no-store"],
                body)
        finally
            rm(tmpfile; force=true)
        end
    end)

    # Bind to the first available port starting from `port`
    server = nothing
    actual_port = port
    for p in port:(port + 100)
        try
            server = HTTP.serve!(router, HTTP.Sockets.localhost, p)
            actual_port = p
            break
        catch e
            occursin("address already in use", lowercase(sprint(showerror, e))) ||
                occursin("eaddrinuse", lowercase(sprint(showerror, e))) ||
                rethrow(e)
        end
    end
    server === nothing && error("Could not find a free port in range $(port)–$(port+100)")
    server_ref[] = server
    last_ping[]  = time()

    # Watchdog: shut down if no browser ping for more than 15 s
    @async begin
        while true
            sleep(5)
            srv = server_ref[]
            (srv === nothing || !isopen(srv)) && break
            if time() - last_ping[] > 15.0
                @info "No browser activity detected — shutting down server."
                close(srv)
                break
            end
        end
    end

    url = "http://127.0.0.1:$actual_port"
    actual_port != port && @info "Port $port was busy; using $actual_port instead"
    @info "SFEModeling GUI running at $url — press Ctrl-C to stop"

    if launch
        try
            _open_app_window(url)
        catch
            @info "Could not open browser automatically. Open $url manually."
        end
    end

    return server
end
