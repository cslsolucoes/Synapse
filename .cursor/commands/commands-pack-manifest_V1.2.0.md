---
name: commands-pack-manifest
description: Manifesto da pasta .cursor/commands/ — inventário de commands activos com FileVersion e descrição
type: manifest
FileVersion: 1.2.0
FolderVersion: 1.2.0
---

# Versão interna — `.cursor/commands/`

**FolderVersion:** 1.2.0 · **Data:** 16/04/2026
**Política:** [../VERSION.md](../VERSION.md)

Commands activos:

| Arquivo | FileVersion | Descrição |
| ------- | :---------: | --------- |
| `migration-plan.md` | 1.1.0 | Gera plano de migração documental — analisa gaps, propõe fases com matriz origem/destino |
| `sync-cursor-pack.md` | 1.1.0 | Propaga o pack `.cursor/` para projectos destino via `sync_cursor_pack.py` |
| `validate-docs.md` | 1.1.0 | Valida integridade da documentação e conformidade de artefactos |
| `consolidar.md` | 1.0.0 | Auditoria consolidada (cursor, docs, source ou all) — rota para a família `project-consolidate-*` |

Todos os commands seguem o padrão V2: seções **Escopo**, **Skills invocadas** (tabela), **Parâmetros**, **Comportamento**, **Exemplos de uso**, **Versão interna**, **Changelog**.

## Changelog (este arquivo)

- 1.2.0 (16/04/2026): **FolderVersion** 1.2.0; novo command `consolidar.md` (1.0.0) — slash command `/consolidar <alvo>` que invoca a família `project-consolidate-*` (orchestrator + 3 especializadas). 4 commands no total.
- 1.1.0 (09/04/2026): Manifesto inicial da pasta `commands/` — 3 commands em FileVersion 1.1.0; padrão V2 completo.
