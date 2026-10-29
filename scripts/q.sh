#!/usr/bin/env bash
# SQL no MySQL local (container), saída em UTF-8 e em tabela.
# Uso: scripts/q.sh [--salvar arquivo] [--linhas N] <<'SQL'
#        USE `imob014729-001`;
#        SELECT ...;
#      SQL
#      scripts/q.sh -e "SELECT ..."         (SQL na linha de comando)
# Com --salvar a saída completa vai para o arquivo e a tela mostra só as primeiras N linhas (padrão 60).
# Bases: imob = `app26_<licença>`; financeiro = `<licença>`. Ex.: app26_imob014729-001 e imob014729-001.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SALVAR=""; LINHAS=60; SQL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --salvar) SALVAR="$2"; shift 2 ;;
    --linhas) LINHAS="$2"; shift 2 ;;
    -e) SQL="$2"; shift 2 ;;
    *) erro "opção desconhecida: $1" ;;
  esac
done
precisa_mysql
[ -n "$SQL" ] || SQL=$(cat)
TMP=$(mktemp)
printf '%s\n' "$SQL" | docker exec -i "$CONTAINER_MYSQL" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=latin1 -t' 2>&1 \
  | grep -v "Using a password on the command line" | iconv -f latin1 -t utf-8 -c >"$TMP" || true
if [ -n "$SALVAR" ]; then
  mkdir -p "$(dirname "$SALVAR")"; mv "$TMP" "$SALVAR"; resumo_arquivo "$SALVAR" "$LINHAS"
else
  resumo_arquivo "$TMP" "$LINHAS"; rm -f "$TMP"
fi
