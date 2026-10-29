#!/usr/bin/env bash
# Diagnóstico rápido: o que a skill consegue fazer nesta máquina agora.
# A última linha (CAPACIDADES=...) é a que o agente usa para decidir o caminho.
# Uso: scripts/diagnostico.sh [--sem-rede]   (--sem-rede não testa Jira nem Metabase)
set -u
. "$(dirname "$0")/lib.sh"

SEM_REDE=0; [ "${1:-}" = "--sem-rede" ] && SEM_REDE=1
CAP="texto"
ok() { echo "✅ $*"; }
nao() { echo "⏭️  $*"; }
alerta() { echo "⚠️  $*"; }

echo "testar-pr — diagnóstico ($(date '+%d/%m/%Y %H:%M'))"
[ -f "$CONFIG_FILE" ] || alerta "sem configuração; rode $SKILL_DIR/configurar.sh (seguindo só com o que for detectado)"

# Projeto
if [ -n "$APPS_DIR" ] && git -C "$APPS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  br=$(git -C "$APPS_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  sujos=$(git -C "$APPS_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  ok "projeto: $APPS_DIR (branch $br, $sujos arquivo(s) com alteração local)"
  CAP="$CAP,codigo"
else
  nao "projeto: não configurado → sem análise de impacto pelo código"
fi

# Docker
if tem docker && docker ps >/dev/null 2>&1; then
  if docker_no_ar "$CONTAINER_APPS"; then
    ok "docker: $CONTAINER_APPS no ar"; CAP="$CAP,phpunit"
  else
    nao "docker: $CONTAINER_APPS fora do ar → sem PHPUnit"
  fi
  if docker_no_ar "$CONTAINER_MYSQL"; then
    ok "docker: $CONTAINER_MYSQL no ar"; CAP="$CAP,banco"
    if [ -n "$LIC_PADRAO" ]; then
      mysql_local -N -e "\"SHOW DATABASES LIKE '$LIC_PADRAO'\"" | grep -q . && ok "licença padrão $LIC_PADRAO existe" || alerta "licença padrão $LIC_PADRAO não existe no MySQL local"
    fi
  else
    nao "docker: $CONTAINER_MYSQL fora do ar → sem consultas ao banco"
  fi
else
  nao "docker: indisponível (não instalado, sem permissão ou bloqueado pelo sandbox do agente)"
fi

# GitHub
if tem gh && gh auth status >/dev/null 2>&1; then ok "gh: autenticado"; CAP="$CAP,gh"
else nao "gh: indisponível → PR lida pelo git (sem título e descrição; peça ao QA)"; fi

# Jira
if [ -n "${JIRA_EMAIL:-}" ] && [ -n "${JIRA_TOKEN:-}" ]; then
  if [ "$SEM_REDE" = 1 ]; then ok "jira: credenciais configuradas (não testado)"; CAP="$CAP,jira"
  else
    code=$(curl -s -m 8 -o /dev/null -w '%{http_code}' -u "$JIRA_EMAIL:$JIRA_TOKEN" "$JIRA_URL/rest/api/3/myself")
    if [ "$code" = 200 ]; then ok "jira: conectado ($JIRA_URL)"; CAP="$CAP,jira"
    else alerta "jira: respondeu $code (token vencido ou rede bloqueada) → pedir o texto do card ao QA"; fi
  fi
else
  nao "jira: sem credenciais → pedir o texto do card e entregar o comentário para colar"
fi

# Tela
if [ "${TELA_ATIVA:-1}" = 0 ]; then
  nao "tela: desligada na configuração → roteiro manual"
elif tem node && [ -d "$SKILL_DIR/node_modules/playwright-core" ]; then
  exe=$(cd "$SKILL_DIR" && node -e "try{console.log(require('playwright-core').chromium.executablePath())}catch(e){}" 2>/dev/null)
  if [ -n "${TESTAR_PR_CHROMIUM:-}" ] || { [ -n "$exe" ] && [ -x "$exe" ]; }; then
    ok "tela: Playwright e Chromium prontos"; CAP="$CAP,tela"
    if curl -s -m 2 "http://127.0.0.1:$QA_PORTA/json/version" >/dev/null 2>&1; then ok "tela: navegador de QA aberto na porta $QA_PORTA"; fi
  else
    nao "tela: Chromium não baixado (cd $SKILL_DIR && npx playwright install chromium)"
  fi
else
  nao "tela: Playwright não instalado (rode $SKILL_DIR/instalar.sh)"
fi
if tem codex && codex mcp list 2>/dev/null | grep -qi playwright; then ok "tela: Playwright MCP registrado no Codex"; CAP="$CAP,mcp"
elif tem claude && claude mcp list 2>/dev/null | grep -qi playwright; then ok "tela: Playwright MCP registrado no Claude Code"; CAP="$CAP,mcp"; fi

# Metabase
if [ -n "${METABASE_URL:-}" ] && [ -n "${METABASE_API_KEY:-}" ]; then
  if [ "$SEM_REDE" = 1 ] || curl -s -m 8 -o /dev/null -w '%{http_code}' -H "x-api-key: $METABASE_API_KEY" "$METABASE_URL/api/user/current" | grep -q 200; then
    ok "metabase: configurado"; CAP="$CAP,metabase"
  else alerta "metabase: não respondeu"; fi
fi

# Sandbox do Codex
if [ -f "$HOME/.codex/config.toml" ] && ! grep -Eq '^\s*network_access\s*=\s*true' "$HOME/.codex/config.toml"; then
  echo "ℹ️  Codex: se comandos de docker/curl falharem só dentro do Codex, o sandbox está bloqueando rede."
  echo "    Libere em ~/.codex/config.toml:  [sandbox_workspace_write]  network_access = true"
fi

echo "Material vai para: $QA_DIR/<CARD>/"
echo "CAPACIDADES=$CAP"
