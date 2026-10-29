# Roteiro manual — <CARD> · cenário <N>: <nome>

**Objetivo:** <o que este cenário prova>
**Licença:** <licença> · **Registro:** <ids>
**Versão:** rodar uma vez em ANTES (código base) e uma vez em DEPOIS (código da PR), quando possível.

## Pré-condição
- <estado do dado antes de começar; como conferir na tela ou no banco>

## Passos
| # | Onde (tela › menu) | Ação | O que observar |
| --- | --- | --- | --- |
| 1 | <Despesas › linha da Água> | <Clique em "Alterar valor no a pagar"> | <Abre o formulário com valor 100,00> |
| 2 | | <Digite 120 no valor (só dígitos)> | <Campo mostra 120,00> |
| 3 | | <Salvar → Confirmar> | <Mensagem de sucesso; tag "Diferença ignorada" na linha> |

## Resultado esperado
- **Tela:** <valores, tag, mensagem>
- **Banco:** <tabela/campo = valor> (consulta em `conferencia.sql`, bloco <N>)

## Resultado obtido (preencher)
| Versão | Tela | Banco | Ok? |
| --- | --- | --- | --- |
| ANTES | | | |
| DEPOIS | | | |

## Desfazer (se precisar repetir)
- <como voltar o dado ao estado inicial>
