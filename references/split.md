# Cenários de split (PJBank) no ambiente local

Use este guia sempre que o card ou a PR falar de split, PJBank, "Split agendado/liquidado/com erro", repasse pelo split, webhook `boleto_liquidado` ou reprocessamento do Suporte. Foi montado nos testes do IMC-1798 (15 e 16/10/2026). Os scripts ficam em `scripts/split/` e precisam de `LIC` definida (ex.: `export LIC=adouglas01-001 CONTRATO=419`) e do navegador de QA logado nessa licença.

## 1. Preparação (uma vez por sessão)
1. **Licença do sandbox.** A licença precisa estar em `_licencasSandbox` do `cloud/todos-atual/application/Shared/Helpers/Facilitador.php`; a `adouglas01-001` já está. Base local nos schemas `adouglas01-001` (financeiro) e `app26_adouglas01-001` (imob).
2. **Conta do PJBank.** A conta usada no contrato precisa de credencial de sandbox. Se der "Credencial não localizada", zere `CONTA_BANCO.ST_TOKEN_CB` dessa conta (anote o valor original) e registre de novo: o PJBank cria a credencial nova.
3. **Navegador de QA.** `node scripts/tela/navegador.mjs abrir` e `node scripts/tela/login.mjs adouglas01-001`, depois `export LIC=adouglas01-001 CONTRATO=419`. Se a tela mostrar outra licença ou página, confira com `node scripts/tela/qa.mjs url` antes de seguir.
4. **Contrato de teste.** Contrato com "Pagamento automático via Split (com PJBank)", proprietário com conta de split ativa (`PROPRIETARIOS_BENEFICIARIOS.ID_PROPSPLIT_PST`) e vigência longa (se precisar, estenda `CONTRATOS.DT_FIM_CON` e anote). Na adouglas01: contrato 419, imóvel 268, proprietário Bento (pessoa 282), aluguel 8.000, taxa 10%, split 7.200, cobrança 8.093,50 (tem opcional de 90 e taxa bancária de 3,50).
5. Anote tudo que mudar fora da tela (configs, tokens, datas) em `alteracoes-locais.txt` e desfaça no fim.

## 2. Ciclo de uma cobrança com split
Ordem combinada na reunião de 15/10.
1. **Gerar a cobrança.** Contrato › Ações › Gerar carnê. As cobranças do dump têm nosso número de produção e não existem no sandbox: sempre gere nova. Por script: abra o formulário e rode `node scripts/split/carne.mjs <MM/AAAA> <meses>`, ou preencha `dtInicio`/`nm_meses` via JS (a máscara não aceita digitação) e dispare o botão Gerar com `window.confirm=()=>true`.
2. **Criar o split.** `scripts/split/sb.sh cron 3` (roda `cron/criarwebhooks` + `cron/webhooks` com `forcarProcessamento=1` pelo proxy). Confira: `scripts/split/sb.sh estado <id>` mostra o split no financeiro (`SPLIT`) e no imob (`app26.SPLIT`, status 1 = agendado). Itens do split: `app26.SPLIT_DESPESAS`.
3. **Registrar.** `scripts/split/sb.sh registrar <id>` (rota de teste `verticalimobiliarias/registrarsplitlocal`). `FL_REMESSASTATUSCR_RECB` vai para 2.
4. **Pagar.** `scripts/split/sb.sh liquidar <id> <valor com ponto> <dt liquidação m/d/Y> <dt crédito m/d/Y>`. Com vírgula o PJBank trunca o valor. O retorno gera `boleto_liquidado` na `WEBHOOKS_QUEUE` com `dados_split.status = -1` (o sandbox nunca divide o dinheiro).
5. **Simular split pago.** `scripts/split/pago.sh <id da fila>` troca o status para 1 no JSON (com `ensure_ascii` e `\/`, senão o hook recebe string).
6. **Processar com tentativas.** `scripts/split/sb.sh cron 2` e depois `scripts/split/sb.sh retry` até 5 vezes. Na 5ª tentativa o ERP pede cancelamento ao PJBank (o sandbox aceita → "Split com erro" + "Repasse pendente").
   Atalho para 4 a 6: `scripts/split/ciclo.sh <id> <valor> <dtliq> <dtcred>`.
7. **Conferir.** `scripts/split/sb.sh estado <id>` e o motivo em `app26.SPLIT_ERROS` (`ST_DESCERRO_SPE`, `ST_CATEGORIA_SPE`). Status do split no imob: 1 agendado, 2 concluído, 3 cancelado. No financeiro: -1 recusado, 0, 1 pago, 2.

**Segurar a baixa** (cenários de "mudou depois do pagamento"): depois do `liquidar`, marque o `boleto_liquidado` com `FL_STATUS_WHQ=1`, faça a mudança pela tela e volte para 0 antes do `cron`. Webhooks gerados pela mudança (ex.: `hooks_split`, `validar_split`, `atualizarsplit_pjbank`) entram na fila depois do `boleto_liquidado`; se o cenário precisar deles antes, processe-os com a baixa segurada.

**"Já foi paga":** o sandbox aceita o cancelamento. Para simular a recusa, stub temporário em `imobiliaria/Helpers/PJBank.php` (~465) lendo `/tmp/qa_stub_ja_paga` no container — só com o ok do QA, anotado em `alteracoes-locais.txt`; reverta com `git checkout`.

## 3. Onde ficam as coisas na tela
- **Grade de cobranças do contrato:** página do contrato, painel "Cobranças do contrato em <ano>". Troque o ano com `node scripts/tela/qa.mjs eval "window.__ANO='2028'; $(cat scripts/split/ano.js)"`. A tela "Mais opções" leva ao financeiro (3059), que pede outro login.
- **Resultado:** clicar na tag "Split com erro" abre "Detalhes do Split", com o valor programado x calculado e a conta do proprietário. É a melhor evidência de tela (`node scripts/tela/qa.mjs texto` depois de abrir o modal).
- **Configurações › Repasse:** engrenagem de `repasses/index` ("Calcular taxa de administração usando os valores de juros e multa", "Valor da tarifa de DOC/TED", "Desconto de pontualidade no repasse garantido").
- **Configurações › Beta:** `/imobiliaria/configuracoes/index` › engrenagem ("Desconto de pontualidade descontar do aluguel sempre", "Não exibir composição de desconto"). Só Suporte em produção.
- **Alterar contrato:** Contrato › "Alterar contrato" › avance até "Repasse do aluguel" (taxa de administração, "Cobrar tarifa bancária de DOC/TED"). O radio de split aparece desabilitado e desmarcado no local mesmo com `FL_SPLIT_CON=1` (limitação do ambiente local, não defeito).
- **Conta do proprietário:** `proprietarios/id/<pessoa>` › lápis › "Habilitar edição dos campos sensíveis". Salvar demora; a troca da conta de split só acontece quando o `hooks_split` roda.
- **Despesas do mês:** `despesas/index?dtInicioMensal=MM/01/AAAA&dtFimMensal=MM/31/AAAA`; editar pelo ícone da linha (aparece no hover). Nova despesa pelo contrato: `node scripts/split/despesa.mjs <DDMMAAAA> <centavos> <serviço>`; a data às vezes grava como hoje, então confira e ajuste.
- **Repasses:** `repasses/index?dtInicio=...&dtFim=...` (a realizar) e `&status=repassados` (realizados, com "Desfazer repasse").

## 4. Travas e caminhos do Suporte
- Despesa no split (`ST_SPLIT_IMOD`): alterar valor, data, competência ou excluir é bloqueado ("Já faz parte de um Split programado"). **Trocar débito/crédito passa** e o split fica desatualizado.
- `suporte/desvinculartagsplit?idRecebimento=<id>&force=1`: só age com split ativo (status 1). Com repasse vinculado à cobrança dá "Para continuar é necessário desfazer o repasse da cobrança". Com cobrança paga, estorna a cobrança e cria o registro em `RETORNO_ESTORNADO`.
- Nova baixa depois disso: `retorno/reliquidar` pelo proxy com `{ID_RETORNO_RETI: <id original>, REPROCESSAR_SEM_ESTORNO: 1}` (é o passo 3 do `estornosplitAction`).
- `suporte/desfazerrepasse?id=<cobrança>`: estorna a movimentação no financeiro e desfaz o repasse.
- O reprocessamento "de verdade" do Suporte (`retorno/reprocessaritem` com usuário Suporte → hook `estorno_split`) não roda pelo proxy local (sessão não é Suporte). **Não enfileire `estorno_split` à mão:** sem o registro em `RETORNO_ESTORNADO` a reliquidação falha e a cobrança fica estornada (a 1786 da adouglas01 ficou assim).
- Desde o PR #22599 (13/10/2026) o reprocessamento não estorna repasse manual lançado.
- Estornar o pagamento de um repasse leva ao caixa do financeiro (3059, outro login).

## 5. Armadilhas do sandbox
- Liquidar com valor maior no próprio vencimento falha calado e deixa a cobrança "já liquidada" no PJBank sem retorno. Pagamento com juros: use data de liquidação depois do vencimento.
- "Arquivo retorno já processado": outro teste já processou o retorno daquela data de crédito. Apague a linha da `RETORNO` daquele dia (`ST_NOME_RET` tem a data) ou use outra data de crédito. Não repita data de crédito entre cenários.
- "Outro processo está realizando essa operação": trava de 10 min do retorno daquela data; espere ou use outra data.
- A rota `liquidarsplitlocal` esconde o erro do PJBank ("Wrong parameters for Exception"). Para ver a mensagem, troque temporariamente `throw new Exception($api_retorno)` por `json_encode($api_retorno)` no `Facilitador::liquidarTeste` e reverta no fim.
- Cobrança clonada ou estornada pode soltar despesas que entram no split da próxima cobrança. Confira `SPLIT_DESPESAS` antes de concluir a causa de uma diferença.

## 6. Controle e causa raiz
- **Um card por causa raiz.** O card começa pela condição ou configuração (tela e rótulo), depois a ação que dispara, o resultado errado e como deveria ser.
- **Prova de controle obrigatória** para atribuir a causa: rode a mesma cobrança sem o gatilho (ex.: config sem mudança, pagamento com o mesmo atraso). Se o controle também falhar, a causa é outra (no IMC-1974 o controle na 1775 liquidou normal e confirmou a causa).
- Antes de afirmar "não reproduz", procure no código a trava que impede (`git log -S`) e diga desde quando ela existe. Passo a passo do card que não reproduz pela tela é corrigido no card (IMC-1975: valor e exclusão bloqueados, débito/crédito reproduz).

## 7. Cenários já montados (adouglas01, contrato 419)
| Card | Gatilho | Resultado |
|---|---|---|
| IMC-1972 | Alterar contrato: taxa 10% → 12% antes do pagamento | Split 7.200 x baixa 7.040, "Split com erro" |
| IMC-1973 | Alterar contrato: marcar "Cobrar tarifa bancária de DOC/TED" | 7.200 x 7.190 |
| IMC-1974 | Desmarcar "Calcular taxa ... juros e multa" + pagar com 31 dias de atraso | 7.047,61 x 7.091,72; controle liquida |
| IMC-1975 | Despesa de 300 débito proprietário no split → trocar para débito imobiliária/crédito proprietário | 7.449,38 x 8.049,38 |
| IMC-1967 | Beta "Desconto de pontualidade descontar do aluguel sempre" + taxa 12% antes da baixa | "Split liquidado" sem aviso |
| IMC-1890 | Trocar a conta do proprietário com a baixa segurada | "Erro inesperado", modal com a conta nova |
| IMC-1966 | Qualquer diferença com cancelamento aceito | Tag "Split com erro" em vez de "cancelado" |
| IMC-1965 | Split acumulado (antes do IMC-1301): recálculo de 2 parcelas na mesma requisição sem zerar, com despesa só no 1º mês | 6.740 x 7.040, "Split com erro"; meses iguais passam; parcela não registrada é recusada pelo PJBank |
| IMC-1977 | Clonar/Substituir cobrança | Não reproduziu (corrida de tempo em produção) |
| IMC-1968/1970 | Reprocessamento do Suporte | Não reproduziram (ver seção 4) |

Esses cenários dependem da base `adouglas01-001` local; quem não tiver a base usa a tabela como referência do que já foi reproduzido.
