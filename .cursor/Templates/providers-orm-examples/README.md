# Templates — ProvidersORM Examples

<!-- FileVersion: 1.0.0 · Data: 17/04/2026 -->

## Propósito

Templates de referência com **exemplos concretos do framework ProvidersORM** — códigos de excepção canónicos, listas de forms de teste, estruturas de módulos ORM. Conteúdo extraído dos agents `developer-delphi-agent-*` durante a Onda 4 do refactor para manter os próprios agents genéricos.

## Escopo

Estes templates aplicam-se a **qualquer projeto que adopte o framework ProvidersORM** — não são específicos do GestorERP. O mapa concreto de módulos MXX do GestorERP fica em `.workspace/rules/gestorerp-mxx-naming_V1.0.0.mdc`.

## Conteúdo

| Ficheiro | Descrição |
|---|---|
| `exception-codes.md` | Tabela canónica de códigos de excepção do ProvidersORM (EConnectionException 40001–40019, EDatabaseException, etc.) |
| `test-forms.md` | Padrão de forms de teste `ufrm*Teste` para validar módulos ORM (ufrmConnectionTeste, ufrmDatabaseTeste, etc.) |
| `module-structure.md` | Estrutura interna canónica de cada módulo ORM (src/Modulos/<Module>/, src/Main/<Module>.pas, src/Main/<Module>.Interfaces.pas) |

## Changelog

- 1.0.0 (17/04/2026): criação — extracção dos agents `developer-delphi-agent-*` na Onda 4 do refactor.
