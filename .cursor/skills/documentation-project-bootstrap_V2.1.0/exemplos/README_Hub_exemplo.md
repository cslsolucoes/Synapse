# Commons — índice consolidado (GestorERP)


| Campo      | Valor           |
| ---------- | --------------- |
| **Versão** | 2.2.0           |
| **Data**   | 30/03/2026      |
| **Raiz**   | `Documentation/` (relativo à pasta `GestorERP/`) |


**Convenção de caminhos:** neste pacote, ligações Markdown usam caminhos **relativos ao ficheiro actual** (ex.: `../Roteiro/...` a partir de `Planejamento/`). A partir da raiz do repositório `GestorERP/`, o núcleo documental é **`Documentation/…`** (não `Analise/Docs/` — caminho histórico obsoleto). O nome *Commons* mantém-se só como **conceito** do núcleo comum (sem pasta física `Commons/`).

Este directório agrupa o **núcleo transversal** do novo produto `GestorERP`: arquitectura, planeamento, estrutura lógica, mapeamento legado→novo, roteiro de evolução, dados e **contratos**; o **normativo de negócio** está em `RegrasNegocio/` (prefixo `GestorERP_RN-`*).

**Escopo operacional:** para geração do novo projeto, as pastas legadas (`Careli`, `COPA`, `OFICINAS`, `WhatsappAPI - Careli`, `WhatsappAPI - Agua Doce`) são tratadas apenas como referência histórica/funcional e não como parte da arquitetura física alvo.

**Stack oficial do novo projeto:** backend Delphi (RAD Studio 12/13), frontend desktop Delphi FMX e frontend web Vue.js; suporte a Free Pascal quando aplicável a módulos compartilhados.

Documentos que antes estavam em `Documentation/Arquitetura/` encontram-se **aqui**, por tema (snapshot histórico: [Analise/Analise_Gaps_V1.0.md](Analise/Analise_Gaps_V1.0.md)).

## Normativo e integração


| Pasta                                     | Conteúdo                                                             |
| ----------------------------------------- | -------------------------------------------------------------------- |
| [RegrasNegocio/](RegrasNegocio/README.md) | RNs por módulo (`RN-M01`…`RN-M33`), governo e prioridade de execução |
| [Contratos/](Contratos/README.md)         | Contratos técnicos Common ↔ produtos |
| [Versionamento/](Versionamento/CHANGELOG.md) | Trilha central de mudanças do pacote `Documentation/` |


## Documentação por tema (ordem sugerida de leitura)

1. [Arquitetura/GestorERP_Arquitetura_PROJETO_V1_0.md](Arquitetura/GestorERP_Arquitetura_PROJETO_V1_0.md) — **arquivo canônico único** da arquitetura geral do novo `GestorERP` (v2.1.0 — §6.2.1 endpoints Habil, §12.3.1 ETL 4ª fonte)
2. [Roteiro/GestorERP_ROADMAP_Index_V1_0.md](Roteiro/GestorERP_ROADMAP_Index_V1_0.md) — **índice único** roadmap / ondas / Habil
3. [Mapeamento/GestorERP_Mapeamento_HabilFinanceiro_Tabelas_V1_0.md](Mapeamento/GestorERP_Mapeamento_HabilFinanceiro_Tabelas_V1_0.md) — 248 tabelas → M01..M33
4. [Planejamento/GestorERP_Commons_Planejamento_V1_0.md](Planejamento/GestorERP_Commons_Planejamento_V1_0.md) — objectivos, stack ORM, riscos
5. [Arquitetura/GestorERP_Commons_Arquitetura_V1_1.md](Arquitetura/GestorERP_Commons_Arquitetura_V1_1.md) — suporte técnico (não canônico da arquitetura geral)
  - Pacotes **no repositório:** [Arquitetura/GestorERP_Pacotes_ORM_Repositorio_Local_V1_0.md](Arquitetura/GestorERP_Pacotes_ORM_Repositorio_Local_V1_0.md) — suporte técnico de módulos `ProvidersORM/`, `ParamentersORM/`
6. [Estrutura/GestorERP_Commons_Estrutura_V1_1.md](Estrutura/GestorERP_Commons_Estrutura_V1_1.md) — blocos `Common.`* e dependências
7. [Mapeamento/GestorERP_Commons_Mapeamento_V1_1.md](Mapeamento/GestorERP_Commons_Mapeamento_V1_1.md) — o que sobe para Commons vs produto
8. [BancoDados/Estrutura_DB_INDICE_V1_1.md](BancoDados/Estrutura_DB_INDICE_V1_1.md) — entidades comuns + variantes SQL Server / PostgreSQL ([SQLServer/README](BancoDados/SQLServer/README.md), [PostgreSQL/README](BancoDados/PostgreSQL/README.md))
9. [Roteiro/GestorERP_Commons_Roteiro_V1_1.md](Roteiro/GestorERP_Commons_Roteiro_V1_1.md) — fases, Ondas BL-011..014, entregas mínimas

## Documentos de plataforma (ex-`Documentation/Arquitetura/`)


| Área               | Ficheiros                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Arquitetura (canônica geral)**    | [GestorERP_Arquitetura_PROJETO_V1_0.md](Arquitetura/GestorERP_Arquitetura_PROJETO_V1_0.md) — v2.1.0: interfaces Commons (§4.4), RBAC (§6.1), paginação (§6.1), async (§6.1), endpoints §6.2 + §6.2.1 (Habil), catálogo de erros (§10), dicionário de entidades (§11), ETL §12 + §12.3.1 (4ª fonte) |
| **Arquitetura (suporte técnico)**    | [GestorERP_Commons_Arquitetura_V1_1.md](Arquitetura/GestorERP_Commons_Arquitetura_V1_1.md), [GestorERP_Pacotes_ORM_Repositorio_Local_V1_0.md](Arquitetura/GestorERP_Pacotes_ORM_Repositorio_Local_V1_0.md), [GestorERP_ADR_WhatsApp_Evolution_Parameters_V1_0.md](Arquitetura/GestorERP_ADR_WhatsApp_Evolution_Parameters_V1_0.md) |
| **Endpoints (novo GestorERP)** | Consolidado em [GestorERP_Arquitetura_PROJETO_V1_0.md](Arquitetura/GestorERP_Arquitetura_PROJETO_V1_0.md) §6.2 e §6.2.1; detalhe aditivo Habil em [Contratos/GestorERP_Especificacao_Endpoints_HabilFinanceiro_V1_0.md](Contratos/GestorERP_Especificacao_Endpoints_HabilFinanceiro_V1_0.md) |
| **Integração (legados WhatsApp API)** | [GestorERP_Inventario_WhatsAppAPI_Careli_vs_AguaDoce_V1_0.md](Analise/GestorERP_Inventario_WhatsAppAPI_Careli_vs_AguaDoce_V1_0.md), [CONTRATOS_WHATSAPP_EVOLUTION_V1_0.md](Contratos/CONTRATOS_WHATSAPP_EVOLUTION_V1_0.md) |
| **Estrutura**      | [GestorERP_Estrutura_PROJETO_V1_0.md](Estrutura/GestorERP_Estrutura_PROJETO_V1_0.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Banco de dados** | [GestorERP_Banco_BD_V1_0.md](BancoDados/GestorERP_Banco_BD_V1_0.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Mapeamento**     | [GestorERP_Mapeamento_3Legados_V1_0.md](Mapeamento/GestorERP_Mapeamento_3Legados_V1_0.md), [GestorERP_Refatoracao_3Legados_Mapa_Integracao_V1_0.md](Mapeamento/GestorERP_Refatoracao_3Legados_Mapa_Integracao_V1_0.md), [GestorERP_Mapeamento_HabilFinanceiro_Tabelas_V1_0.md](Mapeamento/GestorERP_Mapeamento_HabilFinanceiro_Tabelas_V1_0.md)                                                                                                                                                                                                                                                                                                                                                                                                              |
| **Roteiro**        | [GestorERP_Roteiro_PROJETO_V1_0.md](Roteiro/GestorERP_Roteiro_PROJETO_V1_0.md), [GestorERP_Caderno_Execucao_Ondas_V1_0.md](Roteiro/GestorERP_Caderno_Execucao_Ondas_V1_0.md), [GestorERP_Pacote_Execucao_Tecnica_Ondas_V1_0.md](Roteiro/GestorERP_Pacote_Execucao_Tecnica_Ondas_V1_0.md), [GestorERP_ROADMAP_Index_V1_0.md](Roteiro/GestorERP_ROADMAP_Index_V1_0.md)                                                                                                                                                                                                                                                                                                                                            |
| **Planejamento**   | [GestorERP_Backlog_Modularizacao_Execucao_V1_0.md](Planejamento/GestorERP_Backlog_Modularizacao_Execucao_V1_0.md), [GestorERP_Onda1_Baseline_Tecnico_V1_0.md](Planejamento/GestorERP_Onda1_Baseline_Tecnico_V1_0.md), [GestorERP_Matriz_Acompanhamento_Modularizacao_Semanal_V1_0.md](Planejamento/GestorERP_Matriz_Acompanhamento_Modularizacao_Semanal_V1_0.md), [GestorERP_Plano_Modularizacao_3Projetos_V1_0.md](Planejamento/GestorERP_Plano_Modularizacao_3Projetos_V1_0.md), [GestorERP_Plano_Reescrita_RN_Modular_3Legados_V1_0.md](Planejamento/GestorERP_Plano_Reescrita_RN_Modular_3Legados_V1_0.md), [GestorERP_Analise_Comparativa_RN_3Projetos_V1_0.md](Planejamento/GestorERP_Analise_Comparativa_RN_3Projetos_V1_0.md) |


## Meta-documentação (skills Cursor, lacunas, ADR)


| Ficheiro                                                                                                                           | Conteúdo                                                                               |
| ---------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| [Analise/Analise_Gaps_V1.0.md](Analise/Analise_Gaps_V1.0.md)                                                                       | Inventário do pacote `Analise/`, lacunas resolvidas, registo de sincronização de paths |
| [Analise/GestorERP_Inventario_WhatsAppAPI_Careli_vs_AguaDoce_V1_0.md](Analise/GestorERP_Inventario_WhatsAppAPI_Careli_vs_AguaDoce_V1_0.md) | Legados WhatsappAPI: entrypoints, classes, rotas Careli vs Água Doce |
| [Planejamento/GestorERP_ADR_Template_Docs_vs_AnaliseDocs_V1_0.md](Planejamento/GestorERP_ADR_Template_Docs_vs_AnaliseDocs_V1_0.md) | ADR: mapeamento template skills ↔ pasta canónica `Documentation/` no GestorERP |


## Ligações à pasta `Analise/` (fora deste índice)


| Destino                                                                                                                              | Uso                                                                                    |
| ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| [Analise/Analise_Gaps_V1.0.md](Analise/Analise_Gaps_V1.0.md) | Inventário e lacunas do pacote `Documentation/Analise/` |
| [Analise/GestorERP_Inventario_WhatsAppAPI_Careli_vs_AguaDoce_V1_0.md](Analise/GestorERP_Inventario_WhatsAppAPI_Careli_vs_AguaDoce_V1_0.md) | Inventário comparativo de legados WhatsApp API |
| `Analise/Backup/*` | Snapshot histórico (indisponível neste workspace) |
| [Analise/Analise_Gaps_V1.0.md](Analise/Analise_Gaps_V1.0.md) | Arquivo da antiga pasta `Documentation/Arquitetura/`                                            |
| `Analise/Backup/Documentacao_raiz_*` | Snapshot histórico de hubs (indisponível neste workspace) |


---

**Changelog (este arquivo):**

- 2.1.0 (30/03/2026): HabilFinanceiro — índice único de roadmap (`Roteiro/GestorERP_ROADMAP_Index_V1_0.md`); mapeamento 248 tabelas; arquitetura PROJETO v2.1.0 (§6.2.1, §12.3.1); ordem de leitura e tabelas de plataforma atualizadas.
- 2.0.0 (30/03/2026): Arquitetura PROJETO v2.0.0 referenciada com novas seções (interfaces Commons, RBAC, paginação, async, catálogo de erros, dicionário de entidades, ETL); tabela de plataforma atualizada.
- 1.9.0 (30/03/2026): `GestorERP_Arquitetura_PROJETO_V1_0.md` definido como arquivo canônico único da arquitetura geral; demais arquivos de `Documentation/Arquitetura/` marcados como suporte técnico.
- 1.9.1 (30/03/2026): Catálogo de endpoints removido como arquivo separado; endpoints consolidados no arquivo canônico de arquitetura geral.
- 1.8.0 (30/03/2026): Escopo explicitado para novo produto `GestorERP`; stack oficial (Delphi backend, FMX desktop, Vue web); entrada do catálogo de endpoints em `Contratos/`.
- 1.7.0 (30/03/2026): Secção `Versionamento/` adicionada com `Documentation/Versionamento/CHANGELOG.md`; cabeçalho do índice atualizado.
- 1.6.1 (30/03/2026): Links de arquivo histórico corrigidos para `Analise/Backup/*` (navegação válida a partir de `Documentation/`).
- 1.6.0 (27/03/2026): Raiz canónica corrigida para `Documentation/` (fim da referência obsoleta `Analise/Docs/`); tabela integração WhatsApp API; ADR template actualizado noutro ficheiro.
- 1.5.1 (27/03/2026): Inventário comparativo WhatsappAPI Careli vs Água Doce (`Analise/`).
- 1.5.0 (27/03/2026): ADR WhatsApp/Evolution/Parameters; contrato `CONTRATOS_WHATSAPP_EVOLUTION_V1_0.md`; índice Contratos e tabela Arquitetura.
- 1.4.0 (26/03/2026): Secção meta-documentação (`Analise_Gaps_V1.0`, ADR template); documentos de plataforma antes ausentes agora presentes em disco.
- 1.3.2 (24/03/2026): Entrada `GestorERP_Pacotes_ORM_Repositorio_Local_V1_0.md` na ordem de leitura (Arquitetura).
- 1.3.1 (24/03/2026): Correcção do link do hub `README_V1.0` → `../Backup/README_V1.0.md`; índice `Analise/README.md`.
- 1.3.0 (24/03/2026): Convenção de caminhos relativos; remoção da pasta `Commons/` na árvore física (conteúdo em `Documentation/<tema>/`).
- 1.2.1 (24/03/2026): Ligação ao arquivo `Documentacao_raiz_arquivo_`* (hubs de entrada).
- 1.2.0 (24/03/2026): Consolidação de `Documentation/Arquitetura/` neste índice; tabela de documentos por subpasta; arquivo datado em `Backup/Arquitetura_arquivo_2026-03-24/`; removida dependência de `Docs/Arquitetura/README.md`.
- 1.1.0 (24/03/2026): README em subpastas (BancoDados, Mapeamento, etc.); ligação explícita a `Arquitetura/README`.
- 1.0.0 (24/03/2026): índice consolidado do pacote Commons.

