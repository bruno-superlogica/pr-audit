#!/usr/bin/env bash
# Configuração inicial da skill pr-audit. Pode ser rodada de novo a qualquer momento.
# Toda pergunta pode ser pulada (Enter vazio mantém o valor atual ou deixa sem configurar).
# Uso: ./configurar.sh            perguntas interativas
#      ./configurar.sh --mostrar  mostra a configuração atual (sem segredos)
set -u
. "$(dirname "$0")/scripts/lib.sh"

mascarar() { local v="$1"; [ -z "$v" ] && echo "(vazio)" || echo "${v:0:4}…(${#v} caracteres)"; }

if [ "${1:-}" = "--mostrar" ]; then
  echo "Arquivo: $CONFIG_FILE"
  [ -f "$CONFIG_FILE" ] || { echo "(ainda não existe; rode ./configurar.sh)"; exit 0; }
  while IFS= read -r linha; do
    case "$linha" in
      JIRA_TOKEN=*|METABASE_API_KEY=*) echo "${linha%%=*}=$(mascarar "$(eval "echo ${linha#*=}")")" ;;
      *) echo "$linha" ;;
    esac
  done <"$CONFIG_FILE"
  exit 0
fi

ok() { echo "  ✅ $*"; }
pulo() { echo "  ⏭️  $*"; }
falha() { echo "  ⚠️  $*"; }

perguntar() { # perguntar <variavel> <texto> [padrão]
  local var="$1" texto="$2" atual="${!1:-${3:-}}" resp
  if [ -n "$atual" ]; then read -r -p "$texto [$atual]: " resp; else read -r -p "$texto: " resp; fi
  printf -v "$var" '%s' "${resp:-$atual}"
}

sim_nao() { # sim_nao <texto> <padrão S|N>
  local resp
  read -r -p "$1 [$( [ "$2" = S ] && echo 'S/n' || echo 's/N')]: " resp
  resp="${resp:-$2}"
  case "$resp" in [sS]*) return 0 ;; *) return 1 ;; esac
}

echo "Configuração da skill pr-audit"
echo "Toda pergunta pode ser pulada. O que ficar de fora só reduz o que a skill entrega."
echo

# 1. Projeto apps
echo "1) Projeto apps (repositório local)"
perguntar APPS_DIR "   Pasta do projeto apps"
APPS_DIR="${APPS_DIR/#\~/$HOME}"
if [ -z "$APPS_DIR" ]; then
  pulo "sem projeto: a skill trabalha só com o texto do card e da PR"
elif git -C "$APPS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  APPS_DIR="$(cd "$APPS_DIR" && pwd)"
  ok "repositório git em $APPS_DIR"
  [ -d "$APPS_DIR/tests/Imobiliarias" ] || falha "não achei tests/Imobiliarias; confira se é o projeto apps"
  perguntar BASE_BRANCH "   Branch principal" "master"
else
  falha "$APPS_DIR não é um repositório git; deixei sem projeto"
  APPS_DIR=""
fi
echo

# 2. Pasta do material
echo "2) Onde guardar o material de teste (uma pasta por card)"
perguntar QA_DIR "   Pasta" "$HOME/qa-testes"
QA_DIR="${QA_DIR/#\~/$HOME}"
if mkdir -p "$QA_DIR" 2>/dev/null; then ok "$QA_DIR"; else falha "não consegui criar $QA_DIR"; fi
echo

# 3. Ambiente local (Docker)
echo "3) Ambiente local (Docker)"
if tem docker && docker ps >/dev/null 2>&1; then
  perguntar CONTAINER_APPS "   Container do apps" "superlogica-apps"
  perguntar CONTAINER_MYSQL "   Container do MySQL" "superlogica-mysql"
  perguntar APPS_DIR_CONTAINER "   Pasta do projeto dentro do container" "/home/apps"
  perguntar APPS_URL "   Endereço do ERP local" "http://localhost:8080"
  docker_no_ar "$CONTAINER_APPS" && ok "$CONTAINER_APPS no ar" || falha "$CONTAINER_APPS não está rodando agora (tudo bem, a skill confere de novo a cada uso)"
  perguntar LIC_PADRAO "   Licença local padrão (ex.: imob014729-001; Enter pula)"
  if [ -n "$LIC_PADRAO" ] && docker_no_ar "$CONTAINER_MYSQL"; then
    if mysql_local -N -e "\"SHOW DATABASES LIKE '$LIC_PADRAO'\"" | grep -q .; then ok "base $LIC_PADRAO encontrada"; else falha "base $LIC_PADRAO não existe no MySQL local"; fi
  fi
else
  pulo "docker não encontrado ou sem permissão (docker ps falhou): sem PHPUnit e sem banco local"
fi
echo

# 4. Jira
echo "4) Jira (ler o card e publicar o comentário de QA)"
echo "   Token: https://id.atlassian.com/manage-profile/security/api-tokens"
perguntar JIRA_URL "   Endereço do Jira" "https://superlogica.atlassian.net"
perguntar JIRA_EMAIL "   Seu e-mail do Jira (Enter pula)"
if [ -n "${JIRA_EMAIL:-}" ]; then
  if [ -n "${JIRA_TOKEN:-}" ]; then
    read -r -s -p "   Token de API (Enter mantém o atual): " t; echo
  else
    read -r -s -p "   Token de API: " t; echo
  fi
  JIRA_TOKEN="${t:-${JIRA_TOKEN:-}}"
  if [ -n "$JIRA_TOKEN" ]; then
    nome=$(curl -s -m 10 -u "$JIRA_EMAIL:$JIRA_TOKEN" "$JIRA_URL/rest/api/3/myself" \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("displayName",""))' 2>/dev/null)
    if [ -n "$nome" ]; then ok "conectado como $nome"; else falha "o Jira recusou e-mail/token (salvei mesmo assim; rode de novo para corrigir)"; fi
  else
    pulo "sem token: a skill pede o texto do card colado e entrega o comentário pronto para colar"
  fi
else
  JIRA_TOKEN=""
  pulo "sem Jira: a skill pede o texto do card colado e entrega o comentário pronto para colar"
fi
echo

# 5. Tela
echo "5) Execução de testes na tela (Playwright)"
if sim_nao "   Quer que o agente execute passos na tela do ERP?" S; then
  TELA_ATIVA=1
  if sim_nao "   Mostrar a janela do navegador enquanto ele trabalha?" S; then TELA_HEADLESS=0; else TELA_HEADLESS=1; fi
  perguntar QA_PORTA "   Porta de depuração do navegador de QA" "9447"
  if [ -d "$SKILL_DIR/node_modules/playwright-core" ]; then
    ok "Playwright instalado"
  else
    falha "Playwright ainda não instalado; rode ./instalar.sh"
  fi
else
  TELA_ATIVA=0
  pulo "sem tela: a skill entrega roteiro manual"
fi
echo

# 6. Metabase (avançado)
echo "6) Metabase (avançado, opcional)"
if sim_nao "   Configurar Metabase?" N; then
  perguntar METABASE_URL "   Endereço do Metabase"
  read -r -s -p "   Chave de API do Metabase: " t; echo
  METABASE_API_KEY="${t:-${METABASE_API_KEY:-}}"
  if [ -n "${METABASE_URL:-}" ] && [ -n "$METABASE_API_KEY" ]; then
    if curl -s -m 10 -o /dev/null -w '%{http_code}' -H "x-api-key: $METABASE_API_KEY" "$METABASE_URL/api/user/current" | grep -q 200; then ok "Metabase respondeu"; else falha "Metabase recusou a chave"; fi
  fi
else
  pulo "sem Metabase: dados só das bases locais"
fi
echo

# Grava
mkdir -p "$CONFIG_DIR"
umask 077
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
{
  echo "# Configuração da skill pr-audit ($(date '+%d/%m/%Y %H:%M')). Gerado por configurar.sh."
  for v in APPS_DIR BASE_BRANCH QA_DIR CONTAINER_APPS CONTAINER_MYSQL APPS_DIR_CONTAINER APPS_URL LIC_PADRAO \
           JIRA_URL JIRA_EMAIL JIRA_TOKEN TELA_ATIVA TELA_HEADLESS QA_PORTA METABASE_URL METABASE_API_KEY; do
    echo "$v=$(q "${!v:-}")"
  done
} >"$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"
echo "Configuração salva em $CONFIG_FILE (só você lê)."
echo
exec "$SKILL_DIR/scripts/diagnostico.sh"
