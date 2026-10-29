// Preenche nova despesa no formulário aberto pelo contrato. Uso: node scripts/split/despesa.mjs <DDMMAAAA> <centavos> <serviço>
import {conectar} from '../tela/comum.mjs';
const {page} = await conectar();
const [data, valor, servico] = process.argv.slice(2);
await page.fill('[name=DT_LANCAMENTO_IMOD] >> visible=true', ''); await page.click('[name=DT_LANCAMENTO_IMOD] >> visible=true'); await page.keyboard.type(data); await page.keyboard.press('Escape');
await page.click('[name=VALOR] >> visible=true'); await page.keyboard.type(valor);
await page.click('[name=ST_DESCRICAO_PRD] >> visible=true'); await page.keyboard.type(servico, {delay: 80});
await page.waitForTimeout(2500);
const sug = page.locator('.ui-autocomplete li:visible, .typeahead li:visible, .tt-suggestion:visible').first();
if (await sug.count()) await sug.click(); else await page.keyboard.press('Enter');
await page.waitForTimeout(800);
await page.selectOption('[name=ID_DEBITO_IMOD] >> visible=true', '1');
await page.waitForTimeout(500);
await page.selectOption('[name=ID_CREDITO_IMOD] >> visible=true', '3');
await page.waitForTimeout(800);
console.log(JSON.stringify(await page.evaluate(() => [...document.querySelectorAll('input,select')].filter(e => e.getBoundingClientRect().width > 0 || /ID_PRODUTO/.test(e.name)).map(e => e.name + '=' + e.value).join(' ; '))));
process.exit(0);
