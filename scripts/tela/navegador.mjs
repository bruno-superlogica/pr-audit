// Navegador de QA próprio (Chromium do Playwright, perfil em ~/.config/pr-audit), com porta de depuração
// para os outros scripts conectarem. O login fica salvo no perfil entre sessões.
// Uso: node scripts/tela/navegador.mjs abrir [url]   abre (recusa se a porta estiver ocupada por outro processo)
//      node scripts/tela/navegador.mjs estado        mostra se está aberto e as abas
//      node scripts/tela/navegador.mjs fechar        fecha o navegador aberto por este script
// Variáveis: QA_PORTA (padrão 9447), TELA_HEADLESS=1 (sem janela), PR_AUDIT_CHROMIUM (outro executável).
import {spawn} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {chromium} from 'playwright-core';
import {cfg, CDP, CONFIG_DIR, esperar, navegadorAberto} from './comum.mjs';

const [cmd = 'estado', url] = process.argv.slice(2);
const perfil = path.join(CONFIG_DIR, `navegador-${cfg.QA_PORTA}`);
const arqPid = perfil + '.pid';

async function abas() {
  const lista = await (await fetch(CDP + '/json/list')).json();
  return lista.filter(t => t.type === 'page').map(t => t.url.slice(0, 120));
}

if (cmd === 'abrir') {
  if (await navegadorAberto()) {
    const meu = fs.existsSync(arqPid);
    console.log(meu ? `Já aberto na porta ${cfg.QA_PORTA}: ${JSON.stringify(await abas())}`
      : `Porta ${cfg.QA_PORTA} ocupada por outro navegador. Use outra: QA_PORTA=9448 node scripts/tela/navegador.mjs abrir`);
    process.exit(meu ? 0 : 1);
  }
  const exe = process.env.PR_AUDIT_CHROMIUM || chromium.executablePath();
  if (!fs.existsSync(exe)) { console.error(`Chromium não encontrado em ${exe}. Rode: npx playwright install chromium`); process.exit(2); }
  fs.mkdirSync(perfil, {recursive: true});
  const args = [`--remote-debugging-port=${cfg.QA_PORTA}`, `--user-data-dir=${perfil}`, '--no-first-run', '--no-default-browser-check',
    '--window-size=1470,880', '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding', '--disable-background-timer-throttling'];
  if (cfg.TELA_HEADLESS) args.push('--headless=new');
  if (process.getuid && process.getuid() === 0) args.push('--no-sandbox');
  args.push(url || cfg.APPS_URL + '/');
  const log = fs.openSync(perfil + '.log', 'a');
  const p = spawn(exe, args, {detached: true, stdio: ['ignore', log, log]});
  p.unref();
  fs.writeFileSync(arqPid, String(p.pid));
  for (let i = 0; i < 30 && !(await navegadorAberto()); i++) await esperar(500);
  if (!(await navegadorAberto())) { console.error(`Não abriu; veja ${perfil}.log`); process.exit(1); }
  console.log(`Navegador de QA aberto na porta ${cfg.QA_PORTA} (${cfg.TELA_HEADLESS ? 'sem janela' : 'com janela'}), perfil ${perfil}`);
  console.log('Próximo passo: node scripts/tela/login.mjs <licença>');
  process.exit(0);
} else if (cmd === 'estado') {
  if (!(await navegadorAberto())) { console.log(`Fechado (porta ${cfg.QA_PORTA}).`); process.exit(0); }
  console.log(`Aberto na porta ${cfg.QA_PORTA}${fs.existsSync(arqPid) ? '' : ' (não foi aberto por este script)'}. Abas: ${JSON.stringify(await abas())}`);
} else if (cmd === 'fechar') {
  if (!fs.existsSync(arqPid)) { console.log('Nenhum navegador aberto por este script nesta porta.'); process.exit(0); }
  const pid = +fs.readFileSync(arqPid, 'utf8');
  try { process.kill(pid, 'SIGTERM'); } catch {}
  fs.rmSync(arqPid, {force: true});
  console.log(`Navegador de QA (pid ${pid}) fechado.`);
} else {
  console.error('uso: navegador.mjs abrir [url] | estado | fechar');
  process.exit(1);
}
