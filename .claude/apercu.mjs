// Aperçu local sans risque : copie du site déconnectée de Supabase, remplie avec une copie des données.
//   node .claude/apercu.mjs           → reconstruit .apercu/index.html depuis index.html
//   node .claude/apercu.mjs --donnees → recopie aussi les données de production (lecture seule)
// Le site de test n'écrit que dans le navigateur (localStorage), jamais dans Supabase.
import {readFileSync, writeFileSync, mkdirSync, existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, '.apercu');
const dataFile = join(out, 'donnees.json');
mkdirSync(out, {recursive: true});

if (process.argv.includes('--donnees')) {
  const raw = execFileSync('supabase', ['db', 'query', '--remote=cflxwuiekkoegubjbiow', '--read-only', '-o', 'json',
    'select key, data from public.app_state'], {cwd: root, encoding: 'utf8', maxBuffer: 1 << 28});
  const json = JSON.parse(raw.slice(raw.indexOf('{')));
  const data = Object.fromEntries(json.rows.map(r => [r.key, typeof r.data === 'string' ? JSON.parse(r.data) : r.data]));
  writeFileSync(dataFile, JSON.stringify({copie: new Date().toISOString(), data}));
  console.log(`Données copiées : ${Object.keys(data).join(', ')}`);
}

let html = readFileSync(join(root, 'index.html'), 'utf8');
const re = /const SHARED_CONFIG = \{url: '[^']*', anonKey: '[^']*'\};/;
if (!re.test(html)) throw new Error('SHARED_CONFIG introuvable dans index.html');
html = html.replace(re, "const SHARED_CONFIG = {url: '', anonKey: ''}; // APERÇU LOCAL : aucune connexion à Supabase");

if (existsSync(dataFile)) {
  const {copie, data: d} = JSON.parse(readFileSync(dataFile, 'utf8'));
  const ls = {
    'rca.periods.v1': d.periods || [],
    'rca.settings.v2': d.settings || {},
    'rca.asv.v1': {models: d.asv?.models || [], entries: d.asv?.entries || [], settings: d.asvcfg || {}},
    'rca.plan.v1': d.planning || {},
    'rca.plancfg.v1': d.plancfg && Object.keys(d.plancfg).length ? d.plancfg : null,
    'rca.suivi.v1': d.suivi || {},
    'rca.cams.v1': d.cams || {},
    'rca.coach.v1': d.coaching || {},
  };
  // Chargé une seule fois par copie : les essais faits dans l'aperçu restent jusqu'à la prochaine copie.
  const seed = `<script>(() => { const id = ${JSON.stringify(copie)}; if (localStorage.getItem('rca.apercu') === id) return;
  ['rca.sync.cfg','rca.sync.session','rca.sync.meta'].forEach(k => localStorage.removeItem(k));
  const v = ${JSON.stringify(ls)}; for (const [k, x] of Object.entries(v)) localStorage.setItem(k, JSON.stringify(x));
  localStorage.setItem('rca.apercu', id); })();</script>\n`;
  html = html.replace('<script id="engine">', seed + '<script id="engine">');
}
writeFileSync(join(out, 'index.html'), html);

// Vérification de syntaxe des blocs <script> internes
const blocks = [...html.matchAll(/<script(?: id="engine")?>([\s\S]*?)<\/script>/g)].map(m => m[1]);
blocks.forEach((b, i) => { const f = join(out, `bloc${i}.js`); writeFileSync(f, b); execFileSync('node', ['--check', f]); });
console.log(`Aperçu prêt : .apercu/index.html (${blocks.length} blocs JS, syntaxe OK)${existsSync(dataFile) ? ' avec données' : ' sans données'}`);
