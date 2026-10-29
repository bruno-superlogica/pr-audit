#!/usr/bin/env bash
# Roda PHPUnit no container, UM teste por vez (a suíte para no primeiro erro e esconde os outros).
# Uso: scripts/rodar_phpunit.sh <CARD> <fase> <arquivo-de-teste> [opções]
#   <fase>               nome livre: antes, depois, master, pr...
#   <arquivo-de-teste>   caminho no repo (tests/...Test.php) OU arquivo fora do repo (ex.: $QA_DIR/<CARD>/XTest.php)
# Opções:
#   --destino tests/.../XTest.php   obrigatório quando o teste está fora do repo: é copiado para lá só durante a rodada
#   --testes t1,t2                  só estes métodos (padrão: todos os "function test..." do arquivo)
#   --inteiro                       roda o arquivo de uma vez, sem separar por método
#   --config phpunit.xml            arquivo de configuração do PHPUnit
# Saída completa: $QA_DIR/<CARD>/resultados/phpunit_<fase>.txt. Na tela, só o resumo.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

CARD="${1:-}"; FASE="${2:-}"; TESTE="${3:-}"
[ -n "$CARD" ] && [ -n "$FASE" ] && [ -n "$TESTE" ] || erro "uso: rodar_phpunit.sh <CARD> <fase> <arquivo-de-teste> [--destino ...] [--testes a,b] [--inteiro] [--config ...]"
shift 3
DESTINO=""; LISTA=""; INTEIRO=0; CONFIG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --destino) DESTINO="$2"; shift 2 ;;
    --testes) LISTA="${2//,/ }"; shift 2 ;;
    --inteiro) INTEIRO=1; shift ;;
    --config) CONFIG="-c $2"; shift 2 ;;
    *) erro "opção desconhecida: $1" ;;
  esac
done
precisa_apps; precisa_docker
P=$(pasta_card "$CARD")
OUT="$P/resultados/phpunit_$FASE.txt"

COPIA=""
case "$TESTE" in
  /*|~*)
    [ -n "$DESTINO" ] || erro "teste fora do repo precisa de --destino tests/.../XTest.php"
    ORIGEM="${TESTE/#\~/$HOME}"
    [ -f "$ORIGEM" ] || erro "não achei $ORIGEM"
    [ -e "$APPS_DIR/$DESTINO" ] && erro "$DESTINO já existe no repo; escolha outro nome para não sobrescrever"
    mkdir -p "$(dirname "$APPS_DIR/$DESTINO")"
    cp "$ORIGEM" "$APPS_DIR/$DESTINO"
    COPIA="$APPS_DIR/$DESTINO"
    trap 'rm -f "$COPIA"' EXIT
    REL="$DESTINO"
    ;;
  *)
    ORIGEM="$APPS_DIR/$TESTE"; REL="$TESTE"
    [ -f "$ORIGEM" ] || erro "não achei $TESTE no repo"
    ;;
esac

: >"$OUT"
rodar() { docker exec "$CONTAINER_APPS" sh -c "cd $APPS_DIR_CONTAINER && php vendor/bin/phpunit $CONFIG $* 2>&1" >>"$OUT" || true; }
if [ "$INTEIRO" = 1 ]; then
  echo "##### arquivo inteiro" >>"$OUT"; rodar "'$REL'"
else
  [ -n "$LISTA" ] || LISTA=$(grep -oE 'function test[A-Za-z0-9_]+' "$ORIGEM" | sed 's/function //')
  [ -n "$LISTA" ] || erro "nenhum método test... em $TESTE (use --testes ou --inteiro)"
  for t in $LISTA; do echo "##### $t" >>"$OUT"; rodar "--filter '/::$t\$/' '$REL'"; done
fi

if grep -q "Could not determine temp directory" "$OUT"; then
  echo "AVISO: falha de ambiente (temp dir). Corrija com: docker exec $CONTAINER_APPS chmod 1777 /tmp — e rode de novo."
fi
echo "PHPUnit ($FASE) — $REL"
grep -E "^#####|^\[QA\]|^OK|^Tests:|^FAILURES|Failed asserting|^ERRORS|Exception:" "$OUT" | cut -c1-300 | head -60 || true
echo "Completo em $OUT"
