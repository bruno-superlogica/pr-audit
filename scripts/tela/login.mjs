// Login no ERP local pelo navegador de QA.
// Uso: node scripts/tela/login.mjs <licença> [destino]           usuário superlogica, sem senha (ex.: imob014729-001)
//      node scripts/tela/login.mjs testephpunit1 [destino] --teste  licença de teste do PHPUnit: entra por token,
//                                                                  como Auth::loginApps (o login normal dá "Url incorreta")
// destino: caminho (/imobiliaria/despesas/index) ou URL completa. Licença omitida = LIC_PADRAO da configuração.
import {execFileSync} from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {cfg, conectar, esperar, ocioso} from './comum.mjs';

const args = process.argv.slice(2);
const teste = args.includes('--teste');
const [licenca = cfg.LIC_PADRAO, destinoArg = '/imobiliaria/despesas/index'] = args.filter(a => a !== '--teste');
if (!licenca) { console.error('informe a licença (ex.: imob014729-001) ou configure LIC_PADRAO'); process.exit(1); }
const destino = destinoArg.startsWith('http') ? destinoArg : cfg.APPS_URL + destinoArg;
setTimeout(() => { console.log(JSON.stringify({erro: 'tempo esgotado (120 s)'})); process.exit(1); }, 120000).unref();

const {page} = await conectar();
const ir = async u => { await page.goto(u, {waitUntil: 'load', timeout: 60000}).catch(e => console.error(String(e.message).split('\n')[0])); await ocioso(page); };

let preencher;
if (teste) {
  if (!cfg.APPS_DIR) { console.error('APPS_DIR não configurado (precisa de tests/Imobiliarias/config.ini)'); process.exit(1); }
  const ini = fs.readFileSync(path.join(cfg.APPS_DIR, 'tests/Imobiliarias/config.ini'), 'utf8');
  const usuario = (ini.match(/^\s*username\s*=\s*['"]?([^'"\n]+)/m) || [])[1]?.trim();
  if (!usuario) { console.error('username não encontrado em tests/Imobiliarias/config.ini'); process.exit(1); }
  const token = crypto.randomBytes(20).toString('hex');
  const sql = `INSERT INTO \`${licenca}\`.TOKEN (ID_USUARIO_USU, ID_TOKEN_TK, DT_CRIACAO_TK) VALUES (1, '${token}', NOW()) ON DUPLICATE KEY UPDATE DT_CRIACAO_TK = NOW()`;
  execFileSync('docker', ['exec', cfg.CONTAINER_MYSQL, 'sh', '-c', `mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "${sql.replace(/`/g, '\\`')}"`], {stdio: ['ignore', 'ignore', 'ignore']});
  const q = new URLSearchParams({authtoken: token, licenca, filename: licenca, username: usuario, app_id: 'financeiro', id_appstore: '26'});
  await ir(`${cfg.APPS_URL}/imobiliaria/api/index/?${q}`);
  await esperar(1500);
  preencher = {modo: 'token'};
} else {
  await ir(cfg.APPS_URL + '/imobiliaria/auth/logout');
  await ir(destino);
  preencher = await page.evaluate(lic => {
    const q = s => document.querySelector(s);
    const email = q('input[name*=mail i], input[type=email], input[placeholder*=mail i], input[name*=usuario i], input[name*=login i]');
    const senha = q('input[type=password]');
    const l = q('input[name*=licen i], input[placeholder*=Licen]');
    if (!email || !l) return {erro: 'tela de login não encontrada', url: location.href.slice(0, 90)};
    const set = (el, v) => { el.focus(); el.value = v; el.dispatchEvent(new Event('input', {bubbles: true})); el.dispatchEvent(new Event('change', {bubbles: true})); };
    set(email, 'superlogica');
    if (senha) set(senha, '');
    set(l, lic);
    const b = [...document.querySelectorAll('button, input[type=submit]')].find(x => /Entrar/i.test(x.innerText || x.value));
    if (!b) return {erro: 'botão Entrar não encontrado'};
    b.click();
    return {ok: true};
  }, licenca);
  await esperar(2500);
  await ocioso(page, 20000);
}
if (!page.url().startsWith(destino)) await ir(destino);
const depois = await page.evaluate(() => ({
  url: location.href.slice(0, 100), titulo: document.title,
  licencaNaTela: (document.body.innerText.match(/[a-z]+\d*-001|testephpunit\d+/) || [])[0] || null,
  telaDeLogin: !!document.querySelector('input[type=password]'),
}));
console.log(JSON.stringify({licenca, preencher, depois}));
if (depois.telaDeLogin) console.log('Ainda na tela de login: confira a licença e se a base existe localmente.');
process.exit(0);
