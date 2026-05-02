# OIDs ICP-Brasil DOC-ICP-04

Constantes de OIDs definidas no DOC-ICP-04 do ITI (Instituto Nacional de
Tecnologia da Informacao). Identificam campos especificos do certificado
digital brasileiro presentes no `subjectAltName.otherName`.

> **V41.5 (S8) — actualizacao:** adicionados OIDs `.2`, `.3` (legacy CNPJ
> com fallback automatico), `.10` (OAB digital) + parsers para `.5`/`.6`/`.8`
> agora populam o record. Nota sobre evolucao DOC-ICP-04 v3 → v6+ (CAEPF
> substituiu CEI em 2018) na coluna **Formato**.

## Tabela de OIDs

| OID | Constante (`ssl_openssl_icpbrasil_oids`) | Significado | Formato (PrintableString) | V | Parser/Campo no record |
| --- | --- | --- | --- | --- | --- |
| `2.16.76.1.3.1` | `OID_ICPBR_E_CPF_DATA` | e-CPF: dados do titular PF | `DDMMYYYY` (8) + CPF (11) + NIS (11) + RG (15) + emissor (6) | v3+ | `ParseEcpfData` → `ResponsavelCpf`/`ResponsavelNasc`/`ResponsavelRg`/`ResponsavelEmissor` |
| `2.16.76.1.3.2` | `OID_ICPBR_PJ_NOME_LEGACY` | Nome PJ legacy (DOC-ICP-04 pre-v3) | PrintableString com nome empresarial | <v3 | Reconhecido via `IsOidIcpBrasilPJ`; parser pendente (raro) |
| `2.16.76.1.3.3` | `OID_ICPBR_E_CNPJ_LEGACY` | **e-CNPJ legacy: CNPJ da empresa (formato pre-v3)** | `<14 digitos>` | <v3 | Fallback automatico em `TentarExtrairCnpjPJ` quando `.7` ausente — popula `SubjectDocumento` |
| `2.16.76.1.3.4` | `OID_ICPBR_E_CNPJ_RESPONSAVEL` | e-CNPJ: dados do PF responsavel | mesmo formato de `OID_ICPBR_E_CPF_DATA` | v3+ | `ParseEcnpjResponsavel` → `ResponsavelCpf`/`ResponsavelNasc` |
| `2.16.76.1.3.5` | `OID_ICPBR_E_CPF_TITULO` | e-CPF: titulo de eleitor | numero (12) + zona (3) + secao (4) + municipio (6) + UF (2) | v3+ | `ParseTituloEleitor` → `TituloEleitor` (V41.5) |
| `2.16.76.1.3.6` | `OID_ICPBR_E_CPF_INSS` | e-CPF: PIS/PASEP (v3) ou CAEPF/CEI (v6+) | `<11 digitos>` (PIS) / `<12 digitos>` (CEI legacy) / `<14 digitos>` (CAEPF) | v3..v8 | `ParsePisOuCaepf` → `PisOuCaepf` (V41.5) |
| `2.16.76.1.3.7` | `OID_ICPBR_E_CNPJ_DATA` | e-CNPJ: CNPJ da empresa (formato moderno) | `<14 digitos>` | v3+ | `ParseEcnpjData` → `SubjectDocumento` |
| `2.16.76.1.3.8` | `OID_ICPBR_E_CPF_RG` | e-CPF: RG separado (independente de `.1`) | RG (15) + UF emissor (2) + Orgao (4) | v3+ | `ParseRgSeparado` → `RgSeparado` (+ fallback para `ResponsavelRg`/`ResponsavelEmissor`) (V41.5) |
| `2.16.76.1.3.10` | `OID_ICPBR_OAB` | OAB digital (Ordem dos Advogados) | numero OAB + UF | v6+ | Reconhecido via `IsOidIcpBrasilPF`; parser pendente em S11 |

> **CAEPF e CEI:** o OID `.6` historicamente carrega PIS/PASEP (11 digitos).
> A partir do DOC-ICP-04 v6 (2018), o **CEI** (Cadastro Especifico INSS) foi
> desactivado e substituido pelo **CAEPF** (Cadastro de Atividade Economica
> da Pessoa Fisica) — algumas ACs populam este OID com 14 digitos (CAEPF)
> em vez de 11 (PIS). O parser `ParsePisOuCaepf` aceita 11, 12 ou 14
> digitos; o consumidor distingue pelo `Length(LCert.PisOuCaepf)`.

## Helpers

```pascal
function IsOidIcpBrasilPJ(const AOID: string): Boolean;
//   true para OIDs 2.16.76.1.3.{2, 3, 4, 7}

function IsOidIcpBrasilPF(const AOID: string): Boolean;
//   true para OIDs 2.16.76.1.3.{1, 5, 6, 8, 10}

function OID_ICPBR_ROOT_PREFIX: string;
//   '2.16.76.1.3.'
```

## Politicas / Certificados de Politica (`2.5.29.32`)

DOC-ICP-04 tambem reserva o ramo `2.16.76.1.2.*` para OIDs de politica de
certificacao (e.g. `2.16.76.1.2.1.*` = AC-Raiz V1, ate `.10` = AC-Raiz V10).
Esses OIDs ficam dentro da extensao X509 `Certificate Policies` (`2.5.29.32`),
nao em `subjectAltName`. Parser dedicado planeado para S9 (chain validation).

## Compatibilidade legacy (importante)

A divergencia `.3` (legacy) vs `.7` (moderno) foi durante anos uma fonte
silenciosa de bugs. Ate V41.4, o leitor reconhecia apenas `.7` — certificados
e-CNPJ A1 antigos populando apenas `.3` caiam no fallback do CN do Subject.
A partir de **V41.5 (S8)** o leitor tenta `.7` primeiro e faz fallback
automatico para `.3` se ausente, garantindo cobertura uniforme.

## Referencias

- [Instituto Nacional de Tecnologia da Informacao (ITI)](https://www.gov.br/iti/pt-br)
- DOC-ICP-04 - Politicas de Certificacao Digital ICP-Brasil
- [Estrutura ICP-Brasil ITI (cadeia de AC-Raiz v1 a v10)](https://estrutura.iti.gov.br)
- [RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280) - Internet X.509 Public Key Infrastructure Certificate
- [Receita Federal — CAEPF](https://www.gov.br/receitafederal/pt-br/assuntos/orientacao-tributaria/cadastros/caepf)
