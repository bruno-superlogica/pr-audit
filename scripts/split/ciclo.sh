#!/usr/bin/env bash
# Liquida a cobrança no sandbox, marca o split como pago no payload e processa até 5 tentativas.
# Uso: LIC=adouglas01-001 scripts/split/ciclo.sh <id> <valor com ponto> <dtliq m/d/Y> <dtcred m/d/Y> [status_split]
set -uo pipefail
. "$(dirname "$0")/../lib.sh"
: "${LIC:?defina LIC com a licença do sandbox}"
D="$(cd "$(dirname "$0")" && pwd)"
"$D/sb.sh" liquidar "$1" "$2" "$3" "$4"
sleep 3
Q=$(printf '%s' "SELECT MAX(ID_WEBHOOKQUEUE_WHQ) FROM \`$LIC\`.WEBHOOKS_QUEUE WHERE ST_NOME_WHK='boleto_liquidado' AND ST_DADOS_WHQ LIKE '%\"id_recebimento_recb\":\"$1\"%'" \
  | docker exec -i "$CONTAINER_MYSQL" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N' 2>/dev/null)
echo "fila=$Q"
"$D/pago.sh" "$Q" "${5:-1}" | tail -2
"$D/sb.sh" cron 2; for i in 1 2 3 4 5; do "$D/sb.sh" retry >/dev/null; done
"$D/sb.sh" estado "$1"
"$SKILL_DIR/scripts/q.sh" -e "SELECT FL_STATUS_WHP, NM_PROXIMATENTATIVA_WHP FROM \`$LIC\`.WEBHOOKS_PROCESSAMENTOS WHERE ID_WEBHOOK_WHP=$Q"
