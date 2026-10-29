# Casos de borda em lote (Metabase, opcional)

Precisa de `METABASE_URL` e `METABASE_API_KEY` na configuração (`./configurar.sh`, item 6). Sem isso, pule e registre em "Não testado".

Antes dos testes de tela, minere em produção (réplica, **só SELECT**) os casos de borda que o diff toca:
1. Liste os schemas `app26_%` de cada shard via `information_schema`:
   `scripts/metabase.sh <id-do-banco> --salvar $QA_DIR/<CARD>/resultados/schemas.tsv <<'SQL'`
   `SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'app26\_%'`
2. Rode a classificação em lotes de ~15 schemas com `UNION ALL` (um `SELECT '<schema>' lic, ... FROM \`<schema>\`.TABELA WHERE ...` por schema), gravando com `--salvar`.
3. Monte a tabela `caso | itens | licenças | exemplo`. Casos com volume e não citados no card viram cenários (tela, PHPUnit ou ambos) e entram em "Casos em produção" no comentário.

- 401 = chave expirada ou sem permissão; avise o QA.
- No contexto, só o agregado; o detalhe fica nos arquivos.
- Na estágio, o mesmo script serve para conferir antes e depois (licença `imoestagio`).
