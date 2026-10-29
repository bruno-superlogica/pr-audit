#!/usr/bin/env bash
# Gera um cenário real na licença de teste (testephpunitN) com os utilitários de teste do repo,
# sem apagar no tearDown (MANTER_CENARIO=1). O teste costuma gravar os ids em cenarios/<nome>.json.
# Uso: scripts/gerar_cenario.sh <tests/.../GerarCenarioXTest.php> <metodo-ou-filtro> [--config phpunit.xml]
# Exemplo: scripts/gerar_cenario.sh tests/Imobiliarias/Funcionalidades/EstruturaNovaDespesas/IMC1824/GerarCenarioIMC1824Test.php testCcRepassadoSemCobranca
set -euo pipefail
. "$(dirname "$0")/lib.sh"

CLASSE="${1:-}"; FILTRO="${2:-}"
[ -n "$CLASSE" ] && [ -n "$FILTRO" ] || erro "uso: gerar_cenario.sh <ClasseTest.php> <metodo> [--config arquivo]"
CONFIG=""; [ "${3:-}" = "--config" ] && CONFIG="-c ${4:-phpunit.xml}"
precisa_apps; precisa_docker
[ -f "$APPS_DIR/$CLASSE" ] || erro "não achei $CLASSE no repo"
docker exec -e MANTER_CENARIO=1 "$CONTAINER_APPS" sh -c "cd $APPS_DIR_CONTAINER && vendor/bin/phpunit $CONFIG --testdox --filter '$FILTRO' '$CLASSE' 2>&1" | tail -40
echo "Ids gerados: procure em $APPS_DIR/cenarios/ (ou na saída acima). Licença: testephpunitN — login com: node scripts/tela/login.mjs testephpunit1 --teste"
