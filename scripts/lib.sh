# shellcheck shell=bash
# Funções comuns da skill testar-pr. Use com: . "$(dirname "$0")/lib.sh"

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${TESTAR_PR_CONFIG_DIR:-$HOME/.config/testar-pr}"
CONFIG_FILE="$CONFIG_DIR/config.env"

# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

: "${QA_DIR:=$HOME/qa-testes}"
: "${APPS_URL:=http://localhost:8080}"
: "${CONTAINER_APPS:=superlogica-apps}"
: "${CONTAINER_MYSQL:=superlogica-mysql}"
: "${APPS_DIR_CONTAINER:=/home/apps}"
: "${BASE_BRANCH:=master}"
: "${JIRA_URL:=https://superlogica.atlassian.net}"
: "${QA_PORTA:=9447}"
: "${TELA_HEADLESS:=0}"
export QA_DIR APPS_URL CONTAINER_APPS CONTAINER_MYSQL APPS_DIR_CONTAINER BASE_BRANCH JIRA_URL QA_PORTA TELA_HEADLESS
export APPS_DIR="${APPS_DIR:-}" LIC_PADRAO="${LIC_PADRAO:-}"

erro() { echo "ERRO: $*" >&2; exit 1; }
aviso() { echo "AVISO: $*" >&2; }

tem() { command -v "$1" >/dev/null 2>&1; }

precisa_apps() {
  [ -n "$APPS_DIR" ] && git -C "$APPS_DIR" rev-parse --git-dir >/dev/null 2>&1 \
    || erro "projeto apps não configurado ou não é repositório git. Rode: $SKILL_DIR/configurar.sh"
}

docker_no_ar() { docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"; }

precisa_docker() {
  tem docker || erro "docker não instalado: sem PHPUnit e sem banco local. Siga com cenários e roteiro manual."
  docker_no_ar "$CONTAINER_APPS" || erro "container $CONTAINER_APPS fora do ar (confira com: docker ps). Não reinicie containers sem avisar o QA."
}

precisa_mysql() {
  tem docker || erro "docker não instalado: sem banco local."
  docker_no_ar "$CONTAINER_MYSQL" || erro "container $CONTAINER_MYSQL fora do ar (confira com: docker ps)."
}

# Pasta de material de um card: $QA_DIR/<CARD>, com resultados/ dentro.
pasta_card() {
  local c="${1:-}"
  [ -n "$c" ] || erro "informe o card (ex.: IMC-1824)"
  local p="$QA_DIR/$c"
  mkdir -p "$p/resultados"
  echo "$p"
}

# SQL no MySQL local. Argumentos extras vão para o cliente mysql (ex.: -t, -N).
mysql_local() {
  docker exec -i "$CONTAINER_MYSQL" sh -c "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --default-character-set=latin1 $*" 2>/dev/null \
    | iconv -f latin1 -t utf-8 -c
}

# Mostra no máximo N linhas de um arquivo e avisa quando cortou.
resumo_arquivo() {
  local arq="$1" n="${2:-40}" total
  total=$(wc -l <"$arq" | tr -d ' ')
  head -n "$n" "$arq"
  [ "$total" -gt "$n" ] && echo "... ($total linhas no total; completo em $arq)"
  return 0
}
