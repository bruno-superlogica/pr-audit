#!/usr/bin/env bash
# Consulta no Metabase (somente SELECT). Opcional: precisa de METABASE_URL e METABASE_API_KEY na configuração.
# Uso: scripts/metabase.sh <id-do-banco> [--salvar arquivo.tsv] [--linhas N] <<'SQL'
#        SELECT ...
#      SQL
set -euo pipefail
. "$(dirname "$0")/lib.sh"

[ -n "${METABASE_URL:-}" ] && [ -n "${METABASE_API_KEY:-}" ] || erro "Metabase não configurado (rode configurar.sh, item 6). Use as bases locais."
BANCO="${1:-}"; shift || true
[[ "$BANCO" =~ ^[0-9]+$ ]] || erro "uso: metabase.sh <id-do-banco> [--salvar arq] <<SQL ... SQL"
SALVAR=""; LINHAS=50
while [ $# -gt 0 ]; do
  case "$1" in --salvar) SALVAR="$2"; shift 2 ;; --linhas) LINHAS="$2"; shift 2 ;; *) erro "opção desconhecida: $1" ;; esac
done
SQL=$(cat)
echo "$SQL" | grep -Eiq '^\s*(insert|update|delete|drop|alter|create|truncate|replace)\b' && erro "só SELECT no Metabase"
TMP=$(mktemp)
python3 - "$BANCO" "$SQL" <<'PY' | curl -s -m 120 -X POST -H "Content-Type: application/json" -H "x-api-key: $METABASE_API_KEY" --data @- "$METABASE_URL/api/dataset" >"$TMP"
import json, sys
print(json.dumps({"database": int(sys.argv[1]), "type": "native", "native": {"query": sys.argv[2]}}))
PY
SAIDA="${SALVAR:-$(mktemp)}"
python3 - "$TMP" "$SAIDA" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if d.get("error") or "data" not in d:
    sys.exit("ERRO do Metabase: " + str(d.get("error") or d)[:500])
cols = [c["name"] for c in d["data"]["cols"]]
with open(sys.argv[2], "w") as f:
    f.write("\t".join(cols) + "\n")
    for r in d["data"]["rows"]:
        f.write("\t".join("" if v is None else str(v) for v in r) + "\n")
PY
rm -f "$TMP"
resumo_arquivo "$SAIDA" "$LINHAS"
[ -z "$SALVAR" ] && rm -f "$SAIDA"
exit 0
