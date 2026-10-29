#!/usr/bin/env bash
# Split/PJBank no sandbox local (ver references/split.md). Precisa do navegador de QA logado na licença.
# Uso: LIC=adouglas01-001 scripts/split/sb.sh registrar <id> | liquidar <id> <valor 8093.50> <dtliq m/d/Y> <dtcred m/d/Y>
#                                            | cron [n] | retry | estado <id> | fila [n]
set -uo pipefail
. "$(dirname "$0")/../lib.sh"
: "${LIC:?defina LIC com a licença do sandbox (ex.: LIC=adouglas01-001)}"
D="$SKILL_DIR/scripts"
api() { node "$D/tela/qa.mjs" eval "const l=new Superlogica_Js_Location(); l.setController('$1').setAction('$2').setParams({}); $3 l.setApi(true).viaProxy(true); const r=new Superlogica_Js_Request(l.toString()$4); r.setResponseOptions({autoThrowError:false}); const resp=r.getResponse(); return JSON.stringify(resp.getData()).slice(0,400);"; }
cron1() { node "$D/tela/qa.mjs" eval "const l=new Superlogica_Js_Location(); l.setController('cron').setAction('$1').setParams({}).setParam('forcarProcessamento',1).setApi(true).viaProxy(true); const r=new Superlogica_Js_Request(l.toString()); r.setResponseOptions({autoThrowError:false}); r.getResponse(); return '$1 ok';" >/dev/null; }
case "${1:-}" in
registrar) api verticalimobiliarias registrarsplitlocal "l.setParam('id',$2);" "" ;;
liquidar) api verticalimobiliarias liquidarsplitlocal "" ", {ID_RECEBIMENTO_RECB:$2, VALOR:'$3', DT_LIQUIDACAO:'$4', DT_CREDITO:'$5'}" ;;
cron) for i in $(seq "${2:-2}"); do cron1 criarwebhooks; cron1 webhooks; sleep 2; done; echo cron ok ;;
retry) "$D/q.sh" -e "UPDATE \`$LIC\`.WEBHOOKS_PROCESSAMENTOS SET DT_TENTATIVA_WHP=NOW()-INTERVAL 1 MINUTE WHERE FL_STATUS_WHP<>1;"; "$0" cron 1 ;;
estado) "$D/q.sh" <<SQL
USE \`$LIC\`;
SELECT r.ID_RECEBIMENTO_RECB id, r.VL_EMITIDO_RECB vl, r.FL_STATUS_RECB st, r.FL_REMESSASTATUSCR_RECB rem, r.DT_LIQUIDACAO_RECB liq, r.VL_TOTAL_RECB tot FROM RECEBIMENTO r WHERE r.ID_RECEBIMENTO_RECB=$2;
SELECT ID_SPLIT_SPL, VL_VALOR_SPL, FL_STATUS_SPL fin FROM SPLIT WHERE ID_RECEBIMENTO_RECB=$2;
SELECT ID_SPLIT_SPL, FL_STATUS_SPL app, VL_SPLIT_SPL FROM \`app26_$LIC\`.SPLIT WHERE ID_RECEBIMENTO_RECB=$2;
SQL
;;
fila) "$D/q.sh" <<SQL
USE \`$LIC\`;
SELECT q.ID_WEBHOOKQUEUE_WHQ id, q.ST_NOME_WHK nome, q.FL_STATUS_WHQ st, LEFT(q.ST_DADOS_WHQ,90) dados FROM WEBHOOKS_QUEUE q ORDER BY 1 DESC LIMIT ${2:-6};
SELECT ID_WEBHOOK_WHP, ST_NOME_WHK, FL_STATUS_WHP, NM_PROXIMATENTATIVA_WHP, DT_TENTATIVA_WHP FROM WEBHOOKS_PROCESSAMENTOS ORDER BY 1 DESC LIMIT ${2:-6};
SQL
;;
*) erro "uso: sb.sh registrar|liquidar|cron|retry|estado|fila ..." ;;
esac
