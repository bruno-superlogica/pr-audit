// Gera carnê no formulário "Gerar carnê" já aberto no contrato. Uso: node scripts/split/carne.mjs <MM/AAAA> <meses>
import {conectar} from '../tela/comum.mjs';
const {page} = await conectar();
const [ini, meses] = process.argv.slice(2);
await page.fill('[name=dtInicio] >> visible=true', ''); await page.click('[name=dtInicio] >> visible=true'); await page.keyboard.type(ini); await page.keyboard.press('Tab');
await page.fill('[name=nm_meses] >> visible=true', ''); await page.click('[name=nm_meses] >> visible=true'); await page.keyboard.type(meses); await page.keyboard.press('Tab');
await page.waitForTimeout(1000);
console.log(await page.evaluate(() => [...document.querySelectorAll('input')].filter(e => e.getBoundingClientRect().width > 0).map(e => e.name + '=' + e.value).join(' ; ')));
await page.evaluate(() => { window.open = () => {}; });
await page.locator('button:has-text("Gerar") >> visible=true, input[value=Gerar] >> visible=true').first().click();
await page.waitForTimeout(30000);
process.exit(0);
