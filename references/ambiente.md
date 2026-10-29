# Ambiente local, dados e git

## Docker
- Confira com `docker ps`. Containers padrão: `superlogica-{apps,cloud,mysql,minio,redis,mockserver,memcached}` (nomes do apps e do MySQL vêm da configuração).
- Fora do ar: **avise o QA antes de subir ou reiniciar** (`docker start ...`). Reiniciar derruba o login. Se cair no meio do teste, pare e avise; não reinicie sozinho.
- "Could not determine temp directory" ao salvar ou no PHPUnit: `docker exec <container-apps> sh -c 'mkdir -p /tmp/superlogica-apps && chmod 1777 /tmp'`.
- Disco cheio derruba o MySQL: pare, avise o QA e só reinicie o container depois que ele liberar espaço.
- Dentro do Codex, se `docker` ou `curl localhost` falham só lá, é o sandbox: o QA libera rede em `~/.codex/config.toml` (`[sandbox_workspace_write]` → `network_access = true`) ou aprova o comando.

## Bases
- Schemas: `app26_<licença>` (imob) e `<licença>` (financeiro). Ex.: `app26_imob014729-001` e `imob014729-001`.
- Consulta: `scripts/q.sh` (SQL pela entrada padrão ou `-e`; `--salvar arquivo` para guardar a saída completa).
- Sem a base do cliente → peça o dump (costuma estar anexado no card). Importe com o `./subirbase.sh` da pasta `cloud-db` (backup na pasta Downloads); import manual deixa a base sem usuário/URL do app e o login falha. Avise o QA antes de importar.
- Bases imob e financeiro podem estar dessincronizadas: erro "label sem mensalidade" no financeiro = ambiente; troque de candidato.

## Dados do cenário (nesta ordem)
1. **Registro que já existe:** procure em todas as bases locais (`app26_*` que tenham a tabela do módulo, ex.: `DESPESA_PRINCIPAL`), sem limite de data, um registro que atenda a pré-condição **e** cujo contrato exista no financeiro local (`<lic>.MENSALIDADE.ST_LABEL_MENS = contrato`); senão o salvamento falha com "label sem mensalidade".
2. **Não existe → gere:** `scripts/gerar_cenario.sh <ClasseTest.php> <método>` usa os utilitários de teste do repo (criam via API, como a tela) com `MANTER_CENARIO=1` (não apaga no tearDown). Exemplo pronto no repo: `tests/Imobiliarias/Funcionalidades/EstruturaNovaDespesas/IMC1824/GerarCenarioIMC1824Test.php`. A licença é `testephpunitN`.
3. Não deu → peça o dado ao QA.

## Login no ERP local
- Usuário `superlogica`, **sem senha**, licença `<licença>-001`: `node scripts/tela/login.mjs <licença>`.
- Licenças de teste do PHPUnit (`testephpunitN`): `node scripts/tela/login.mjs testephpunit1 <destino> --teste` (gera token como `Auth::loginApps`; o redirect normal dá "Url incorreta").
- Sem Playwright: o QA entra no navegador dele com os mesmos dados.

## Git
- Os arquivos da PR não podem ter alteração local. Outros arquivos com alteração (WIP do QA) ficam intocados.
- Anote a branch em que o QA estava e volte para ela no fim (`antes_depois.sh` grava em `branch-original.txt`).
- Para testar a PR: estar na branch dela ou num master que já a contém. `scripts/antes_depois.sh` confere isso arquivo por arquivo.
- Nunca faça commit, push ou merge no repo do QA sem pedido explícito.

## Antes x depois
- Commit base: PR aberta → ponto em que saiu da base; PR mergeada → pai do merge. O `scripts/pr.sh` calcula e grava em `pr.env`.
- `scripts/antes_depois.sh antes|depois|estado <CARD>`.
- Front mudou → recarregue a página e confirme a versão carregada (procure um marcador do diff: função nova em `window`, atributo do form).
- Form PHP mudou e a tela não reflete → cache Zend local em `imobiliaria/Data/cache/financeiro/<lic>-001/zend_cache---apps_Form_*` (só local).
