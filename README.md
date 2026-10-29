# testar-pr

Skill de apoio a QA para testar PRs do **apps** (ERP imobiliário). Funciona no **Codex CLI** e no **Claude Code**.

A partir do card do Jira e da PR, ela monta os cenários (incluindo impacto no código), gera plano e roteiro de teste, roda PHPUnit antes x depois, confere no banco local, executa passos de tela com Playwright quando o QA quiser e prepara o comentário de QA no card.

**Nada é impeditivo.** A skill faz o que der com o que cada pessoa tem:

| Você tem | A skill entrega |
| --- | --- |
| Só o texto do card e da PR | Cenários, checklist de riscos, roteiro manual e o comentário pronto para colar |
| + projeto `apps` local | Impacto pelo código (quem chama, quem lê os campos alterados) e "desde quando" |
| + Docker do ambiente local | PHPUnit antes x depois e conferência no banco |
| + token do Jira | Lê o card direto e publica o comentário (sempre depois do seu ok) |
| + `gh` autenticado | Lê título, descrição e versão da PR direto |
| + Playwright | Executa passos de tela — você decide em cada teste se vale a pena |

## Instalação (Linux)

```bash
git clone https://github.com/bruno-superlogica/pr-audit.git ~/ferramentas/testar-pr
cd ~/ferramentas/testar-pr
./instalar.sh
```

O `instalar.sh`:
1. confere os programas (git, curl, python3, node 18+, docker, gh, codex);
2. instala o Playwright e, se você quiser, baixa o Chromium (~150 MB, uma vez);
3. cria os links da skill em `~/.agents/skills/testar-pr` (Codex) e `~/.claude/skills/testar-pr` (Claude Code);
4. se você quiser, registra o Playwright MCP no Codex e no Claude Code;
5. chama o `configurar.sh`.

O `configurar.sh` pergunta (tudo pode ser pulado):
- onde está o seu projeto `apps`;
- onde guardar o material (padrão `~/qa-testes`);
- nomes dos containers e a licença local padrão;
- e-mail e token do Jira ([gerar token](https://id.atlassian.com/manage-profile/security/api-tokens));
- se quer usar a tela com Playwright;
- Metabase (avançado).

A configuração fica em `~/.config/testar-pr/config.env`, com permissão só sua. O token nunca fica na pasta da skill.
Rode `./configurar.sh` de novo para mudar algo e `./configurar.sh --mostrar` para ver a configuração atual.

## Atualizar

```bash
cd ~/ferramentas/testar-pr && git pull && ./instalar.sh --sem-config
```

## Usar

No Codex (ou no Claude Code), dentro de qualquer pasta:

```
Testar a PR 22595 do card IMC-1824
```

A skill começa por um diagnóstico, diz o que vai conseguir fazer e segue. Antes de executar, ela pergunta se você quer usar o Playwright em cada teste e recomenda com o motivo — para API, mensagens ou cálculo conferido no banco, normalmente não compensa.

O material de cada card fica em `~/qa-testes/<CARD>/`:
- `card.md`, `pr.md`, `pr.diff`, `arquivos.txt` — entrada;
- `plano-de-testes.md`, `roteiro-manual.md`, `conferencia.sql` — o que testar e como;
- `resultados/` — logs de PHPUnit, banco e tela;
- `comentario-card.md` — o comentário de QA (publicado só depois do seu ok).

### Codex: sandbox
O Codex bloqueia rede nos comandos por padrão. Para a skill falar com o Docker, o ERP local (`localhost:8080`) e o Jira, libere em `~/.codex/config.toml`:

```toml
[sandbox_workspace_write]
network_access = true
```

Ou aprove os comandos quando o Codex pedir. Sem isso a skill continua, só que no modo manual.

### Custo
O Playwright é gratuito e local. O que custa é o modelo: cada tela lida pelo Playwright MCP vira tokens na sua chave. Por isso a skill usa por padrão as receitas por script (a página não passa pelo modelo) e deixa o MCP para explorar telas novas.

## Scripts (para uso direto)

| Script | Para quê |
| --- | --- |
| `scripts/diagnostico.sh` | O que está disponível agora |
| `scripts/pr.sh <PR> <CARD>` | Baixa a PR, calcula a base, grava diff e arquivos |
| `scripts/jira.py card\|comentar\|anexar\|eu` | Jira (com prévia e `--confirmado`) |
| `scripts/leitores.sh <CARD> <CAMPO>...` | Quem lê os campos que a PR passou a gravar |
| `scripts/antes_depois.sh antes\|depois\|estado <CARD>` | Troca os arquivos da PR pela versão base e volta |
| `scripts/rodar_phpunit.sh <CARD> <fase> <teste>` | PHPUnit no container, um teste por vez |
| `scripts/gerar_cenario.sh <Teste.php> <método>` | Gera dado de teste pelos utilitários do repo |
| `scripts/q.sh` | SQL no MySQL local |
| `scripts/metabase.sh` | SELECT no Metabase (opcional) |
| `scripts/tela/navegador.mjs abrir\|estado\|fechar` | Navegador de QA próprio |
| `scripts/tela/login.mjs <licença> [--teste]` | Login no ERP local |
| `scripts/tela/receita.mjs <receita.json>` | Executa uma receita de tela |
| `scripts/tela/qa.mjs <comando>` | Comandos avulsos na tela |
| `scripts/split/*` | Cenários de split/PJBank no sandbox |

## Problemas comuns
- **"container fora do ar"**: suba o ambiente (`docker start ...`) e rode de novo.
- **Jira 401**: token vencido; rode `./configurar.sh` e informe um novo.
- **Chromium não encontrado**: `cd ~/ferramentas/testar-pr && npx playwright install chromium` (se faltar biblioteca do sistema: `npx playwright install --with-deps chromium`).
- **Porta do navegador ocupada**: `QA_PORTA=9448 node scripts/tela/navegador.mjs abrir`.
