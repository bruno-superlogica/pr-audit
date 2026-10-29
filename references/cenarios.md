# Montar os cenários

No máximo ~8 cenários, priorizados. Cada um tem: objetivo, pré-condição de dado, resultado esperado verificável no banco ou na tela, e a fonte do esperado.

## 1. Do card
"Passos para reprodução", "Comportamento esperado", licença, ids (vistoria, contrato, despesa…), comentários de QA e de dev. Critérios de aceite viram cenários um a um.

## 2. Da PR
Seção "Como testar" da descrição (`pr.md`). Se o dev listou casos, todos entram.

## 3. Impacto (a maior dor — capriche)
Para cada símbolo alterado no `pr.diff` (função, método, form, campo, rota), procure quem usa:
- `git -C "$APPS_DIR" grep -n "<símbolo>"` em PHP, JS, templates e SQL; para conceito sem nome conhecido, procure palavras do domínio (ex.: "diferenca", "repasse") na pasta do módulo.
- Se a pessoa tiver `codegraph` instalado, `codegraph explore "<símbolos>"` mostra callers, telas e forms que reutilizam.

Pense em:
- outras telas e rotas que chamam o mesmo model, helper ou form (ex.: o mesmo form usado em criação e edição);
- variações de dado (cadastro feito pelo app x pela web, numeração diferente, acento, nulos, registro antigo sem vínculo);
- regressão: salvar sem alterar não duplica; excluir; editar de novo; validação de campo vazio; erro do backend;
- efeitos colaterais: histórico, auditoria, vínculos, status.

## 4. Leitores dos campos gravados (obrigatório quando a PR muda o que vai para o banco)
Para cada campo ou flag que a PR passa a gravar de outro jeito (valor novo de flag, campo preenchido onde antes era nulo, valor atualizado onde antes era mantido), liste **todos** os lugares que leem esse campo — não só os que comparam com igualdade:

`scripts/leitores.sh <CARD> <CAMPO> [CAMPO...]`

Os perigosos são os que testam "está ligado/preenchido" (`if ($x->FL_...)`, `!empty(...)`, `> 0`) e os que fazem conta com o campo (`VL_A + VL_B`): eles passam a rodar ou a calcular diferente. Para cada leitor anote o comportamento antes x depois; vira cenário quando mudar. Se dois leitores interpretam o mesmo campo de jeitos opostos (ex.: estorno subtrai a diferença do valor, liquidação soma), é bug até prova em contrário.

*Caso real (IMC-1959, 15/10/2026):* a PR passou a gravar `FL_ALTEROUVALOR = 2` e `VL_PAGTOINDEVIDO` na linha que já estava com o valor novo. Só os `== 1` foram conferidos; a validação da liquidação (`if FL_ALTEROUVALOR` → exige `VL_VALOR + VL_PAGTOINDEVIDO`) passou a rodar e a despesa não liquidava por valor nenhum. O defeito veio do IMC-1824 e foi replicado sem questionar: trate o código das PRs anteriores como suspeito, não como base correta.

## 5. Ciclo de vida completo (obrigatório)
O teste não para na tela que a PR mexeu. Leve o mesmo registro pelos passos seguintes do processo e confira cada um no banco e na tela:
- **Despesa/a pagar:** lançar → alterar → liquidar → repasse/CCDP → estornar → alterar de novo → liquidar de novo.
- **Cobrança:** gerar → liquidar → baixar/estornar → segunda via.
- **Contrato/repasse:** lançar → repassar → estornar repasse → repassar de novo.

Abriu um formulário de um passo seguinte (ex.: Liquidar) durante o teste? Conclua a ação e confira o resultado; não feche sem salvar.

## 6. Riscos que sempre entram na lista
- **Regras do cloud/financeiro:** o lançamento passa pelo financeiro (`caixa/put` etc.), que tem validações próprias (ex.: "Valor total da despesa não pode ser positivo" recusa repasse negativo). Leve o cenário até o lançamento no financeiro e confira o caixa gravado.
- **Clique duplo / reenvio:** submeta a mesma ação duas vezes seguidas; só pode existir um registro.
- **Centavos:** rateio com 3 beneficiários e valores que não dividem exato (ex.: 100,00 / 3); a soma das partes tem que bater com o total.
- **Falha no meio:** force um erro no meio do processo (bloqueio, dado inválido) e confira que nada ficou gravado pela metade.
- **Dados antigos:** registros criados antes da funcionalidade/tabela existir (ex.: histórico só existe desde a data X). Monte o cenário sem esse dado e veja o que a PR faz com ele.
- **Bloqueio novo / exceção:** se a PR passa a bloquear algo, confira a tela inteira: mensagem legível (sem `#id` interno), botões funcionando, dá para sair e voltar sem recarregar.
- **Controle sem a PR:** todo resultado estranho é rodado também sem o gatilho da PR (ex.: o mesmo repasse sem troca de proprietário). Se acontece igual, é comportamento que já existia: registre em "Não testado/limites", não como defeito da PR.
- **Varredura da base do cliente:** quando a PR muda um cálculo, rode a conta em **todos** os registros pendentes da base (ex.: 1ª tela = 2ª tela para os 122 proprietários com repasse pendente) e reporte `N de M` antes x depois. Script em loop gravando em arquivo; no contexto, só o agregado.

## 7. Revisão independente
Peça a outro agente, a outra sessão ou a outra pessoa: "o card bate com o código?", o rastreio dos leitores dos campos alterados (item 4) e o ciclo de vida (item 5). No relatório, separe o que ela relatou do que você conferiu.

## 8. Mostrar e seguir
Grave `plano-de-testes.md` a partir de `modelos/plano-de-testes.md`, mostre a lista ao QA numa mensagem curta e siga. Só espere aprovação se precisar de dado, login ou decisão (por exemplo, usar ou não o Playwright).
