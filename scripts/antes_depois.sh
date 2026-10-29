#!/usr/bin/env bash
# Troca os arquivos da PR pela versão do código base (ANTES) e volta para a versão da PR (DEPOIS).
# Precisa do scripts/pr.sh rodado antes (usa pr.env e arquivos.txt da pasta do card).
# Uso: scripts/antes_depois.sh antes  <CARD>   arquivos da PR ficam como no código base
#      scripts/antes_depois.sh depois <CARD>   arquivos voltam para a versão da PR
#      scripts/antes_depois.sh estado <CARD>   mostra em que fase está
# Regra: nunca termine o trabalho em "antes". Se for interrompido, a primeira coisa é rodar "depois".
set -euo pipefail
. "$(dirname "$0")/lib.sh"

ACAO="${1:-}"; CARD="${2:-}"
precisa_apps
P=$(pasta_card "$CARD")
[ -f "$P/pr.env" ] && [ -f "$P/arquivos.txt" ] || erro "rode antes: scripts/pr.sh <PR> $CARD"
# shellcheck disable=SC1091
. "$P/pr.env"
MARCA="$P/.fase-antes"
cd "$APPS_DIR"

# Lista "caminho<TAB>versão_na_base(1=existe)<TAB>versão_na_pr(1=existe)"
listar() {
  while IFS=$'\t' read -r st a b; do
    case "$st" in
      A*) printf '%s\t0\t1\n' "$a" ;;
      D*) printf '%s\t1\t0\n' "$a" ;;
      R*|C*) printf '%s\t1\t0\n%s\t0\t1\n' "$a" "$b" ;;
      *) printf '%s\t1\t1\n' "$a" ;;
    esac
  done <"$P/arquivos.txt"
}

aplicar() { # aplicar <commit> <coluna 2|3>
  local sha="$1" col="$2"
  listar | while IFS=$'\t' read -r f nb np; do
    existe=$([ "$col" = 2 ] && echo "$nb" || echo "$np")
    if [ "$existe" = 1 ]; then mkdir -p "$(dirname "$f")"; git show "$sha:$f" >"$f"; else rm -f "$f"; fi
  done
}

confere_pr() { # 0 se todos os arquivos estão iguais à versão da PR
  local dif=0
  while IFS=$'\t' read -r f _ np; do
    if [ "$np" = 1 ]; then
      if [ ! -f "$f" ] || ! git show "$HEAD_SHA:$f" | cmp -s - "$f"; then echo "  diferente da PR: $f"; dif=1; fi
    elif [ -e "$f" ]; then echo "  deveria não existir na PR: $f"; dif=1; fi
  done < <(listar)
  return $dif
}

case "$ACAO" in
  antes)
    [ -f "$MARCA" ] && erro "já está em ANTES desde $(cat "$MARCA"). Rode 'depois' primeiro se quiser recomeçar."
    echo "Conferindo se os arquivos da PR estão na versão da PR (sem alteração local)..."
    if ! confere_pr; then
      erro "arquivos acima não batem com a PR ${HEAD_SHA:0:10}. Faça checkout da PR (anote a branch atual: $(git rev-parse --abbrev-ref HEAD)) ou guarde as alterações locais, e rode de novo."
    fi
    aplicar "$BASE_SHA" 2
    date '+%d/%m/%Y %H:%M' >"$MARCA"
    echo "ANTES ativo: $(listar | wc -l | tr -d ' ') arquivo(s) na versão base ${BASE_SHA:0:10}."
    echo "Front mudou? Recarregue a tela. Form PHP? Limpe o cache Zend local da licença (ver references/ambiente.md)."
    echo "Lembre de rodar: scripts/antes_depois.sh depois $CARD"
    ;;
  depois)
    aplicar "$HEAD_SHA" 3
    rm -f "$MARCA"
    if confere_pr; then echo "DEPOIS ativo: arquivos na versão da PR ${HEAD_SHA:0:10}."; else erro "algum arquivo não voltou; confira com git status"; fi
    st=$(listar | cut -f1 | xargs git status --short -- 2>/dev/null || true)
    echo "git status dos arquivos da PR: ${st:-(iguais ao commit atual)}"
    [ -f "$P/branch-original.txt" ] && echo "No fim, volte para a branch em que o QA estava: $(cat "$P/branch-original.txt")"
    ;;
  estado)
    if [ -f "$MARCA" ]; then echo "Fase: ANTES (desde $(cat "$MARCA")) — rode 'depois' ao terminar."; else echo "Fase: DEPOIS (versão da PR)."; fi
    [ -f "$P/branch-original.txt" ] && echo "Branch em que o QA estava: $(cat "$P/branch-original.txt")"
    ;;
  *) erro "uso: antes_depois.sh antes|depois|estado <CARD>" ;;
esac
