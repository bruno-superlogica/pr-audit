# Tela com Playwright

Só quando o QA escolheu usar (SKILL.md, seção 3). O Playwright é gratuito e roda local; o custo é tempo e, no caso do MCP, tokens.

## Quando usar (para a recomendação ao QA)
- **Compensa:** o resultado depende da tela (botão, tag, mensagem, bloqueio, formulário, ícone de ação do grid); fluxo de vários cliques que precisa ser repetido em ANTES e DEPOIS ou com vários dados; componente reaproveitado em várias telas (despesas, contrato, imóvel, pessoa).
- **Não compensa:** teste de API ou endpoint; mensagens, filas, webhooks, cron; cálculo que se confere no banco; troca de texto simples; tela que o QA vai olhar de qualquer forma. Nesses, use PHPUnit, `q.sh` ou o roteiro manual.

## Dois jeitos
1. **Receita por script (padrão, mais barato).** A página não passa pelo modelo; o script devolve um resumo.
   ```
   node scripts/tela/navegador.mjs abrir           # navegador de QA próprio (porta QA_PORTA, padrão 9447)
   node scripts/tela/login.mjs imob014729-001       # ou testephpunit1 ... --teste
   node scripts/tela/qa.mjs goto /imobiliaria/despesas/index
   node scripts/tela/receita.mjs $QA_DIR/<CARD>/receitas/c1.json --objetivo "PERMITIR_SALVAR PERMITIR_CONFIRMAR" --log $QA_DIR/<CARD>/resultados/c1-depois.json
   node scripts/tela/navegador.mjs fechar           # no fim
   ```
   Comandos avulsos: `node scripts/tela/qa.mjs goto|url|texto|acoes|campos|clicar|preencher|selecionar|eval|evalf|box`.
2. **Playwright MCP (explorar tela nova).** O agente lê a página (árvore de acessibilidade) a cada passo: bom para descobrir o caminho, caro para repetir. Depois de achar o caminho, grave uma receita e use o jeito 1 para ANTES e DEPOIS. O MCP usa outro perfil de navegador (`~/.config/pr-audit/navegador-mcp`), com login próprio.

## Formato da receita
```json
{"nome": "c1-alterar-valor", "passos": [
  {"nome": "abrir", "acao": "clicar", "alvo": {"texto": "Alterar valor no a pagar"}, "depois": {"existe": "form[prefixoid$=\"alterarValorDespesaPrincipal\"]"}},
  {"nome": "valor", "acao": "preencher", "alvo": {"nome": "VL_VALOR_IMOD"}, "valor": "120"},
  {"nome": "salvar", "acao": "clicar", "alvo": {"texto": "Salvar"}, "depois": {"texto": "sucesso", "rede": "despesas/", "timeout": 20000}},
  {"nome": "evidencia", "acao": "eval", "codigo": "return document.querySelector('tr.selecionada')?.innerText"}
]}
```
- `acao`: `clicar`, `preencher`, `selecionar`, `marcar`, `eval` (JS na página; pode `return` evidência), `esperar` (`ms`).
- `alvo`: `seletor` > `nome` (atributo name) > `texto` (rótulo, `title`/`alt` de ícone; prioriza a linha com checkbox marcado). `passar`: seletor para passar o mouse antes (ícones que só aparecem no hover).
- `depois`: pós-condição `existe` (seletor visível), `texto`, `js` ou `rede` (regex da URL da resposta, que vai para o log), com `timeout`.
- `permitir: true` no passo libera um botão perigoso só ali; `continuarSeFalhar: true` não para a receita.
- Alvo não encontrado: a receita para e mostra os botões e campos visíveis para você corrigir o passo.
- Exemplos reais (cards já testados, ids de bases locais): `exemplos/receitas/`. Os campos `objetivoJev`/`maxJev` deles são do fluxo antigo e são ignorados.

## Regras
- Botões perigosos (`Salvar`, `Fechar`, `Alterar`, `Excluir`, `Estornar`, `Liquidar`, `Confirmar`, `Enviar`, `Atualizar`, `Sim`, `OK`) só com `PERMITIR_<RÓTULO>` no `--objetivo`.
- Diálogos nativos (`confirm`/`alert`) são aceitos automaticamente e registrados: clicar em "Excluir"/"Desfazer" **executa** a ação. Só clique quando ela faz parte do cenário.
- Espera é por evento (rede e DOM quietos); não use `sleep` fixo.
- Nunca revele o que está escondido por regra de negócio (ex.: checkbox que só aparece quando o valor muda) — isso é parte do que se testa.
- Prova é o banco: depois da receita, confira com `scripts/q.sh`.

## Armadilhas do ERP (Zend/jQuery)
- Handlers do grid são jQuery: se o clique nativo não chega, o script dispara `jQuery(el).trigger('click')`.
- Ícones de ação do grid (`a[acao]`, `title` na imagem) ficam `visibility:hidden` até passar o mouse — localize por `texto` (title) com a linha marcada, ou use `passar`.
- `jQuery.active` fica preso em 1 por requisição longa — não use para esperar.
- Autocomplete jQuery UI 1.8: `menu.activate/select`; confira os campos ocultos da linha antes de salvar.
- Checkbox estilizado: o input nativo fica `display:none` — confira a visibilidade pelo container (`.fl-diferenca-composicao` etc.).
- Diálogos de confirmação (swal) aparecem depois do submit — inclua passos para `Confirmar`/`Atualizar`. O swal pode continuar no DOM depois de salvar: confira pela lista ou pelo banco antes de clicar de novo (clique duplo = ação duplicada).
- Valor monetário com máscara: preencha só dígitos (`120` → 120,00); com vírgula a máscara multiplica. Confira o `value` do campo antes de salvar (`qa.mjs campos`).
- Campo de data abre calendário por cima do formulário: feche (`jQuery('.ui-datepicker').hide()` + `blur`).
- `select` com handler: `s.value='6'; jQuery(s).trigger('change')` por `eval` quando o `selecionar` não dispara a regra.
- Despesa partilhada usa outro fluxo (`LancamentosProgramados`), não "Alterar valor no a pagar".

## Rescisão de contrato
Wizard "Gerar cobrança proporcional" → "Mover despesas" → "Seguro" → confirmar. O ERP barra quando o contrato tem seguro ativo ("O contrato possui um seguro lançado, cancele-o para prosseguir") ou despesa de seguro pendente ("Despesa#X não pode ser excluída pois é referente ao seguro"). Escolha contrato sem seguro: `NOT EXISTS (SELECT 1 FROM SEGUROS s WHERE s.ID_CONTRATO_CON=c.ID_CONTRATO_CON AND s.DT_CANCELAMENTO_SEG IS NULL)` e sem `IMOVEIS_DESPESA` com `ID_SEGURO_SEG` ativo. Etapa de seguro: "Seguir sem seguro incêndio" (valor 0). Contrato que já foi a repasse: "Excluir despesa de diferença pendente" exclui só a diferença do locatário; a do proprietário fica pendente.
