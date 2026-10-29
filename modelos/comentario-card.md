**QA da PR #<número> — <dd/mm/aaaa>**
Ambiente local. "Produção" = código atual do master; "PR" = código da PR (versão `<SHA curto>`).

**1. <Ação em linguagem do usuário>** — ✅ Corrigido
- **Situação testada:** <Situação do dado>.
- **Esperado:** <Resultado com números>. *Fonte: <Critério N do card | comentário do dev | comportamento atual | inferido pela IA: porquê>.*
- **Produção hoje:** <Resultado real no código base | Não rodado>.
- **Com a PR:** <Resultado real com a PR>.
- **Como:** <PHPUnit | Tela (Playwright) | Manual pelo QA | Banco>. Evidências: [^item1-phpunit.log]

**2. <Ação>** — ✅ Mantido
- **Situação testada:** <...>.
- **Esperado:** <...>. *Fonte: <...>.*
- **Produção hoje:** <...>.
- **Com a PR:** <...>.
- **Como:** <...>. Evidências: [^item2-banco.txt]

**❌ Problemas encontrados**
- ❌ <Defeito> — <onde e efeito>. Card: <link, se criado>
- ⚠️ <Alerta> — <o que confirmar>

**⚠️ Regra de negócio a confirmar**
- <Pergunta objetiva para produto/dev>

**Não testado**
- <Item> — <motivo>
