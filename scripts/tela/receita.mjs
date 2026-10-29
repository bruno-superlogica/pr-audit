// Executa uma receita (roteiro de tela em JSON) no navegador de QA, sem passar a página pelo modelo.
// Uso: node scripts/tela/receita.mjs <receita.json> [--objetivo "PERMITIR_SALVAR PERMITIR_CONFIRMAR"] [--log saida.json]
//
// Receita: {"nome": "...", "passos": [{nome, acao, alvo, valor, codigo, depois, permitir, continuarSeFalhar}]}
//   acao:  clicar | preencher | selecionar | marcar | eval (JS na página, pode "return" evidência) | esperar (ms)
//   alvo:  {seletor} > {nome} (atributo name) > {texto} (rótulo, title/alt de ícone; prioriza a linha com checkbox marcado)
//          {passar: seletor} passa o mouse antes (ícones de grid que só aparecem no hover)
//   depois: pós-condição {existe: seletor visível | texto | js | rede: regex da URL da resposta, timeout}
// Botões perigosos (Salvar, Alterar, Excluir, Estornar, Liquidar, Confirmar, Enviar, Atualizar, Sim, OK) só são
// clicados com PERMITIR_<ROTULO> no --objetivo ou "permitir": true no passo.
// Alvo não encontrado: a receita PARA e mostra o que existe na tela (acoes/campos) para o agente corrigir o passo.
// Saída: resumo curto na tela; log completo (passos, diálogos, erros de console, respostas POST) no arquivo --log.
import fs from 'node:fs';
import path from 'node:path';
import {cfg, conectar, ocioso, inventario} from './comum.mjs';

const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
if (!args[0] || !fs.existsSync(args[0])) { console.error('uso: receita.mjs <receita.json> [--objetivo "PERMITIR_..."] [--log saida.json]'); process.exit(1); }
const receita = JSON.parse(fs.readFileSync(args[0], 'utf8'));
const objetivo = opt('--objetivo', '');
const saida = opt('--log', path.join(cfg.QA_DIR, 'receitas-log', `${receita.nome || 'receita'}-${Date.now()}.json`));
const PERIGOSOS = /^\s*(Salvar|Fechar|Alterar|Excluir|Estornar|Liquidar|Confirmar|Enviar|Atualizar|Sim|OK)\s*$/i;

const {page, dialogos} = await conectar();
const erros = [];
page.on('pageerror', e => erros.push(String(e.message || e).slice(0, 300)));
page.on('console', m => { if (m.type() === 'error') erros.push(m.text().slice(0, 300)); });
const rede = [];
page.on('response', async r => {
  const req = r.request();
  if ((req.method() !== 'POST' && !/\/api\//.test(r.url())) || /clarity|notific|poll|analytics|announcekit|zendesk|telemetry/.test(r.url())) return;
  let corpo = ''; try { corpo = (await r.text()).slice(0, 2000); } catch {}
  rede.push({u: r.url().slice(0, 160), st: r.status(), b: corpo});
});

const porTexto = texto => page.evaluateHandle(t => {
  const vis = e => e && e.getClientRects().length > 0;
  const titulo = [...document.querySelectorAll('[title],[alt]')].filter(e => (e.getAttribute('title') || e.getAttribute('alt') || '').trim() === t && vis(e));
  const marcada = titulo.find(e => e.closest('tr')?.querySelector('input[type=checkbox]:checked'));
  if (marcada || titulo.length === 1) return marcada || titulo[0];
  const botoes = [...document.querySelectorAll('button,a,input[type=button],input[type=submit],label,span')]
    .filter(e => vis(e) && (e.innerText || e.value || '').trim() === t);
  return botoes[botoes.length - 1] || titulo[0] || null;
}, texto);

async function localizar(alvo) {
  if (alvo.passar) { const h = page.locator(alvo.passar).first(); if (await h.count()) { await h.scrollIntoViewIfNeeded().catch(() => {}); await h.hover().catch(() => {}); } }
  if (alvo.seletor) {
    const l = page.locator(alvo.seletor).filter({visible: true}).last(); if (await l.count()) return l.elementHandle();
    if (alvo.passar) { const o = page.locator(alvo.seletor).first(); if (await o.count()) return o.elementHandle(); }
  }
  if (alvo.nome) { const l = page.locator(`[name="${alvo.nome}"]`).first(); if (await l.count()) return l.elementHandle(); }
  if (alvo.texto) { const h = await porTexto(alvo.texto); if (await h.evaluate(e => !!e)) return h.asElement(); }
  return null;
}

// O ERP usa handlers jQuery: se o clique nativo não pegar, dispara pelo jQuery.
async function clicar(el) {
  try { await el.click({timeout: 5000}); return 'click'; }
  catch { await el.evaluate(e => window.jQuery ? window.jQuery(e).trigger('click') : e.click()); return 'jquery-click'; }
}

const log = [];
let parou = null;
for (const [i, p] of receita.passos.entries()) {
  const ini = Date.now();
  const reg = {i, passo: p.nome, acao: p.acao};
  try {
    await ocioso(page);
    const esperaRede = p.depois?.rede ? page.waitForResponse(r => new RegExp(p.depois.rede).test(r.url()), {timeout: p.depois.timeout || 60000}) : null;
    if (p.acao === 'eval') reg.resultado = await page.evaluate(`(async()=>{${p.codigo}})()`);
    else if (p.acao === 'esperar') await page.waitForTimeout(p.ms || 1000);
    else {
      const el = p.alvo ? await localizar(p.alvo) : null;
      if (!el) {
        reg.erro = 'alvo não encontrado: ' + JSON.stringify(p.alvo);
        reg.naTela = await inventario(page, 30);
        parou = reg;
      } else if (p.acao === 'preencher') { await el.fill(String(p.valor)); await el.dispatchEvent('change'); reg.resultado = 'preenchido'; }
      else if (p.acao === 'selecionar') { await el.selectOption(String(p.valor)); reg.resultado = 'selecionado'; }
      else if (p.acao === 'marcar') { await el.check({force: true}).catch(() => clicar(el)); reg.resultado = 'marcado'; }
      else {
        const rotulo = (await el.evaluate(e => (e.innerText || e.value || e.getAttribute('title') || '').trim())).slice(0, 40);
        if (PERIGOSOS.test(rotulo) && !p.permitir && !objetivo.toUpperCase().includes('PERMITIR_' + rotulo.toUpperCase())) {
          reg.erro = `botão perigoso "${rotulo}" sem PERMITIR_${rotulo.toUpperCase()} no --objetivo`;
          parou = reg;
        } else reg.resultado = await clicar(el);
      }
    }
    if (!reg.erro && p.depois) {
      const t = p.depois.timeout || 10000;
      if (p.depois.existe) await page.locator(p.depois.existe).filter({visible: true}).first().waitFor({timeout: t});
      if (p.depois.texto) await page.getByText(p.depois.texto).first().waitFor({timeout: t});
      if (p.depois.js) await page.waitForFunction(new Function('return ' + p.depois.js), null, {timeout: t});
      if (esperaRede) { const r = await esperaRede; reg.resposta = {u: r.url().slice(0, 160), st: r.status(), b: (await r.text().catch(() => '')).slice(0, 2000)}; }
      reg.posCondicao = true;
    }
  } catch (e) { reg.erro = String(e.message || e).split('\n')[0].slice(0, 300); reg.posCondicao = false; }
  reg.ms = Date.now() - ini;
  log.push(reg);
  if (reg.erro && !p.continuarSeFalhar) { parou = parou || reg; break; }
}
await ocioso(page);
fs.mkdirSync(path.dirname(saida), {recursive: true});
fs.writeFileSync(saida, JSON.stringify({receita: receita.nome, url: page.url(), log, dialogos, erros, rede}, null, 2));

console.log(`Receita ${receita.nome}: ${log.filter(r => !r.erro).length}/${receita.passos.length} passo(s) ok`);
for (const r of log) console.log(`  ${r.erro ? '❌' : '✅'} ${r.i} ${r.passo} (${r.ms} ms)${r.erro ? ' — ' + r.erro : ''}${r.acao === 'eval' && r.resultado !== undefined ? ' → ' + JSON.stringify(r.resultado).slice(0, 300) : ''}${r.resposta ? ` [resposta ${r.resposta.st}: ${r.resposta.b.slice(0, 150)}]` : ''}`);
if (parou?.naTela) console.log('Na tela agora: ' + JSON.stringify(parou.naTela).slice(0, 1500));
if (dialogos.length) console.log('Diálogos aceitos: ' + JSON.stringify(dialogos).slice(0, 500));
if (erros.length) console.log(`Erros de console: ${erros.length} (primeiro: ${erros[0].slice(0, 200)})`);
const falhasRede = rede.filter(r => r.st >= 400 || /"status"\s*:\s*"?(0|false|erro)/i.test(r.b));
console.log(`Respostas POST/API: ${rede.length}${falhasRede.length ? `, ${falhasRede.length} com erro (primeira: ${falhasRede[0].st} ${falhasRede[0].u})` : ''}`);
console.log(`Log completo: ${saida}`);
process.exit(parou ? 2 : 0);
