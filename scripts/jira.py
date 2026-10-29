#!/usr/bin/env python3
"""Jira pela API REST, com as credenciais da configuração inicial. Sem credenciais, trabalha no modo manual.

Uso:
  jira.py eu                                         confere as credenciais
  jira.py card <CARD>                                grava $QA_DIR/<CARD>/card.md (descrição, comentários, anexos)
  jira.py comentar <CARD> <arquivo.md>               mostra o comentário convertido (prévia); nada é publicado
  jira.py comentar <CARD> <arquivo.md> --confirmado  publica (só depois do ok do QA)
       ... --editar <id-do-comentario>               substitui um comentário anterior de QA
  jira.py anexar <CARD> <arquivo> [...] [--confirmado] sobe arquivos (logs, SQL) como anexos do card
  jira.py wiki <arquivo.md>                          só converte Markdown para o formato do Jira (para colar à mão)

O comentário é escrito em Markdown e convertido para o formato wiki do Jira.
Para citar um anexo no comentário: [^nome-do-arquivo.log]
"""
import base64
import json
import os
import re
import shlex
import subprocess
import sys
import urllib.error
import urllib.request

CONFIG = os.path.join(os.environ.get("PR_AUDIT_CONFIG_DIR", os.path.expanduser("~/.config/pr-audit")), "config.env")


def ler_config():
    cfg = {}
    if os.path.exists(CONFIG):
        for linha in open(CONFIG, encoding="utf-8"):
            linha = linha.strip()
            if not linha or linha.startswith("#") or "=" not in linha:
                continue
            k, v = linha.split("=", 1)
            try:
                partes = shlex.split(v)
                cfg[k] = partes[0] if partes else ""
            except ValueError:
                cfg[k] = v
    for k in ("JIRA_URL", "JIRA_EMAIL", "JIRA_TOKEN", "QA_DIR"):
        if os.environ.get(k):
            cfg[k] = os.environ[k]
    cfg.setdefault("JIRA_URL", "https://superlogica.atlassian.net")
    cfg["JIRA_URL"] = (cfg.get("JIRA_URL") or "https://superlogica.atlassian.net").rstrip("/")
    cfg["QA_DIR"] = os.path.expanduser(cfg.get("QA_DIR") or "~/qa-testes")
    return cfg


CFG = ler_config()


def tem_credencial():
    return bool(CFG.get("JIRA_EMAIL") and CFG.get("JIRA_TOKEN"))


def pasta(card):
    p = os.path.join(CFG["QA_DIR"], card)
    os.makedirs(os.path.join(p, "resultados"), exist_ok=True)
    return p


def api(metodo, caminho, corpo=None):
    auth = base64.b64encode(f"{CFG['JIRA_EMAIL']}:{CFG['JIRA_TOKEN']}".encode()).decode()
    req = urllib.request.Request(CFG["JIRA_URL"] + caminho, method=metodo,
                                 data=json.dumps(corpo).encode() if corpo is not None else None,
                                 headers={"Authorization": "Basic " + auth, "Accept": "application/json",
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            txt = r.read().decode()
            return json.loads(txt) if txt else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"ERRO Jira {e.code} em {caminho}: {e.read().decode()[:400]}")
    except urllib.error.URLError as e:
        sys.exit(f"ERRO: não consegui falar com o Jira ({e.reason}). Peça o texto do card ao QA.")


# ---------- Markdown -> wiki do Jira ----------
def inline(t):
    codigos = []
    t = re.sub(r"`([^`]+)`", lambda m: codigos.append(m.group(1)) or f"\x00{len(codigos) - 1}\x00", t)
    t = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r"[\1|\2]", t)
    t = re.sub(r"\*\*(.+?)\*\*", "\x01\\1\x01", t)
    t = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"_\1_", t)
    t = re.sub(r"(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)", r"_\1_", t)
    t = t.replace("\x01", "*")
    t = re.sub(r"~~(.+?)~~", r"-\1-", t)
    return re.sub("\x00(\\d+)\x00", lambda m: "{{" + codigos[int(m.group(1))] + "}}", t)


def md_para_wiki(md):
    saida, em_codigo, linhas = [], False, md.splitlines()
    i = 0
    while i < len(linhas):
        l = linhas[i]
        if l.strip().startswith("```"):
            saida.append("{code}" if not em_codigo else "{code}")
            em_codigo = not em_codigo
            i += 1
            continue
        if em_codigo:
            saida.append(l)
            i += 1
            continue
        m = re.match(r"^(#{1,6})\s+(.*)", l)
        if m:
            saida.append(f"h{len(m.group(1))}. {inline(m.group(2))}")
        elif re.match(r"^\s*\|", l):
            prox = linhas[i + 1] if i + 1 < len(linhas) else ""
            celulas = [c.strip() for c in l.strip().strip("|").split("|")]
            if re.match(r"^\s*\|?\s*:?-{2,}", prox):
                saida.append("||" + "||".join(inline(c) for c in celulas) + "||")
                i += 2
                continue
            saida.append("|" + "|".join(inline(c) or " " for c in celulas) + "|")
        elif re.match(r"^(\s*)([-*+]|\d+[.)])\s+", l):
            m = re.match(r"^(\s*)([-*+]|\d+[.)])\s+(.*)", l)
            nivel = len(m.group(1).replace("\t", "    ")) // 2 + 1
            marca = "#" if m.group(2)[0].isdigit() else "*"
            saida.append(marca * nivel + " " + inline(m.group(3)))
        elif l.startswith(">"):
            saida.append("bq. " + inline(l.lstrip("> ").rstrip()))
        elif re.match(r"^\s*(-{3,}|\*{3,})\s*$", l):
            saida.append("----")
        else:
            saida.append(inline(l))
        i += 1
    return "\n".join(saida)


# ---------- comandos ----------
def cmd_eu():
    if not tem_credencial():
        sys.exit("Sem credenciais do Jira (rode configurar.sh). Modo manual: peça o texto do card ao QA.")
    d = api("GET", "/rest/api/2/myself")
    print(f"Conectado como {d.get('displayName')} ({d.get('emailAddress', '')}) em {CFG['JIRA_URL']}")


def cmd_card(card):
    p = pasta(card)
    if not tem_credencial():
        print(f"MODO MANUAL: sem credenciais do Jira. Peça ao QA para colar o card (descrição, passos, comportamento esperado e comentários) e salve em {p}/card.md")
        return
    d = api("GET", f"/rest/api/2/issue/{card}?fields=summary,status,issuetype,components,assignee,reporter,description,comment,attachment,labels,priority")
    f = d["fields"]
    nome = lambda x: (x or {}).get("displayName") or "-"
    comps = ", ".join(c["name"] for c in f.get("components") or []) or "-"
    coms = (f.get("comment") or {}).get("comments", [])
    anexos = f.get("attachment") or []
    linhas = [f"# {card} — {f.get('summary')}", "",
              f"{CFG['JIRA_URL']}/browse/{card}", "",
              f"Tipo: {(f.get('issuetype') or {}).get('name')} · Status: {(f.get('status') or {}).get('name')} · Prioridade: {(f.get('priority') or {}).get('name', '-')}",
              f"Componentes: {comps} · Responsável: {nome(f.get('assignee'))} · Relator: {nome(f.get('reporter'))}", "",
              "## Descrição", "", f.get("description") or "(sem descrição)", "",
              f"## Anexos ({len(anexos)})", ""]
    linhas += [f"- {a['filename']} ({a.get('size', 0) // 1024} KB, {a.get('created', '')[:10]}) id {a['id']}" for a in anexos] or ["(nenhum)"]
    linhas += ["", f"## Comentários ({len(coms)})", ""]
    for c in coms:
        linhas += [f"### {nome(c.get('author'))} — {c.get('created', '')[:16].replace('T', ' ')} (id {c['id']})", "", c.get("body") or "", ""]
    open(os.path.join(p, "card.md"), "w", encoding="utf-8").write("\n".join(linhas))
    json.dump(d, open(os.path.join(p, "resultados", "card.json"), "w"), ensure_ascii=False)
    print(f"{card} — {f.get('summary')}")
    print(f"Status: {(f.get('status') or {}).get('name')} · {len(coms)} comentário(s) · {len(anexos)} anexo(s)")
    dumps = [a["filename"] for a in anexos if re.search(r"\.(sql|gz|zip|bz2|dump)$", a["filename"], re.I)]
    if dumps:
        print("Possível dump da base anexado: " + ", ".join(dumps))
    print(f"Card completo em {p}/card.md (leia descrição e comentários inteiros)")


def cmd_comentar(card, arq, editar=None, confirmado=False):
    md = open(arq, encoding="utf-8").read()
    wiki = md_para_wiki(md)
    destino = os.path.join(pasta(card), "comentario-card.wiki.txt")
    open(destino, "w", encoding="utf-8").write(wiki)
    if not tem_credencial():
        print(f"MODO MANUAL: sem credenciais. O QA cola o conteúdo de {arq} no card {card} (o editor do Jira aceita Markdown colado).")
        print(f"Versão no formato wiki do Jira: {destino}")
        return
    if not confirmado:
        print("PRÉVIA (nada foi publicado). Mostre ao QA; depois de ok, repita com --confirmado.")
        print(f"Formato wiki em {destino}. Primeiras linhas:")
        print("\n".join(wiki.splitlines()[:25]))
        return
    if editar:
        api("PUT", f"/rest/api/2/issue/{card}/comment/{editar}", {"body": wiki})
        cid = editar
    else:
        cid = api("POST", f"/rest/api/2/issue/{card}/comment", {"body": wiki}).get("id")
    print(f"Comentário publicado: {CFG['JIRA_URL']}/browse/{card}?focusedCommentId={cid}")


def cmd_anexar(card, arquivos, confirmado=False):
    faltando = [a for a in arquivos if not os.path.isfile(a)]
    if faltando:
        sys.exit("ERRO: não achei " + ", ".join(faltando))
    if not tem_credencial():
        print(f"MODO MANUAL: o QA anexa à mão no card {card}: " + ", ".join(arquivos))
        return
    if not confirmado:
        print(f"PRÉVIA: subiria {len(arquivos)} arquivo(s) no {card}: " + ", ".join(os.path.basename(a) for a in arquivos))
        print("Depois do ok do QA, repita com --confirmado.")
        return
    cmd = ["curl", "-s", "-m", "300", "-u", f"{CFG['JIRA_EMAIL']}:{CFG['JIRA_TOKEN']}", "-H", "X-Atlassian-Token: no-check"]
    for a in arquivos:
        cmd += ["-F", f"file=@{a}"]
    cmd.append(f"{CFG['JIRA_URL']}/rest/api/3/issue/{card}/attachments")
    r = subprocess.run(cmd, capture_output=True, text=True)
    try:
        nomes = [x["filename"] for x in json.loads(r.stdout)]
        print("Anexados: " + ", ".join(nomes) + ". Cite no comentário com [^nome-do-arquivo].")
    except Exception:
        sys.exit("ERRO ao anexar: " + (r.stdout or r.stderr)[:400])


def main(a):
    if not a or a[0] in ("-h", "--help"):
        print(__doc__)
        return
    flag = lambda n: n in a and (a.remove(n) or True)
    confirmado = flag("--confirmado")
    editar = None
    if "--editar" in a:
        i = a.index("--editar")
        editar = a[i + 1]
        del a[i:i + 2]
    c = a[0]
    if c == "eu":
        cmd_eu()
    elif c == "card" and len(a) == 2:
        cmd_card(a[1])
    elif c == "comentar" and len(a) == 3:
        cmd_comentar(a[1], a[2], editar, confirmado)
    elif c == "anexar" and len(a) >= 3:
        cmd_anexar(a[1], a[2:], confirmado)
    elif c == "wiki" and len(a) == 2:
        print(md_para_wiki(open(a[1], encoding="utf-8").read()))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
