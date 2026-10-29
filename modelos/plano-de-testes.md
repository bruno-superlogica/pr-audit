# Plano de testes — <CARD> · PR #<número>

- **Card:** <título do card> (<link>)
- **PR:** <título> · versão testada `<SHA curto>` · base `<SHA curto>`
- **Data:** <dd/mm/aaaa> · **QA:** <nome>
- **O que a PR muda (em linguagem de negócio):** <1–3 frases>
- **Capacidades nesta máquina:** <linha CAPACIDADES do diagnóstico>

## Cenários

| # | Cenário | Origem | Pré-condição (dado) | Esperado (verificável) | Fonte do esperado | Execução |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | <ação do usuário + situação> | Card / PR / Impacto / Leitor / Ciclo / Risco | <licença, ids, estado do registro> | <valores, tag, mensagem, registro no banco> | Critério N do card / comentário do dev / comportamento atual / inferido: <porquê> | PHPUnit / Playwright / Manual |

## Impacto levantado
- **Quem mais usa o que mudou:** <telas, rotas, forms>
- **Leitores dos campos gravados:** <campo → leitor perigoso → efeito antes x depois>
- **Ciclo de vida coberto:** <passos>

## Riscos fixos
- [ ] Regras do financeiro/cloud
- [ ] Clique duplo / reenvio
- [ ] Centavos
- [ ] Falha no meio
- [ ] Dados antigos
- [ ] Bloqueio novo / exceção
- [ ] Controle sem a PR
- [ ] Varredura (se muda cálculo)

## Conferência no banco
Consultas em `conferencia.sql` (rodar antes e depois de cada cenário).

## Não será testado
- <item> — <motivo>
