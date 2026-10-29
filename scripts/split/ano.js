const alvo = window.__ANO;
for (let i = 0; i < 4; i++) {
  const t = document.getElementById('tituloGridCobrancas').textContent;
  if (t.includes(alvo)) break;
  const b = [...document.querySelectorAll('.paginacaoPorData a[comportamentos=recarregarCobrancas]')].find(a => /\d{4} >/.test(a.textContent));
  b.click();
  for (let k = 0; k < 40; k++) { await new Promise(r => setTimeout(r, 500)); if (!document.getElementById('tituloGridCobrancas').textContent.includes(t.match(/\d{4}/)[0])) break; }
  await new Promise(r => setTimeout(r, 2500));
}
return document.getElementById('tituloGridCobrancas').textContent;
