# Teste na estágio (só quando o QA pedir)

Exige permissões que nem todo QA tem (merge na branch `estagio`, login na estágio). Sem elas, diga isso e siga no ambiente local.

**Atenção:** a estágio usa o **banco de produção**. Cada clique grava dado real. Confira antes e depois (Metabase, se houver) e anote tudo que ficou (resíduos).

## Subir a PR
- A PR principal fica com a base que ela precisa (se depende de outra PR não mergeada, a base é a branch dessa outra).
- Para a estágio: branch a partir de `origin/estagio` num `git worktree` (não troque a branch do QA), `git cherry-pick <commit>`, PR para `estagio`. **Peça o ok do QA antes do merge.** O merge dispara o deploy (`cd-estagio-deploy.yml`): acompanhe com `gh run watch <id> --exit-status`.
- Logo depois do deploy a estágio responde **502 por 1–2 min**: espere e tente de novo; não conclua nada com 502.
- CI com "The runner has received a shutdown signal" = infraestrutura: espere terminar e `gh run rerun <id> --failed`.

## Dados
- Licença de teste `imoestagio` (schemas `app26_imoestagio` e `imoestagio`, sem `-001`).
- Procure o candidato com a pré-condição exata do card e já **limpo**: sem alteração anterior (`FL_ALTEROUVALOR_IMOD` nulo/0, `ID_PAGTOINDEVIDO_IMOD` nulo), sem diferença excluída antiga no contrato, contrato ativo e, se o roteiro rescinde, sem seguro (ver `references/tela.md`, Rescisão).
- Um contrato por cenário (o que rescinde não serve para o próximo). Anote os ids.

## Tela
- Navegador de QA em outra porta e apontado para a estágio: `QA_PORTA=9444 APPS_URL=<url da estágio> node scripts/tela/navegador.mjs abrir`. O login na estágio é do QA: peça para ele entrar nessa janela (com `TELA_HEADLESS=0`).
- Mesmas receitas e comandos, com as mesmas variáveis (`QA_PORTA`, `APPS_URL`).

## Fim
Liste os **resíduos** que ficaram na licença de teste (contrato rescindido, despesa alterada, diferença pendente).
