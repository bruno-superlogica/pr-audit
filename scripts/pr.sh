#!/usr/bin/env bash
# Baixa a PR, descobre o commit base e grava o material na pasta do card.
# Uso: scripts/pr.sh <numero-da-PR> <CARD>
# Grava em $QA_DIR/<CARD>/: pr.env (SHAs), pr.md (título e descrição, se houver gh), pr.diff, arquivos.txt
# Mostra só um resumo. Sem gh, título e descrição ficam de fora: peça ao QA para colar.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

N="${1:-}"; CARD="${2:-}"
[[ "$N" =~ ^[0-9]+$ ]] || erro "uso: pr.sh <numero-da-PR> <CARD>"
precisa_apps
P=$(pasta_card "$CARD")
cd "$APPS_DIR"

git fetch -q origin "$BASE_BRANCH" "+pull/$N/head:refs/remotes/origin/qa-pr-$N" \
  || erro "não consegui baixar a PR $N do origin (sem acesso ao GitHub?). Peça ao QA o diff ou o link da PR."
HEAD_SHA=$(git rev-parse "refs/remotes/origin/qa-pr-$N")

ESTADO="desconhecido"; TITULO=""; URL=""; BASE_REF="$BASE_BRANCH"; MERGE=""
if tem gh && gh auth status >/dev/null 2>&1; then
  gh pr view "$N" --json number,title,body,url,state,headRefName,baseRefName,headRefOid,mergeCommit >"$P/pr.json"
  eval "$(python3 - "$P/pr.json" "$P/pr.md" <<'PY'
import json, shlex, sys
d = json.load(open(sys.argv[1]))
m = (d.get("mergeCommit") or {}).get("oid") or ""
open(sys.argv[2], "w").write(f"# PR #{d['number']} — {d['title']}\n\n{d['url']}\n\nEstado: {d['state']} · {d['headRefName']} → {d['baseRefName']}\n\n## Descrição\n\n{d.get('body') or '(sem descrição)'}\n")
for k, v in {"TITULO": d["title"], "URL": d["url"], "ESTADO": d["state"], "BASE_REF": d["baseRefName"], "MERGE": m}.items():
    print(f"{k}={shlex.quote(v)}")
PY
)"
fi

# Commit base: PR mergeada com merge commit → pai do merge; senão o ponto onde a PR saiu da base.
git fetch -q origin "$BASE_REF" 2>/dev/null || true
if [ -n "$MERGE" ] && git cat-file -e "$MERGE^2" 2>/dev/null; then
  BASE_SHA=$(git rev-parse "$MERGE^1")
else
  BASE_SHA=$(git merge-base "origin/$BASE_REF" "$HEAD_SHA")
  if [ "$BASE_SHA" = "$HEAD_SHA" ]; then
    m=$(git log "origin/$BASE_REF" --merges --ancestry-path "$HEAD_SHA..origin/$BASE_REF" --format=%H | tail -1)
    [ -n "$m" ] && BASE_SHA=$(git rev-parse "$m^1")
  fi
fi

[ -f "$P/branch-original.txt" ] || git rev-parse --abbrev-ref HEAD >"$P/branch-original.txt"
git diff "$BASE_SHA" "$HEAD_SHA" >"$P/pr.diff"
git diff --name-status "$BASE_SHA" "$HEAD_SHA" >"$P/arquivos.txt"
{
  echo "PR=$N"
  echo "HEAD_SHA=$HEAD_SHA"
  echo "BASE_SHA=$BASE_SHA"
  echo "BASE_REF=$BASE_REF"
  printf 'TITULO=%q\n' "$TITULO"
} >"$P/pr.env"

echo "PR #$N ${TITULO:+— $TITULO}"
[ -n "$URL" ] && echo "$URL"
echo "Estado: $ESTADO · versão testada: ${HEAD_SHA:0:10} · base: ${BASE_SHA:0:10} ($BASE_REF)"
echo "Mudança: $(git diff --shortstat "$BASE_SHA" "$HEAD_SHA")"
echo "Arquivos:"
resumo_arquivo "$P/arquivos.txt" 40
echo
echo "Gravado em $P: pr.env, pr.diff, arquivos.txt${TITULO:+, pr.md (leia a seção 'Como testar')}"
echo "Branch atual do QA anotada em branch-original.txt: $(cat "$P/branch-original.txt") (volte para ela no fim)"
[ -z "$TITULO" ] && echo "Sem gh: peça ao QA o título e a descrição da PR (seção 'Como testar') e salve em $P/pr.md"
exit 0
