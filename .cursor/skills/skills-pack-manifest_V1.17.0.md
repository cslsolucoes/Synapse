# Versão interna — `.cursor/skills/`

**FolderVersion:** 1.17.0 · **Data:** 18/04/2026
**Política:** [../VERSION.md](../VERSION.md)

Skills organizadas por pasta **`<identificador>_V{MAJOR.MINOR.PATCH}/`** (sufixo = versão SemVer do `SKILL.md`), com ficheiro **`SKILL.md`** obrigatório dentro.

**Total V1.17.0: 181 pastas activas.** (Delta vs estado real = +1: `project-query-docs-index_V1.0.0` criada. Nota: o manifesto V1.16.0 declarava 178 pastas, mas a contagem real do filesystem era 180 quando foi publicado — ajuste feito aqui sem reescrita retroativa.)

## Onda pós-indexação `.docs/Assembly/` — 18/04/2026

### 1 skill nova: `project-query-docs-index_V1.0.0`

Skill de **consulta** (leitura) dos três índices SQLite + FTS5 do workspace:

- `.cursor/index.db` — pack (skills, agents, rules)
- `.workspace/index.db` — artefactos do clone (`gestorerp-*`)
- `E:\.docs\index.db` — docs técnicos locais (Assembly/Delphi/LDAP)

Complementa o command `/syncdb` (escrita/sincronização) com o fluxo inverso (leitura offline BM25-ranked), cobrindo sintaxe FTS5 (operadores, pegadinha do hífen como operador NOT), 7 receitas canónicas, interpretação de ranking BM25, integração com `Read`/`Grep` e troubleshooting.

**Categoria:** `project`. **Path:** `.cursor/skills/project-query-docs-index_V1.0.0/SKILL.md`.

### Contexto

Criação motivada pela finalização da documentação offline em `E:\.docs\Assembly\` (53 MDs) e indexação em `E:\.docs\index.db` (scope `project`, introduzido em `pack_index_db.py` 1.1.0 de 18/04/2026). Até este momento, o pack só tinha o lado de **escrita** coberto (`/syncdb`); a skill nova fecha o ciclo cobrindo também o lado de **leitura**, tornando o fluxo offline-first completo.

## Histórico anterior (Onda 5 do refactor — 17/04/2026)

### 8 skills AD/RDW generificadas

Paths hardcoded substituídos por `{ACTIVE_DIRECTORY_ORM_ROOT}` / `{REST_DATAWARE_ROOT}` com resolução via `.cursor/config.json._frameworks`:

- `developer-delphi-active-directory-expert_V1.0.0`
- `developer-delphi-active-directory-estrutura_V1.0.0`
- `developer-delphi-active-directory-roteiro_V1.0.0`
- (orchestrators AD + RDW e RDW-estrutura/roteiro já estavam genéricos)

### 1 SPLIT: developer-delphi-rest-dataware-expert

Secção "GestorERP — Controllers e fluent handlers (MXX pattern)" (linhas 236–322 do original) extraída para `.workspace/skills/gestorerp-mxx-rest-dataware-controllers_V1.0.0/SKILL.md`. Skill em `.cursor/skills/` agora 100% genérica (arquitetura RDW V2.1 + 5 camadas + componentes).

### 1 SPLIT: developer-delphi-modular-backend-scaffold

Conteúdo MXX concreto (paths `M01-Seguranca_Acesso`, defines `USE_*` deste clone, template `database.ini` com `GestorERP_Dev`) extraído para `.workspace/skills/gestorerp-mxx-scaffold_V1.0.0/SKILL.md`. Skill em `.cursor/skills/` agora usa placeholders `{BACKEND_ROOT}`, `<ModulePattern>`, `<Domain>`.

### 1 MOVE: developer-web-vue-gestorerp-alignment → .workspace/

Skill inteira migrada para `.workspace/skills/gestorerp-frontend-alignment_V1.0.0/SKILL.md`. Vue/Pinia/Vite genérico continua coberto pelas skills `developer-vuejs-*` em `.cursor/skills/` (core, routing-state, components-reactivity).

## Changelog (este arquivo)

- 1.17.0 (18/04/2026): **FolderVersion** 1.17.0 — +1 skill nova `project-query-docs-index_V1.0.0` (consulta dos 3 índices FTS5, categoria `project`). **Total real: 181 pastas em `.cursor/skills/`** (contagem real do filesystem: 180 antes da criação; +1 desta onda). Nota de auditoria: o manifesto V1.16.0 declarava 178 pastas, mas a contagem efectiva era 180 — discrepância documentada e corrigida aqui sem reescrita retroativa.
- 1.16.0 (17/04/2026): **FolderVersion** 1.16.0 (Onda 5 do refactor) — 8 skills AD/RDW generificadas (paths lidos de `_frameworks`); 2 SPLITs (rest-dataware-expert; modular-backend-scaffold) com conteúdo MXX extraído para `.workspace/skills/`; 1 MOVE (developer-web-vue-gestorerp-alignment → `.workspace/skills/gestorerp-frontend-alignment`). **Total: 178 pastas em `.cursor/skills/`** (era 179; −1 movida).
- 1.15.0 (17/04/2026): **FolderVersion** 1.15.0 (Onda 3) — 8 renames + 2 consolidações de skills `project-*` (ver histórico arquivado).
- (histórico preservado — ver V1.15.0 arquivada).
