# Comentário de QA no card e problema que vira card

## 1. Escrever
Escreva `$QA_DIR/<CARD>/comentario-card.md` a partir de `modelos/comentario-card.md`. Markdown, pt-BR, linguagem de negócio (sem SQL, sem nome de classe ou arquivo). **Um bloco por item**, sempre nesta ordem:

> **QA da PR #22595 — 06/10/2026**
> Ambiente local. "Produção" = código atual do master; "PR" = código da PR.
>
> **1. Aumentar o valor de 100 para 120 com "Cobrar diferença" marcado** — ✅ Corrigido
> - **Situação testada:** Repasse do proprietário já feito no conta corrente; boleto do locatário ainda não gerado.
> - **Esperado:** Terceiro recebe 120, locatário paga 120 no próximo boleto e é lançada diferença de 20 (débito proprietário, crédito imobiliária) no mesmo mês da despesa. *Fonte: Critério 2 do card.*
> - **Produção hoje:** O valor do locatário não muda e nenhuma diferença é lançada.
> - **Com a PR:** Terceiro 120, locatário 120, diferença de 20 lançada em nov/2026.
> - **Como:** Tela + banco. Evidências: [^item1-banco.txt]
>
> **2. Aumentar o valor com "Cobrar diferença" desmarcado** — ❌ Não atende
> - **Situação testada:** A mesma do item 1.
> - **Esperado:** Locatário vai para o valor novo e nenhuma diferença é lançada. *Fonte: Critério 4 do card.*
> - **Produção hoje:** Não rodado.
> - **Com a PR:** Erro "as movimentações não podem ser excluídas, pois já foram repassadas".
> - **Como:** PHPUnit. Evidências: [^item2-phpunit.log]

Regras do bloco:
- Depois de dois-pontos, sempre letra maiúscula.
- **Título** = a ação em linguagem do usuário + o resultado: `✅ Corrigido` (produção errada, PR certa), `✅ Mantido` (as duas certas), `❌ Regressão` (produção certa, PR errada), `❌ Não atende` (as duas erradas, ou PR errada sem rodada de produção), `⚠️ Verificar` (o esperado foi inferido e a PR difere).
- **Esperado** sempre com a *fonte*: critério do card, comentário do dev, comportamento atual que deve ser mantido, ou *inferido pela IA* + uma frase do porquê.
- **Produção hoje** só com rodada real no código base; senão "Não rodado".
- **Como:** PHPUnit, Tela (Playwright), Manual pelo QA, Banco — e as evidências anexadas.
- No fim: **❌ Problemas encontrados** (cada linha com ❌ defeito ou ⚠️ alerta), **⚠️ Regra de negócio a confirmar**, **Não testado** (item — motivo) e, se houver, **Casos em produção** (Metabase). Problema sem emoji é erro de formato.
- Separe o que foi conferido (banco/tela) do que é leitura de código; não marque ✅ sem conferência.
- Comentário anterior de QA da mesma PR: substitua-o (`--editar <id>`; o id está em `card.md`) ou diga no topo que ele foi substituído e por quê.

## 2. Evidências
Nomeie por item: `itemN-phpunit.log`, `itemN-banco.txt`, `itemN-tela.json`, mais `phpunit-completo-{producao,pr}.log`. Copie de `resultados/` com esses nomes. No comentário, `[^nome-do-arquivo]` vira link para o anexo.

## 3. Publicar (só com o ok do QA)
```
scripts/jira.py comentar <CARD> $QA_DIR/<CARD>/comentario-card.md               # prévia, nada é publicado
# mostre ao QA; com o ok:
scripts/jira.py anexar <CARD> $QA_DIR/<CARD>/evidencias/* --confirmado
scripts/jira.py comentar <CARD> $QA_DIR/<CARD>/comentario-card.md --confirmado
```
Informe o link do comentário. Se o pedido de teste já autorizou postar, publique direto e envie o link.
**Sem credenciais do Jira:** entregue `comentario-card.md` (o editor do Jira aceita Markdown colado) e a pasta de evidências para o QA anexar à mão.

## 4. Problema encontrado (no comentário ou em card novo)
Todo problema leva ❌ (defeito) ou ⚠️ (alerta/a confirmar) e estas seções, nesta ordem:
1. **Como era antes** das alterações da PR que causou ou expôs o problema — rode o cenário no código base e use os valores reais.
2. **Como ficou depois** — valores reais com a PR.
3. **Condições para acontecer** — todas, com a configuração da licença pelo rótulo da tela (e onde fica; os rótulos estão em `imobiliaria/Forms/Configuracoes/Index.php`) e o motivo de negócio.
4. **Como replicar** — passo a passo pela tela para o desenvolvedor.
5. **Regra de negócio da correção** — como deve ficar, com o resultado esperado em números, e **critérios de aceite**.
6. **Desde quando** — `git -C "$APPS_DIR" log -S '<símbolo ou trecho>' --format='%h %ad %an %s' --date=short origin/master` no código que causa e no que torna o caso alcançável (config, opção de tela). Diga a data de origem e as datas em que ficou mais frequente.
7. **Correção de código x correção de dados** — se a PR (ou outra) resolve daqui para frente e quais registros já gravados precisam de ajuste.

**Uma causa raiz = um card.** Antes de dizer que um passo a passo "não reproduz", procure a trava no código e diga desde quando existe (`git log -S`); se o card ensina um caminho que a tela bloqueia, corrija o passo a passo com o caminho que reproduz. Sem reprodução, comente o que foi testado e o que pode faltar.
Problema fora do escopo da PR vira **card próprio** (IMC, com componente) nesse formato, com evidência anexada, e o link vai no comentário de QA. Criar card só com o ok do QA.
