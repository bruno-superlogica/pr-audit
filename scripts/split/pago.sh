#!/usr/bin/env bash
# Uso: LIC=<licença> scripts/split/pago.sh <id da WEBHOOKS_QUEUE> [status=1]
# troca dados_split.status para 1 no boleto_liquidado da fila (id da WEBHOOKS_QUEUE)
. "$(dirname "$0")/../lib.sh"
: "${LIC:?defina LIC com a licença do sandbox}"
Q="$SKILL_DIR/scripts/q.sh"
J=$(echo "SELECT ST_DADOS_WHQ FROM \`$LIC\`.WEBHOOKS_QUEUE WHERE ID_WEBHOOKQUEUE_WHQ=$1" | docker exec -i "$CONTAINER_MYSQL" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=latin1 -N -r' 2>/dev/null)
N=$(python3 -c '
import json,sys
d=json.loads(sys.argv[1])
def fix(o):
    if isinstance(o,dict):
        for k,v in o.items():
            if k=="dados_split":
                for s in (v if isinstance(v,list) else [v]):
                    if isinstance(s,dict) and "status" in s: s["status"]=sys.argv[2]
            else: fix(v)
    elif isinstance(o,list):
        for x in o: fix(x)
fix(d); s=json.dumps(d,ensure_ascii=True,separators=(",",":")).replace("/","\\/"); print(s.replace("\\","\\\\").replace("'"'"'","\\'"'"'"))' "$J" "${2:-1}")
echo "UPDATE \`$LIC\`.WEBHOOKS_QUEUE SET ST_DADOS_WHQ='$N' WHERE ID_WEBHOOKQUEUE_WHQ=$1;" | "$Q"
echo "SELECT LOCATE('\"status\":\"${2:-1}\"', ST_DADOS_WHQ)>0 ok, LENGTH(ST_DADOS_WHQ) FROM \`$LIC\`.WEBHOOKS_QUEUE WHERE ID_WEBHOOKQUEUE_WHQ=$1" | "$Q"
