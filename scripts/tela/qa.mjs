// Comandos avulsos no navegador de QA (precisa de navegador.mjs abrir). Cada comando imprime uma linha curta.
// Uso: node scripts/tela/qa.mjs <comando> [args]
//   goto <url|/caminho>        abre a página (caminho relativo usa APPS_URL)
//   url                        endereço atual e título
//   texto [--salvar arq] [N]   texto visível da página (N caracteres na tela, padrão 1500)
//   acoes                      botões/links/ícones e campos visíveis (para montar receita)
//   campos                     campos visíveis com valor (conferir formulário antes de salvar)
//   clicar <seletor|texto=Rótulo>
//   preencher <seletor> <valor>
//   selecionar <seletor> <valor>
//   eval <js|@arquivo.js>      roda JS na página (pode usar await e return)
//   evalf <js>                 roda JS em todos os frames (modais em iframe)
//   box <seletor>              centro do elemento em qualquer frame
// Diálogos nativos (confirm/alert) são ACEITOS e aparecem como "DIALOGO aceito: ..." — clicar em Excluir executa.
import fs from 'node:fs';
import path from 'node:path';
import {cfg, conectar, ocioso, inventario} from './comum.mjs';

const [cmd, a, b] = process.argv.slice(2);
if (!cmd) { console.error(fs.readFileSync(new URL(import.meta.url)).toString().split('\n').slice(0, 16).join('\n')); process.exit(1); }
const {page} = await conectar();
const alvo = s => s.startsWith('texto=') ? page.getByText(s.slice(6), {exact: true}).filter({visible: true}).last() : page.locator(s).filter({visible: true}).first();
let out;
try {
  if (cmd === 'goto') { await page.goto(a.startsWith('/') ? cfg.APPS_URL + a : a, {waitUntil: 'load', timeout: 60000}); await ocioso(page); out = page.url(); }
  else if (cmd === 'url') out = {url: page.url(), titulo: await page.title()};
  else if (cmd === 'texto') {
    const t = (await page.evaluate(() => document.body.innerText)).replace(/\n{3,}/g, '\n\n');
    if (a === '--salvar') { fs.mkdirSync(path.dirname(b), {recursive: true}); fs.writeFileSync(b, t); out = `${t.length} caracteres salvos em ${b}`; }
    else out = t.slice(0, +(a || 1500)) + (t.length > +(a || 1500) ? `\n... (${t.length} caracteres no total; use --salvar)` : '');
  }
  else if (cmd === 'acoes') out = await inventario(page, 60);
  else if (cmd === 'campos') out = (await inventario(page, 80)).campos;
  else if (cmd === 'clicar') { const l = alvo(a); try { await l.click({timeout: 8000}); } catch { await l.evaluate(e => window.jQuery ? window.jQuery(e).trigger('click') : e.click()); } await ocioso(page); out = 'ok'; }
  else if (cmd === 'preencher') { const l = alvo(a); await l.fill(String(b)); await l.dispatchEvent('change'); out = 'ok'; }
  else if (cmd === 'selecionar') { await alvo(a).selectOption(String(b)); out = 'ok'; }
  else if (cmd === 'eval' || cmd === 'evalf') {
    const js = a.startsWith('@') ? fs.readFileSync(a.slice(1), 'utf8') : a;
    if (cmd === 'eval') out = await page.evaluate(`(async()=>{${js}})()`);
    else { out = []; for (const f of page.frames()) { try { out.push(await f.evaluate(`(async()=>{${js}})()`)); } catch {} } }
  }
  else if (cmd === 'box') {
    let bb = null;
    for (const f of page.frames()) { bb = await f.locator(a).first().boundingBox({timeout: 1500}).catch(() => null); if (bb && bb.width) break; }
    out = bb ? [Math.round(bb.x + bb.width / 2), Math.round(bb.y + bb.height / 2)] : null;
  }
  else { console.error('comando desconhecido: ' + cmd); process.exit(1); }
} catch (e) { console.log('ERRO: ' + String(e.message || e).split('\n')[0].slice(0, 300)); process.exit(1); }
console.log(typeof out === 'string' ? out : JSON.stringify(out));
process.exit(0);
