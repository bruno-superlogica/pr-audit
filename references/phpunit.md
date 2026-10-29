# PHPUnit

- Roda **no container**, nunca direto na máquina: `scripts/rodar_phpunit.sh` cuida disso.
- **Um teste por vez** (`--filter`): a suíte para no primeiro erro e esconde os outros. O script separa por método automaticamente.
- O arquivo de teste novo mora em `$QA_DIR/<CARD>/` (durável). Ele é copiado para `tests/` só durante a rodada e removido no fim — nunca fica no repo do QA:
  `scripts/rodar_phpunit.sh <CARD> antes $QA_DIR/<CARD>/CenariosXTest.php --destino tests/Imobiliarias/QA/<CARD>/CenariosXTest.php`
- Teste que já existe no repo: `scripts/rodar_phpunit.sh <CARD> depois tests/.../XTest.php [--testes testA,testB]`.
- Crie os dados **como a tela cria** (mesmas rotas da API: `imoveis/put` cria, `imoveis/post` com `ID_IMOVEL_IMO` edita; contrato → faturar → liquidar). Dado inserido direto no banco pula regras da tela e dá falso resultado. Ex.: IMC-1961 — pelo banco: Ana 2.700 / Filho 900; pela tela (`pessoas/post`): Ana 3.600 / Filho 0.
- Imprima no teste linhas `[QA] ...` com os valores que importam: o resumo do script mostra essas linhas.
- Rode cada cenário no código base (ANTES, com `antes_depois.sh antes`) e na PR (DEPOIS) para preencher "Produção hoje" com número real.
- Falha de ambiente (login 404, temp dir) → corrija e rode de novo antes de concluir algo.
- Suíte existente da pasta afetada: rode também e compare com o master. Falha que já existe sem a PR é "base de teste suja", não regressão.
- Saída completa em `$QA_DIR/<CARD>/resultados/phpunit_<fase>.txt` — é ela que vai anexada ao card.
