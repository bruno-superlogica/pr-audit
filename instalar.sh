#!/usr/bin/env bash
# Instala a skill pr-audit para o Codex e o Claude Code e chama a configuração inicial.
# Uso: ./instalar.sh            instalação completa (pode rodar de novo para atualizar)
#      ./instalar.sh --sem-config   não chama o configurar.sh no fim
set -u
. "$(dirname "$0")/scripts/lib.sh"

ok() { echo "  ✅ $*"; }
pulo() { echo "  ⏭️  $*"; }
falha() { echo "  ⚠️  $*"; }
sim_nao() { local r; read -r -p "$1 [$( [ "$2" = S ] && echo 'S/n' || echo 's/N')]: " r; r="${r:-$2}"; case "$r" in [sS]*) return 0 ;; *) return 1 ;; esac; }

echo "Instalando pr-audit a partir de $SKILL_DIR"
echo

echo "1) Programas"
for p in git curl python3; do
  if tem "$p"; then ok "$p"; else falha "$p não encontrado (sudo apt install $p)"; fi
done
NODE_OK=0
if tem node; then
  v=$(node -p 'process.versions.node.split(".")[0]')
  if [ "$v" -ge 18 ]; then ok "node $(node -v)"; NODE_OK=1; else falha "node $(node -v) é antigo; a parte de tela precisa do 18 ou mais novo"; fi
else
  falha "node não encontrado: sem execução de tela (instale o Node 20+ para usar)"
fi
tem docker && ok "docker" || pulo "docker não encontrado: sem PHPUnit e sem banco local"
tem gh && ok "gh (GitHub CLI)" || pulo "gh não encontrado: a PR é lida pelo git (sem título e descrição)"
tem codex && ok "codex" || pulo "codex não encontrado no PATH"
tem claude && ok "claude" || pulo "claude não encontrado no PATH"
echo

echo "2) Playwright (tela)"
if [ "$NODE_OK" = 1 ]; then
  if (cd "$SKILL_DIR" && npm install --no-audit --no-fund --loglevel=error >/dev/null); then
    ok "dependências do Node instaladas"
    if sim_nao "   Baixar o Chromium do Playwright agora (~150 MB, uma vez só)?" S; then
      if sim_nao "   Instalar também as bibliotecas de sistema do Chromium (usa sudo apt)?" N; then
        (cd "$SKILL_DIR" && npx playwright install --with-deps chromium) && ok "Chromium e bibliotecas instalados" || falha "falhou; rode depois: cd $SKILL_DIR && npx playwright install --with-deps chromium"
      else
        (cd "$SKILL_DIR" && npx playwright install chromium) && ok "Chromium instalado" || falha "falhou; rode depois: cd $SKILL_DIR && npx playwright install chromium"
      fi
    fi
  else
    falha "npm install falhou; a parte de tela fica desligada até resolver"
  fi
else
  pulo "sem Node: parte de tela desligada"
fi
echo

echo "3) Registrar a skill"
for base in "$HOME/.agents/skills" "$HOME/.claude/skills"; do
  if [ "$base" = "$HOME/.claude/skills" ] && ! tem claude && [ ! -d "$HOME/.claude" ]; then
    pulo "Claude Code não encontrado; não criei $base/pr-audit"
    continue
  fi
  mkdir -p "$base"
  if [ -e "$base/pr-audit" ] && [ ! -L "$base/pr-audit" ]; then
    falha "$base/pr-audit já existe e não é link; renomeie a pasta antiga e rode de novo"
  else
    ln -sfn "$SKILL_DIR" "$base/pr-audit" && ok "$base/pr-audit → $SKILL_DIR"
  fi
done
echo

# Migração do nome antigo (testar-pr): remove links velhos e aproveita a configuração já feita.
for velho in "$HOME/.agents/skills/testar-pr" "$HOME/.claude/skills/testar-pr"; do
  [ -L "$velho" ] && rm -f "$velho" && ok "link antigo removido: $velho"
done
if [ -f "$HOME/.config/testar-pr/config.env" ] && [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$CONFIG_DIR" && cp -p "$HOME/.config/testar-pr/config.env" "$CONFIG_FILE" && ok "configuração antiga copiada de ~/.config/testar-pr"
fi
echo

echo "4) Playwright MCP (o agente navega sozinho na tela; opcional)"
MCP_ARGS=(npx -y @playwright/mcp@latest --user-data-dir "$CONFIG_DIR/navegador-mcp")
if [ "$NODE_OK" = 1 ] && sim_nao "   Registrar o Playwright MCP no seu agente?" S; then
  mkdir -p "$CONFIG_DIR/navegador-mcp"
  if tem codex; then
    if codex mcp list 2>/dev/null | grep -qi playwright; then ok "Codex já tem um MCP chamado playwright"
    elif codex mcp add playwright -- "${MCP_ARGS[@]}" >/dev/null 2>&1; then ok "registrado no Codex"
    else
      falha "não consegui registrar no Codex. Acrescente em ~/.codex/config.toml:"
      printf '\n[mcp_servers.playwright]\ncommand = "npx"\nargs = ["-y", "@playwright/mcp@latest", "--user-data-dir", "%s"]\n\n' "$CONFIG_DIR/navegador-mcp"
    fi
  fi
  if tem claude; then
    if claude mcp list 2>/dev/null | grep -qi playwright; then ok "Claude Code já tem um MCP chamado playwright"
    elif claude mcp add --scope user playwright -- "${MCP_ARGS[@]}" >/dev/null 2>&1; then ok "registrado no Claude Code"
    else falha "não consegui registrar no Claude Code (claude mcp add --scope user playwright -- ${MCP_ARGS[*]})"
    fi
  fi
else
  pulo "Playwright MCP não registrado"
fi
echo

if [ "${1:-}" != "--sem-config" ]; then
  echo "5) Configuração inicial"
  exec "$SKILL_DIR/configurar.sh"
fi
