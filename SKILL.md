---
name: testar-pr
description: Apoio de QA para testar uma PR do apps (ERP imobiliário Superlógica). Monta cenários a partir do card do Jira, da PR e do impacto no código, gera plano e roteiro de teste, roda PHPUnit antes x depois, confere no banco local, executa passos de tela com Playwright quando o QA quiser e prepara o comentário de QA no card. Usar quando pedirem "testar a PR", "QA da PR", "validar o fix do card", "cenários de teste", "roteiro de teste", "cenários impactados" ou reproduzir bug de um card. Funciona com o acesso que o QA tiver; nenhum acesso é impeditivo.
---

# Testar PR

Os caminhos abaixo são relativos à pasta desta skill (onde está este `SKILL.md`). Rode os scripts por caminho completo, ex.: `<pasta-da-skill>/scripts/pr.sh`.

## Princípios
- Tudo em pt-BR, inclusive resumos e o fechamento.
- Quem prova o resultado é o banco e a tela conferidos. "Salvou" ou "passou" sem conferência não é prova.
- Só é problema da PR o que muda entre ANTES (código base) e DEPOIS (código da PR).
- Nada é impeditivo: sem um acesso, faça a versão manual e diga ao QA, em uma linha, o que ficou de fora.
- O QA decide o que é dele: usar ou não o Playwright, publicar no Jira, mexer em dados ou no ambiente.
- Economize tokens: os scripts gravam a saída completa em arquivo e mostram só o resumo. Leia inteiros só o card, a PR e o que for necessário para o cenário.
- Material do card fica em `$QA_DIR/<CARD>/` (padrão `~/qa-testes/<CARD>/`).

## 0. Diagnóstico (sempre o primeiro passo)
Rode `scripts/diagnostico.sh`. A última linha diz o que está disponível:

| Capacidade | Sem ela |
| --- | --- |
| `texto` (sempre) | — |
| `codigo` (projeto local) | Impacto só pelo texto do card/PR e pelo diff que o QA colar |
| `phpunit`, `banco` (Docker) | Sem PHPUnit; SQL de conferência vai no roteiro para o QA rodar onde tiver acesso |
| `gh` | PR lida pelo git; peça ao QA título e descrição ("Como testar") |
| `jira` | Peça o texto do card colado; o comentário sai em arquivo para colar |
| `tela` / `mcp` | Roteiro manual |
| `metabase` | Dados só das bases locais |

Diga ao QA em uma linha o que vai conseguir fazer. Sem configuração, sugira `./configurar.sh` e siga assim mesmo.

## Lista de tarefas (copie para a lista de tarefas do seu agente e mantenha atualizada)
Não declare o QA concluído com item aberto. Item que não se aplica: "não se aplica — <motivo>".
1. [ ] Versão da PR anotada (SHA testado). PR atualizada pelo dev → rode de novo só o DEPOIS na versão nova.
2. [ ] Cenários do card, da PR e de impacto; leitores dos campos; ciclo de vida; riscos fixos (seção 2).
3. [ ] Forma de execução combinada com o QA, incluindo se usa Playwright (seção 3).
4. [ ] PHPUnit antes x depois, quando houver Docker.
5. [ ] Controle sem a PR para todo comportamento estranho.
6. [ ] Varredura nos registros pendentes quando a PR muda cálculo.
7. [ ] Revisão independente (outro agente, outra sessão ou outra pessoa), com o relato dela separado do que foi conferido.
8. [ ] Todo problema com ❌/⚠️ e as 7 partes de `references/comentario-card.md`, incluindo "desde quando".
9. [ ] Comentário de QA: prévia → ok do QA → publicar (ou entregar o arquivo para colar).
10. [ ] Ambiente devolvido: `antes_depois.sh depois`, teste copiado para `tests/` removido, branch original, navegador de QA fechado se foi aberto por você.

## 1. Entrada
- PR (número) e card (chave). Sem card: tire do título ou da branch (`IMC-1234`, `SUI-12345`).
- `scripts/pr.sh <PR> <CARD>` → SHA testado, commit base, arquivos alterados, `pr.diff` e `pr.md`. Sem acesso ao GitHub: peça o link, a descrição e o diff ao QA.
- `scripts/jira.py card <CARD>` → `card.md` com descrição, comentários e anexos. Sem credenciais: peça ao QA para colar o card e salve em `card.md`.
- Leia `card.md` e `pr.md` inteiros: passos para reprodução, comportamento esperado, licença, ids, comentários de dev e QA, "Como testar".

## 2. Cenários (leia `references/cenarios.md` inteiro antes)
- No máximo ~8, priorizados. Cada um com objetivo, pré-condição de dado, resultado esperado verificável no banco ou na tela e a **fonte** do esperado (critério do card, comentário do dev, comportamento atual a manter ou "inferido" com o porquê).
- Fontes: card, "Como testar" da PR e **impacto** (a maior dor — capriche): quem mais chama o que mudou (`git grep` pelos símbolos do diff), variações de dado, regressão e efeitos colaterais.
- **Leitores dos campos:** se a PR muda o que vai para o banco, rode `scripts/leitores.sh <CARD> <CAMPO>...` e analise cada leitor perigoso (testa "ligado/preenchido" ou faz conta com o campo).
- **Ciclo de vida:** leve o mesmo registro pelos passos seguintes do processo (ex.: lançar → alterar → liquidar → repasse → estornar → alterar de novo).
- **Riscos fixos:** regras do financeiro/cloud, clique duplo, centavos, falha no meio, dados antigos, bloqueio novo, controle sem a PR, varredura.
- Grave `$QA_DIR/<CARD>/plano-de-testes.md` a partir de `modelos/plano-de-testes.md`. Mostre a lista ao QA numa mensagem curta e siga; só espere se precisar de dado, login ou decisão.

## 3. Combinar a execução com o QA (obrigatório antes de executar)
Para cada cenário (ou bloco de cenários parecidos), recomende uma forma e **pergunte ao QA se ele quer usar o Playwright**, dizendo o porquê. A decisão é do QA; siga o que ele escolher e não repita a pergunta a cada passo.

| Forma | Quando compensa | Quando não compensa |
| --- | --- | --- |
| PHPUnit (Docker) | Regra de negócio, cálculo, API, o que vai para o banco | Comportamento que só existe na tela |
| Playwright (tela) | Resultado depende da tela: botão, tag, mensagem, bloqueio, formulário, fluxo de vários cliques, componente reutilizado em várias telas; passos repetitivos (repetir antes x depois, vários dados) | Teste de API ou endpoint, mensagens, filas, webhooks, cron, cálculo que se confere no banco, troca de texto simples — é muito para pouco |
| Manual com roteiro | QA prefere executar, tela nova sem receita, ou sem Playwright/Docker | — |

Exemplo de pergunta: "O cenário 2 muda a tag na grade de despesas. Quer usar o Playwright para executar antes x depois? Recomendo sim, porque são 6 cliques repetidos nas duas versões. Os cenários 3 e 4 são de API e confiro pelo PHPUnit e pelo banco, sem tela."
Se `tela` não está nas capacidades, diga que não está disponível e siga com o roteiro manual (`modelos/roteiro-manual.md`), conferindo no banco o que o QA executar.

## 4. Dados do cenário e ambiente (leia `references/ambiente.md`)
Ordem: registro que já existe nas bases locais → gerar com `scripts/gerar_cenario.sh` (licença `testephpunitN`) → pedir ao QA. Nunca reinicie containers nem importe base sem avisar o QA.

## 5. PHPUnit (leia `references/phpunit.md`)
`scripts/rodar_phpunit.sh <CARD> <fase> <teste> [--destino tests/...]` — um teste por vez, no container, saída em `resultados/phpunit_<fase>.txt`. Rode cada cenário em ANTES e DEPOIS para preencher "Produção hoje" com número real.

## 6. Antes x depois
- `scripts/antes_depois.sh antes <CARD>` troca os arquivos da PR pela versão base; `scripts/antes_depois.sh depois <CARD>` devolve. O script recusa começar se os arquivos não estiverem na versão da PR.
- Nunca termine em ANTES. Interrompido? A primeira coisa é `antes_depois.sh depois <CARD>`.
- Front mudou → recarregue a tela e confirme a versão carregada. Form PHP não reflete → cache Zend local (ver `references/ambiente.md`).

## 7. Tela (só se o QA escolheu Playwright; leia `references/tela.md`)
- Padrão, mais barato: `node scripts/tela/navegador.mjs abrir` → `node scripts/tela/login.mjs <licença>` → `node scripts/tela/receita.mjs <receita.json> --objetivo "PERMITIR_SALVAR ..."`. A página não passa pelo modelo; a saída é um resumo e o log completo vai para arquivo.
- Tela nova sem receita: explore com `node scripts/tela/qa.mjs acoes|campos|texto` ou com o Playwright MCP (custa mais tokens por passo) e grave uma receita em `$QA_DIR/<CARD>/receitas/` para repetir antes x depois. Modelos em `exemplos/receitas/`.
- Botões perigosos (Salvar, Alterar, Excluir, Estornar, Liquidar, Confirmar…) só com `PERMITIR_<RÓTULO>` no objetivo. Diálogos nativos são aceitos: clicar em Excluir executa.
- Nunca revele na tela o que está escondido por regra de negócio; isso é parte do que se testa.

## 8. Verificar (por cenário)
- Banco antes e depois das tabelas afetadas com `scripts/q.sh --salvar $QA_DIR/<CARD>/resultados/<cenario>-<fase>.txt`; `AUDITORIA` (o save chegou ao servidor?); tabelas de histórico.
- Erros de console e respostas da API (estão no log da receita).
- Mudança visual: confira todas as telas que reaproveitam o componente.
- O QA mexeu no dado ("liquidei", "repassei")? Consulte de novo antes de rodar outra vez.
- O QA corrigiu a regra no meio? Rode de novo **todos** os cenários.

## 9. Encerrar
- `antes_depois.sh depois <CARD>` e `estado`; teste copiado removido; volte a branch anotada; `node scripts/tela/navegador.mjs fechar` se você abriu. Liste dados de teste que ficaram.
- Relatório curto em pt-BR: tabela `cenário | antes | depois | evidência`, o que não foi testado e por quê, o que é relato de agente x conferido por você.
- Comentário de QA (leia `references/comentario-card.md`): escreva `$QA_DIR/<CARD>/comentario-card.md` a partir de `modelos/comentario-card.md` → `scripts/jira.py comentar <CARD> <arquivo>` mostra a prévia → mostre ao QA → só com o ok dele, repita com `--confirmado` e anexe logs com `scripts/jira.py anexar <CARD> <arquivos> --confirmado`. Sem Jira: entregue o arquivo para colar.
- Problema fora do escopo da PR vira card próprio, no mesmo formato, com evidência.

## Referências (leia o arquivo inteiro antes de executar a etapa)
| Arquivo | Quando |
| --- | --- |
| `references/cenarios.md` | Sempre, antes de montar os cenários |
| `references/ambiente.md` | Docker, bases, login, dados do cenário, git |
| `references/phpunit.md` | Antes de rodar PHPUnit |
| `references/tela.md` | O QA escolheu Playwright |
| `references/comentario-card.md` | Ao escrever o comentário ou um card de problema |
| `references/estagio.md` | O QA pediu teste na estágio |
| `references/metabase.md` | Casos em lote em produção (precisa de Metabase) |
| `references/split.md` | Card ou PR de split, PJBank, repasse pelo split ou reprocessamento do Suporte |

PR de app Nexus (JS/TS): rode só a suíte afetada (`npx vitest run` com filtro pelos arquivos do diff); o restante do fluxo é o mesmo.
