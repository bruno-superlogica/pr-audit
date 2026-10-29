#!/usr/bin/env bash
# Lista quem lê os campos que a PR passou a gravar de outro jeito (PHP, JS, SQL, templates) e classifica cada uso.
# Perigosos: os que testam "ligado/preenchido" e os que fazem conta com o campo — passam a rodar/calcular diferente.
# Uso: scripts/leitores.sh <CARD> <CAMPO> [CAMPO...]      ex.: leitores.sh IMC-1959 FL_ALTEROUVALOR_IMOD VL_PAGTOINDEVIDO_IMOD
# Lista completa: $QA_DIR/<CARD>/resultados/leitores-<CAMPO>.txt
set -euo pipefail
. "$(dirname "$0")/lib.sh"

CARD="${1:-}"; shift || true
[ -n "$CARD" ] && [ $# -gt 0 ] || erro "uso: leitores.sh <CARD> <CAMPO> [CAMPO...]"
precisa_apps
P=$(pasta_card "$CARD")
cd "$APPS_DIR"

for CAMPO in "$@"; do
  OUT="$P/resultados/leitores-$CAMPO.txt"
  git grep --untracked -n -I -w "$CAMPO" -- '*.php' '*.phtml' '*.js' '*.ts' '*.sql' '*.tpl' ':!vendor' ':!node_modules' >"$OUT" || true
  python3 - "$OUT" "$CAMPO" <<'PY'
import re, sys
from collections import Counter
arq, campo = sys.argv[1], re.escape(sys.argv[2])
C = rf"(?<![\w$]){campo}(?!\w)"
regras = [
    ("faz conta", re.compile(rf"(?<!-)[+*/]\s*[\w$>\[\]'\"()-]*?{C}|(?<![-=])-(?!>)\s*[\w$>\[\]'\"()-]*?{C}|{C}[\]'\")]*\s*(?:[+*/]|-(?!>))(?!=)")),
    ("testa ligado/preenchido", re.compile(rf"(?:empty|isset|is_null|intval|boolval)\s*\([^)]*{C}|!\s*[\w$>\[\]'\"-]*{C}|{C}[\]'\")]*\s*(?:\)|&&|\|\||\?|and\b|or\b)|(?:&&|\|\||\?|\band\b|\bor\b)\s*[\w$>\[\]'\"(-]*{C}[\]'\")]*\s*(?![=!<>])|{C}[\]'\")]*\s*(?:>|<|>=|<=)\s*0")),
    ("compara com valor", re.compile(rf"{C}[\]'\")]*\s*(?:===?|!==?|<>|>=?|<=?)|(?:===?|!==?)\s*[\w$>\[\]'\"-]*{C}")),
    ("grava", re.compile(rf"{C}[\]'\")]*\s*(?:=(?!=)|=>)")),
]
grupos, arquivos = {}, Counter()
total = 0
for linha in open(arq, encoding="utf-8", errors="replace"):
    linha = linha.rstrip("\n")
    caminho = linha.split(":", 1)[0]
    total += 1
    if caminho.startswith("tests/"):
        grupos.setdefault("em testes", []).append(linha)
        continue
    arquivos[caminho] += 1
    codigo = linha.split(":", 2)[-1]
    cat = next((n for n, r in regras if r.search(codigo)), "outro uso (leia)")
    grupos.setdefault(cat, []).append(linha)
print(f"== {sys.argv[2]}: {total} ocorrência(s) em {len(arquivos)} arquivo(s) fora de tests/ ({len(grupos.get('em testes', []))} em tests/)")
for cat in ["testa ligado/preenchido", "faz conta", "compara com valor", "grava", "outro uso (leia)"]:
    itens = grupos.get(cat, [])
    if not itens:
        continue
    alerta = " ⚠️ PERIGOSO: confira antes x depois" if cat in ("testa ligado/preenchido", "faz conta") else ""
    print(f"-- {cat} ({len(itens)}){alerta}")
    lim = 25 if alerta else 8
    for l in itens[:lim]:
        print("   " + l[:220])
    if len(itens) > lim:
        print(f"   ... mais {len(itens) - lim} na lista completa")
PY
  echo "Lista completa em $OUT"
  echo
done
