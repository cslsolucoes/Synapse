# .cursor — ActiveDirectoryORM

<!-- internal_file_version: 2.2.0 -->

Hub do pack de ferramentas (rules, skills, agents, templates, scripts) utilizado
pelo projecto **ActiveDirectoryORM**. Este pack e **SSOT** — fonte canonica dos
espelhos em `.claude/`, `.vscode/`, `.continue/` e `.opencode/` (symlinks).

---

## Versionamento da estrutura `.cursor/`

| Area | Manifesto | Politica |
| ---- | --------- | -------- |
| **Skills** | `skills/skills-pack-manifest_V1.17.0.md` | skill `governance-pack-versioning-policy_V1.0.0` |
| **Agents** | `agents/` (inventario) | idem |
| **Rules** | `rules/rules-pack-manifest_V1.6.0.md` | idem |
| **Templates** | `Templates/templates-pack-manifest*.md` | idem |
| **Commands** | `commands/commands-pack-manifest_V1.2.0.md` | idem |
| **Scripts** | `scripts/scripts-pack-manifest_V1.4.0.md` | idem |

**Politica de versionamento:** [`VERSION.md`](VERSION.md) + skill `governance-pack-versioning-policy_V1.0.0`.

---

## Scripts de automacao

| Script | Tipo | Funcao |
| ------ | ---- | ------ |
| `bootstrap-mirror-symlinks.ps1` | PowerShell | Cria/valida symlinks dos espelhos (`.claude`, `.vscode`, `.continue`, `.opencode`). Requer Admin. |
| `bootstrap-build-config.ps1` | PowerShell | Gera/valida ficheiros de build do projecto (`dcc32.cfg`, `dcc64.cfg`, `fpc32.opts`, `fpc64.opts`). |
| `bootstrap-reset.ps1` | PowerShell | Reset controlado do ambiente de bootstrap. |
| `bootstrap-form-unit.ps1` | PowerShell | Gera form units sob demanda (VCL/FMX/LCL). |
| `sync-cursor-pack.ps1` | PowerShell | Sincroniza o pack `.cursor/` para outros projectos. |
| `validate_pack.py` | Python | Valida integridade de skills/rules/agents. |
| `pack_index_db.py` | Python | Gestor do indice SQLite (FTS5) do pack. Operacoes: `--init`, `--scan`, `--query`, `--stats`. |

---

## Slash commands disponiveis

| Comando | Script invocado | Funcao |
| ------- | --------------- | ------ |
| `/consolidar` | `project-consolidate-orchestrator` | Auditoria do workspace (pack + docs + src). |
| `/migration-plan` | `documentation-migration-plan` | Plano de migracao documental. |
| `/sync-cursor-pack` | `sync-cursor-pack.ps1` | Propaga pack para projectos destino. |
| `/syncdb` | `pack_index_db.py --scan all` | Sincroniza indices SQLite do pack. |
| `/validate-docs` | `documentation-project-scan` | Valida coerencia da Documentation/. |

---

## Estrutura

| Pasta / ficheiro | Descricao |
| ---------------- | --------- |
| **Templates/** | Ficheiros-modelo `TEMPLATE_*.md` (e HTML/JS) para scaffolding de Documentation e Analise. |
| **rules/** | Rules Cursor activas (`.mdc`) — ver `rules/rules-pack-manifest_V1.6.0.md`. |
| **skills/** | Skills `developer-*`, `governance-*`, `project-*`, `documentation-*`. |
| **agents/** | Agentes de documentacao, desenvolvimento Delphi, governanca, qualidade, versionamento. |
| **commands/** | Comandos slash (`.md`). |
| **plans/** | Planos de execucao — convencao `<nome>_V<versao>.plan.md`. |
| **scripts/** | Scripts PowerShell e Python de automacao. |
| **Templates/** | Templates de scaffolding por area. |
| **[VERSION.md](VERSION.md)** | Politica de versionamento. |

---

## Espelhos (`.claude`, `.vscode`, `.continue`, `.opencode`)

Sao **ligacoes simbolicas** (symlinks) de `.cursor/` para as pastas mirror.
Isto permite que Claude Code, VS Code, Continue.dev e OpenCode acedam ao
mesmo conteudo sem duplicacao.

### Bootstrap (criar/verificar espelhos)

**Pre-requisito:** Administrador (ou Developer Mode activo com permissao real para symlinks).

```powershell
# Criar symlinks em falta (abre UAC se necessario)
.\.cursor\scripts\bootstrap-mirror-symlinks.ps1

# Verificar estado (sem alterar nada)
.\.cursor\scripts\bootstrap-mirror-symlinks.ps1 -ValidateOnly

# Reparar symlinks quebrados
.\.cursor\scripts\bootstrap-mirror-symlinks.ps1 -Repair
```

### O que e espelhado (symlinks)

| Tipo | Itens |
| ---- | ----- |
| **Directorios** | `agents/`, `plans/`, `rules/`, `skills/`, `Templates/`, `commands/` |
| **Ficheiros** | `VERSION.md`, `README.md` |

### Ficheiros NAO espelhados

Ficheiros especificos de cada IDE permanecem reais:

- `.vscode/settings.json`, `tasks.json`, `extensions.json`
- `.claude/settings.json`, `settings.local.json`

Templates para inicializar estes ficheiros: [Templates/mirror-config/](Templates/mirror-config/README.md).

---

## Bases de dados de indice (SQLite + FTS5)

| Ficheiro | Conteudo | Propagacao |
| -------- | -------- | ---------- |
| `.cursor/index.db` | Metadados de skills + agents + rules + docs do pack | Sim (via `sync-cursor-pack`; destino regenera) |
| `.workspace/index.db` | Metadados de artefactos deste clone | Nao (ignorado) |

Schema com FTS5 + indices multi-coluna. Updates incrementais por hash SHA-256.

Consulta: `python .cursor/scripts/pack_index_db.py --query "<keywords>"`.

---

## Workflow de geracao documental

Sequencia recomendada para gerar documentacao completa de um projecto Delphi/FPC:

| Ordem | Skill | Resultado |
| --- | --- | --- |
| 0 | `documentation-project-bootstrap` | Cria `Documentation/` com subpastas obrigatorias, hub e changelog. |
| 1 | `documentation-paste_analysis` | Cria `Analise/` (scaffolding: subpastas por dominio + `{ClassName}.md` placeholder). |
| 1b | `documentation-overview-architecture` | Quality model Overview + Architecture em `Documentation/Arquitetura/`. |
| 2 | `documentation-class-analysis-generator` | Preenche conteudo completo em cada `{ClassName}.md`. |
| 3 | `documentation-project-feature` | Matriz de lacunas, RN, checklist e backlog. |
| 3b | `documentation-business-rules` | Regras de Negocio em formato padrao (12 seccoes). |
| 4 | `documentation-project-scan` | Inventario completo + gaps. |
| 5 | `documentation-migration-backup` | Migracao documental (se necessario) com backup. |
| 6 | `documentation-rules_creator` | Sintetiza `.cursor/rules/` a partir da documentacao. |

**Nota:** As ordens 1/1b e 3/3b podem executar em paralelo. A ordem 0 e pre-requisito para todas as outras.

---

## Convencoes de nomenclatura

### Regras de Negocio — formato padrao

Todas as RN seguem o formato com **12 seccoes obrigatorias**:

1. Cabecalho de identificacao (ID, Modulo, Fase, Prioridade, Status, Titulo, Ref. Arquitetura)
2. PRE-CONDICOES
3. FLUXO PRINCIPAL
4. FLUXOS DE EXCECAO
5. VALIDACOES
6. TABELAS / CAMPOS DO BANCO DE DADOS
7. IMPACTO EM OUTRAS RNs
8. LGPD
9. ESBOCO DE IMPLEMENTACAO
10. NOTAS / OBSERVACOES
11. Assinaturas

Referencia: skill `documentation-business-rules` (templates e gold standard).

### Analise/ — nomenclatura de ficheiros

- **`{ClassName}.md`** sem prefixo `T`/`I` no nome do ficheiro (ex.: `TConnection` / `IConnection` geram `Connection.md`).
- Tipos `T...` e `I...` com o mesmo sufixo Pascal partilham o mesmo ficheiro.
- Referencia: skill `documentation-paste_analysis` (canonica para `Analise/`).

---

## Referencias externas

- **Analise:** [../Analise/README.md](../Analise/README.md) (quando existir).
- **Documentacao:** [../Documentation/README_V1.0.md](../Documentation/README_V1.0.md).
- **Changelog:** [../Documentation/Versionamento/CHANGELOG.md](../Documentation/Versionamento/CHANGELOG.md).
- **CLAUDE.md:** [../CLAUDE.md](../CLAUDE.md) — guia para agents Claude Code.

---

## Estrutura final `.cursor/`

```text
.cursor/
|- README.md                          # este ficheiro (hub)
|- VERSION.md                         # politica de versionamento
|- config.json                        # config do pack
|- index.db                           # indice SQLite (FTS5)
|- pack-inventory.json                # inventario do pack
|- Templates/                         # ficheiros-modelo
|- agents/                            # agents de documentacao, Delphi, governance
|- commands/                          # comandos slash
|- docs/                              # documentacao auxiliar do pack
|- plans/                             # planos de execucao
|- rules/                             # rules Cursor activas (.mdc)
|- scripts/                           # scripts de automacao
|- skills/                            # skills developer-*, governance-*, documentation-*, project-*
```

---

**Changelog (este ficheiro):**

- 2.2.0 (21/04/2026): Destacamento do pack mae — remocao de referencias GestorERP/M01-M33 e paths absolutos (`E:\Providers.2.1.0\`); README neutralizado para projecto standalone ActiveDirectoryORM; tabelas simplificadas; seccoes longas absorvidas pelo manifesto de cada area.
- 2.1.0 (11/04/2026): Auditoria de coerencia no pack mae. Historico pre-2.2.0 preservado em `.cursor_backup_2026-04-21/README.md`.
