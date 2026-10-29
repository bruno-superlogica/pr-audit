// Configuração e conexão comuns aos scripts de tela.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {chromium} from 'playwright-core';

export const CONFIG_DIR = process.env.TESTAR_PR_CONFIG_DIR || path.join(os.homedir(), '.config', 'testar-pr');

function lerConfig() {
  const cfg = {};
  const arq = path.join(CONFIG_DIR, 'config.env');
  if (fs.existsSync(arq)) {
    for (const linha of fs.readFileSync(arq, 'utf8').split('\n')) {
      const m = linha.match(/^([A-Z_]+)=(.*)$/);
      if (!m) continue;
      let v = m[2].trim();
      if (v.startsWith("'") && v.endsWith("'")) v = v.slice(1, -1).replace(/'\\''/g, "'");
      cfg[m[1]] = v;
    }
  }
  return cfg;
}

const arquivo = lerConfig();
const pegar = (k, padrao) => process.env[k] || arquivo[k] || padrao;
export const cfg = {
  APPS_URL: pegar('APPS_URL', 'http://localhost:8080').replace(/\/$/, ''),
  APPS_DIR: pegar('APPS_DIR', ''),
  QA_DIR: pegar('QA_DIR', path.join(os.homedir(), 'qa-testes')).replace(/^~/, os.homedir()),
  QA_PORTA: pegar('QA_PORTA', '9447'),
  TELA_HEADLESS: pegar('TELA_HEADLESS', '0') === '1',
  LIC_PADRAO: pegar('LIC_PADRAO', ''),
  CONTAINER_MYSQL: pegar('CONTAINER_MYSQL', 'superlogica-mysql'),
};
export const CDP = `http://127.0.0.1:${cfg.QA_PORTA}`;

export const esperar = ms => new Promise(r => setTimeout(r, ms));

export async function navegadorAberto() {
  try { const r = await fetch(CDP + '/json/version', {signal: AbortSignal.timeout(2000)}); return r.ok; } catch { return false; }
}

// Conecta no navegador de QA aberto por navegador.mjs e devolve a aba do ERP.
export async function conectar({aba} = {}) {
  if (!(await navegadorAberto())) {
    console.error(`Navegador de QA não está aberto na porta ${cfg.QA_PORTA}. Rode: node scripts/tela/navegador.mjs abrir`);
    process.exit(3);
  }
  const browser = await chromium.connectOverCDP(CDP);
  const paginas = browser.contexts().flatMap(c => c.pages());
  const host = new URL(cfg.APPS_URL).host;
  const page = paginas.find(p => p.url().includes(aba || host)) || paginas[0] || await browser.contexts()[0].newPage();
  const dialogos = [];
  page.on('dialog', async d => { dialogos.push({tipo: d.type(), msg: d.message()}); console.error('DIALOGO aceito:', d.message()); await d.accept().catch(() => {}); });
  return {browser, page, dialogos};
}

// Espera a página sossegar: carregamento, rede (sem travar em long-poll) e DOM quieto por 250 ms.
export async function ocioso(page, max = 8000) {
  await page.waitForLoadState('domcontentloaded', {timeout: max}).catch(() => {});
  await page.waitForLoadState('networkidle', {timeout: Math.min(max, 5000)}).catch(() => {});
  await page.evaluate(lim => new Promise(ok => {
    let t = setTimeout(fim, 250); const ini = Date.now();
    const obs = new MutationObserver(() => { clearTimeout(t); if (Date.now() - ini > lim) fim(); else t = setTimeout(fim, 250); });
    function fim() { obs.disconnect(); ok(); }
    obs.observe(document.documentElement, {subtree: true, childList: true, attributes: true, characterData: true});
  }), 3000).catch(() => {});
}

// Lista resumida do que dá para clicar/preencher na tela (para corrigir uma receita ou montar uma nova).
export async function inventario(page, limite = 40) {
  return page.evaluate(lim => {
    const vis = e => e.getClientRects().length > 0 && getComputedStyle(e).visibility !== 'hidden';
    const txt = e => (e.getAttribute('title') || e.getAttribute('alt') || e.getAttribute('aria-label') || e.innerText || e.value || '').replace(/\s+/g, ' ').trim().slice(0, 60);
    const acoes = [...document.querySelectorAll('button,a,input[type=button],input[type=submit],[title],[role=button]')]
      .filter(vis).map(txt).filter(Boolean);
    const campos = [...document.querySelectorAll('input:not([type=hidden]),select,textarea')]
      .filter(vis).map(e => `${e.name || e.id || '?'}=${e.type === 'checkbox' ? e.checked : (e.value || '').slice(0, 30)}`);
    return {acoes: [...new Set(acoes)].slice(0, lim), campos: campos.slice(0, lim)};
  }, limite);
}
