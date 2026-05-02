# Roadmap ICP-Brasil — Synapse CSL fork (referência completa)

> **Revisão 5** — Direcção tomada: **dual-license** (BSD core + LGPL nas units ICP-Brasil) para permitir reuso directo de código ACBr. CSL Synapse é distribuído publicamente, o que viabiliza esta arquitectura.

## 1. Decisão licenciamento — dual-license (BSD + LGPL ICP-Brasil)

**ACBr:** GNU LGPL v2.1 ([Doctos/LICENSE.TXT](e:/GDoc/src/package/ACBr/Doctos/LICENSE.TXT))
**Synapse fork CSL (core):** BSD 3-Clause ([LICENSE.md](e:/Dropbox/GDoc/src/modules/Synapse/LICENSE.md))
**Synapse fork CSL (units ICP-Brasil — novas):** **LGPL v2.1** (compatível com cópias ACBr)

### Arquitectura adoptada

```
Synapse fork CSL — vendor distribuído publicamente
├── Core BSD 3-Clause (50 units upstream + CSL patches)
│   ├── ssl_openssl3.pas, ssl_openssl4.pas, blcksock.pas, …
│   └── ssl_openssl_x509_ext.pas (CSL — BSD)
│
└── Camada ICP-Brasil LGPL v2.1 (CSL — pode reusar ACBr)
    ├── ssl_openssl_icpbrasil.pas
    ├── ssl_openssl_icpbrasil_oids.pas
    ├── ssl_openssl_icpbrasil_othername.pas
    ├── ssl_openssl_icpbrasil_subject.pas
    ├── ssl_openssl_icpbrasil_types.pas
    ├── ssl_openssl_chain_verify.pas          (S9, novo — generico chain verify)
    ├── ssl_openssl_icpbrasil_policy.pas      (S9, novo)
    ├── ssl_openssl_icpbrasil_crl.pas         (S10, novo)
    ├── ssl_openssl_icpbrasil_ocsp.pas        (S10, novo)
    ├── ssl_openssl_icpbrasil_san.pas         (S11, novo)
    ├── ssl_openssl_icpbrasil_pkcs7.pas       (S12, novo)
    ├── ssl_openssl_icpbrasil_tsp.pas         (S12, novo)
    ├── ssl_openssl_icpbrasil_pkcs11.pas      (S13, novo)
    └── ssl_openssl_icpbrasil_winstore.pas    (S13, novo, Win-only)
```

### Implicações práticas

- **Cliente que usa só o core Synapse**: continua sob BSD — sem obrigações copyleft.
- **Cliente que usa parsing/validação ICP-Brasil**: deve respeitar LGPL v2.1 — fornecer código fonte (ou facilidade de relink) das units LGPL modificadas. Software proprietário pode usar mediante:
  - Distribuir sources das units LGPL (ou apontar para o repositório público).
  - Ou linkar dinamicamente (exigência leve da LGPL — "user must be able to relink").
- **Headers das units LGPL**: obrigatório citar autores ACBr quando código for derivado/copiado.
- **CHANGELOG e VERSION.md**: documentar fronteira BSD vs LGPL com tabela explícita.

### Atribuições obrigatórias

Cada unit LGPL com código derivado do ACBr deve listar no header:

```pascal
{ Portions Copyright (c) ACBr Team — Daniel Simões de Almeida et al.       }
{ Adapted from ACBr (https://acbr.com.br) under GNU LGPL v2.1 terms.       }
{ Specific functions adapted: <listar>                                     }
{ ACBr source unit(s) referenced: <listar>                                 }
```

### Configuração compile-time opcional

Define `{$DEFINE NO_ICPBRASIL_LGPL}` em `ORM.Defines.inc` do consumidor permite excluir as units LGPL e ficar somente com a stack BSD pura. Para empresas com aversão a LGPL.

---

## 2. Estratégia de copy/integration ACBr → Synapse

### Mapa de cópia (ACBr → Synapse LGPL)

Após varredura aprofundada do ACBr, estes blocos são candidatos a cópia/adaptação directa:

| Origem ACBr | Destino Synapse (LGPL) | Tipo | Esforço economizado |
|---|---|---|---|
| `ACBrDFeWinCrypt.GetCertIsHardware` (CRYPT_IMPL_HARDWARE + NCRYPT_IMPL_HARDWARE_FLAG) | `ssl_openssl_icpbrasil_winstore.pas` (S13) | Cópia + adaptação OO | ~3h |
| `ACBrDFeWinCrypt.GetTaxIDFromExtensions` (binary pattern OID extraction) | Adaptar para `asn1util.ASNItem` em `ssl_openssl_icpbrasil_othername.pas` | Inspiração — não copiar bytes literais | — |
| `ACBrDFeSSL.ValidarCNPJCertificado` (compara raiz 8 dígitos) | `ssl_openssl_icpbrasil_subject.MatchCnpjRaiz` | Re-escrita guiada | ~30 min |
| `ACBrOpenSSLUtils.GetCertExt` (lookup por padrão binário) | Adaptar para OID-string lookup | Inspiração | — |
| `ACBrDFeWinCrypt.PFXDataToCertContextWinApi` (Windows store cert load) | `ssl_openssl_icpbrasil_winstore.LoadFromMyStore` | Cópia + adaptação | ~5h |
| `ACBrDFeWinCrypt.SetCertContextPassword` (PIN handling A3) | `ssl_openssl_icpbrasil_winstore.SetA3Pin` | Cópia | ~2h |
| `ACBrDFeOpenSSL.LoadFromFile` / PEM parsing | Já temos `PKCS12ReadFromBytes` — não precisa copiar | — | — |
| `ACBrUtil.ValidarCNPJ` / `ValidarCPF` (mod-11) | **Synapse já tem** — não copiar | — | — |
| `ACBrDFeUtil.OnlyNumber` | **Synapse já tem `SoDigitos`** — não copiar | — | — |

### Ganho real da Opção B vs Opção A (re-implementação)

- **S8 (quick wins)**: ganho mínimo — bindings Synapse já cobrem 90%; re-implementação é trivial.
- **S9 (chain validation)**: ganho médio — ACBr não implementa programaticamente, só usa `X509_verify_cert` no TLS handshake. Pouco a copiar.
- **S10 (CRL/OCSP)**: ganho zero — ACBr não tem.
- **S11 (SAN/KU/EKU)**: ganho médio — ACBr tem parsing de SAN parcial em WinCrypt; pode adaptar.
- **S12 (PKCS#7/CAdES)**: ganho ALTO — ACBr tem `ACBrEAD` (assinatura digital) e signing logic em XmlSec. Pode acelerar significativamente. **~6h economia.**
- **S13 (PKCS#11 + Windows Store)**: ganho ALTO — `ACBrDFeWinCrypt` tem ~1500 linhas testadas em produção para Windows Store. **~10–15h economia.**
- **S14 (helpers fiscais)**: ganho baixo — re-implementação é trivial.

**Total economia em horas adoptando Opção B:** ~20–25h sobre os 97h originais → **~75h efectivos.**

### Arquivos ACBr a estudar como fonte primária (para cópia ou referência)

| ACBr file | Conteúdo relevante | Acção Synapse |
|---|---|---|
| [ACBrDFe/ACBrDFeSSL.pas](e:/GDoc/src/package/ACBr/Fontes/ACBrDFe/ACBrDFeSSL.pas) | `TDadosCertificado`, parsers CN/Issuer | Estudar; nomes de campo distintos |
| [ACBrDFe/ACBrDFeWinCrypt.pas](e:/GDoc/src/package/ACBr/Fontes/ACBrDFe/ACBrDFeWinCrypt.pas) | A3 detection, PIN, Windows Store, OID extraction | Cópia de A3+PIN+Store após adaptação |
| [ACBrOpenSSL/ACBrOpenSSLUtils.pas](e:/GDoc/src/package/ACBr/Fontes/ACBrOpenSSL/ACBrOpenSSLUtils.pas) | `GetCertExt`, parsing X509 OpenSSL | Inspiração (mas técnica do `asn1util` é melhor) |
| [ACBrTCP/ACBrEAD.pas](e:/GDoc/src/package/ACBr/Fontes/ACBrTCP/ACBrEAD.pas) | Assinatura digital | Estudar para PKCS#7 (S12) |
| [ACBrDFe/ACBrDFeXsXmlSec.pas](e:/GDoc/src/package/ACBr/Fontes/ACBrDFe/ACBrDFeXsXmlSec.pas) | Assinatura XML via XmlSec | Referência — não copiar (XmlSec é GPL) |
| [ACBrComum/ACBrUtil.pas](e:/GDoc/src/package/ACBr/Fontes/ACBrComum/) | Funções utilitárias | Skip — Synapse tem equivalentes |

### Salvaguardas legais (mesmo na Opção B)

1. **Header de cada unit copiada** lista funções derivadas, ACBr unit fonte e copyright original.
2. **Compile-time guard** `NO_ICPBRASIL_LGPL` permite consumidor BSD-puro.
3. **Documentação clara** em [README.md](e:/Dropbox/GDoc/src/modules/Synapse/README.md) e [LICENSE.md](e:/Dropbox/GDoc/src/modules/Synapse/LICENSE.md) sobre dual-license.
4. **Patch separado** das ACBr para CSL (caso CSL melhore alguma função, o patch fica visível e pode ser oferecido upstream ao ACBr).

---

## Contexto

O fork CSL do Synapse v41.4 entregou leitor PFX ICP-Brasil em 6 units (S1–S6). A avaliação contra ACBr e a varredura das 50 units do package revelou que:

- **7 das 10 lacunas iniciais** são triviais (bindings já importados — só falta wrapper).
- **3 lacunas estruturais** são partilhadas com ACBr (chain, CRL, OCSP — ambos delegam ao SO).
- **Várias features estratégicas** estão ausentes nos dois (PolicyId, AIA fetch, PKCS#7 CAdES, time-stamping, PKCS#11 portátil, bundle AC-Raiz embarcado).

**Decisão tomada:** posicionar o Synapse CSL como a **biblioteca ICP-Brasil mais completa** — superando o ACBr em todos os campos (parsing, validação, revogação, assinatura PKCS#7, time-stamping, A3 cross-platform).

**Escopo total:** ~95–115h em 7 sprints (S8–S14), entregáveis em versões 41.5 → 42.0.

---

## 1. O que cada sprint entrega (visão executiva)

| Sprint | Versão | Tema | Esforço | Lacunas fechadas |
|---|---|---|---|---|
| **S8** | v41.5 | Quick wins + saneamento | ~5h | 7 lacunas (record completo) |
| **S9** | v41.6 | Chain validation + Policy + AC-Raiz bundle | ~14h | Chain offline + ITI bundle |
| **S10** | v41.7 | Revogação completa (CRL + OCSP + AIA + CDP) | ~16h | Revogação programática |
| **S11** | v41.8 | Subject enrichment — SAN/KU/EKU/OAB/RFB/CAEPF | ~10h | DOC-ICP-04 v8.x compliance |
| **S12** | v41.9 | PKCS#7/CAdES + Time-stamping (NFe/eSocial signing) | ~16h | Assinatura fiscal nativa |
| **S13** | v42.0 | Hardware (PKCS#11 cross-platform + Windows Store + A3) | ~30h | A3 portátil |
| **S14** | v42.1 | Helpers fiscais + DOC-ICP-04 v8.x audit + docs | ~6h | UX fiscal pronto |

**Total estimado: ~97h** (≈ 12-13 dias/pessoa em fluxo contínuo).

---

## 2. Estado actual do leitor (baseline antes de S8)

### Campos já populados em `TIcpBrasilCertificado` ([ssl_openssl_icpbrasil_types.pas:67-85](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_types.pas#L67))

✅ `Tipo`, `Subject`, `SubjectTitular`, `SubjectDocumento`, `DocumentoFormatado`, `DocumentoValido`, `Issuer`, `IssuerSerial` (declarado, não populado), `NotBefore`, `NotAfter`, `ResponsavelNome` (declarado, não populado), `ResponsavelCpf`, `ResponsavelNasc`, `ResponsavelRg`, `ResponsavelEmissor`, `Email` (declarado, não populado), `OtherNamesRaw` (declarado, não populado).

### OIDs declarados em [ssl_openssl_icpbrasil_oids.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_oids.pas) — 6 OIDs

| Constante | OID | Consumo actual |
|---|---|---|
| `OID_ICPBR_E_CPF_DATA` | `2.16.76.1.3.1` | ✅ `ParseEcpfData` |
| `OID_ICPBR_E_CNPJ_RESPONSAVEL` | `2.16.76.1.3.4` | ✅ `ParseEcnpjResponsavel` |
| `OID_ICPBR_E_CPF_TITULO` | `2.16.76.1.3.5` | ⚠️ declarado, não populado |
| `OID_ICPBR_E_CPF_INSS` | `2.16.76.1.3.6` | ⚠️ declarado, não populado |
| `OID_ICPBR_E_CNPJ_DATA` | `2.16.76.1.3.7` | ✅ `ParseEcnpjData` |
| `OID_ICPBR_E_CPF_RG` | `2.16.76.1.3.8` | ⚠️ declarado, não populado |

### OIDs ausentes a adicionar

`2.16.76.1.3.2` (Nome PJ legacy), `2.16.76.1.3.3` (CNPJ legacy — **crítico**), `2.16.76.1.3.10` (OAB digital), `2.16.76.1.3.11`/`.12` (extensões DOC-ICP-04 v8 novas), `2.16.76.1.2.*` (Policy OIDs ITI — várias).

---

## 3. S8 — v41.5 — Quick wins (~5h)

> Tudo aproveita bindings já importados. Esforço baixo, impacto alto.

### Tarefas

| # | Acção | Ficheiro | Esforço |
|---|---|---|---|
| **A1** | Adicionar `OID_ICPBR_PJ_NOME_LEGACY = '2.16.76.1.3.2'` e `OID_ICPBR_E_CNPJ_LEGACY = '2.16.76.1.3.3'`; atualizar `IsOidIcpBrasilPJ` | [ssl_openssl_icpbrasil_oids.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_oids.pas) | 15 min |
| **A2** | Em `ClassificarPorExtensoes`, fallback para `.3` quando `.7` ausente | [ssl_openssl_icpbrasil.pas:119](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil.pas#L119) | 15 min |
| **A3** | Adicionar campos no record: `NumeroSerie`, `ThumbPrintSHA1`, `ThumbPrintSHA256`, `Certificadora`, `TituloEleitor`, `PisOuCaepf`, `RgSeparado`, `DERBase64`, `Versao` (X509 v3=2) | [ssl_openssl_icpbrasil_types.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_types.pas) | 30 min |
| **A4** | Helpers em `ssl_openssl_x509_ext.pas`: `NID_organizationName=17`, `X509GetIssuerO`, `X509GetSubjectO`, `X509GetSerialNumberHex`, `X509GetThumbprintSHA1`, `X509GetThumbprintSHA256`, `X509GetDERBase64`, `X509GetVersion` | [ssl_openssl_x509_ext.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_x509_ext.pas) | 1h |
| **A5** | `LerDoPfx` popula novos campos do record | [ssl_openssl_icpbrasil.pas:194](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil.pas#L194) | 30 min |
| **A6** | Consumir `.5` `.6` `.8` em `ClassificarPorExtensoes` (popular `TituloEleitor`, `PisOuCaepf`, `RgSeparado`) | [ssl_openssl_icpbrasil.pas:112](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil.pas#L112), `_othername.pas` (novos parsers) | 1h 30min |
| **A7** | Helpers públicos em `ssl_openssl_icpbrasil_subject.pas`: `MatchCnpjRaiz(ACertCnpj, ADocCnpj: string): Boolean` (8 dígitos), `EstaValidoEm(ACert, AData): Boolean` | [ssl_openssl_icpbrasil_subject.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_subject.pas) | 30 min |
| **A8** | Tests fixtures + bump `001.000.001 → 001.001.000`, VERSION.md, .lpk/.dpk | `tests-extra/`, [VERSION.md](e:/Dropbox/GDoc/src/modules/Synapse/VERSION.md), [laz_synapse.lpk](e:/Dropbox/GDoc/src/modules/Synapse/laz_synapse.lpk), [synapse.dpk](e:/Dropbox/GDoc/src/modules/Synapse/synapse.dpk) | 30 min |

### Resultado S8

Record `TIcpBrasilCertificado` com 25+ campos populados; paridade ou superioridade com ACBr em parsing.

---

## 4. S9 — v41.6 — Chain validation + Policy + AC-Raiz bundle (~14h)

> Lacuna estrutural partilhada com ACBr. Aqui o Synapse passa à frente.

### Tarefas

| # | Acção | Esforço |
|---|---|---|
| **B1** | **Importar bindings X509 chain** em [ssl_openssl3_lib.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl3_lib.pas) e [ssl_openssl4_lib.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl4_lib.pas): `X509_STORE_new`, `X509_STORE_free`, `X509_STORE_add_cert`, `X509_STORE_load_locations`, `X509_STORE_CTX_new`, `X509_STORE_CTX_init`, `X509_STORE_CTX_free`, `X509_verify_cert`, `X509_STORE_CTX_get_error`, `X509_verify_cert_error_string` | 3h |
| **B2** | **Refactor `StripASN1OctetWrapper` → `asn1util.ASNItem`** — suporte TLV recursivo robusto | 2h |
| **B3** | **Bundle AC-Raiz ICP-Brasil embarcado** — script PowerShell para baixar v1–v10 do ITI (https://estrutura.iti.gov.br) e gerar `ssl_openssl_icpbrasil_acraiz.inc` (resource Pascal com bytes embutidos) | 2h |
| **B4** | **Nova unit `ssl_openssl_chain_verify.pas` (CSL)** — `TX509ChainVerifier` com `LoadStoreFromBundle`, `Verify(ACert): TVerifyResult` (record com `OK`, `ErrCode`, `ErrText`, `ChainDepth`) | 3h |
| **B5** | **Nova unit `ssl_openssl_icpbrasil_policy.pas` (CSL)** — parser de `Certificate Policies` (ext `2.5.29.32`); reconhece OIDs canónicos `2.16.76.1.2.1.*` (AC Raiz V1), `2.16.76.1.2.3.*` (V3), até `.10` (V10); cross-check entre policy do cert e AC-Raiz reconhecida | 3h |
| **B6** | Integração em `LerDoPfx` opcional (parâmetro `AVerificarChain: Boolean = False`) — popula `Validacao.Chain*` no record | 30 min |
| **B7** | Tests: PFX A1 real, PFX self-signed, PFX expirado, PFX com policy fora do ITI | 30 min |

### Novos campos no record (S9)

```pascal
ChainValido:        Boolean;
ChainErro:          string;
ChainProfundidade:  Integer;
PolicyOids:         array of string;
PolicyValida:       Boolean;
AcRaizDetectada:    string;     // 'AC-Raiz V5' etc.
```

### Resultado S9

Synapse passa a validar cadeia ICP-Brasil **offline** sem depender do SO. Bundle AC-Raiz é distribuído com o vendor — ACBr não tem isso.

---

## 5. S10 — v41.7 — Revogação programática (CRL + OCSP + AIA + CDP) (~16h)

> Lacuna ausente em ambos. Aqui o Synapse assume liderança no ecossistema Pascal.

### Tarefas

| # | Acção | Esforço |
|---|---|---|
| **C1** | **Bindings CRL** em `ssl_openssl3_lib`/`_lib4`: `d2i_X509_CRL`, `i2d_X509_CRL`, `X509_CRL_free`, `X509_CRL_get0_by_serial`, `X509_CRL_verify`, `X509_CRL_get_lastUpdate`, `X509_CRL_get_nextUpdate`, `X509_REVOKED_*` | 2h |
| **C2** | **Bindings OCSP** em `ssl_openssl3_lib`/`_lib4`: `OCSP_REQUEST_new`, `OCSP_request_add0_id`, `OCSP_REQUEST_free`, `OCSP_response_status`, `OCSP_basic_verify`, `OCSP_resp_find_status`, `OCSP_check_validity`, `OCSP_RESPONSE_free`, `OCSP_BASICRESP_free` | 3h |
| **C3** | **Bindings AIA / CDP parser** — usar `asn1util.ASNItem` para parsear extensões `1.3.6.1.5.5.7.1.1` (AIA) e `2.5.29.31` (CDP) e extrair URLs | 2h |
| **C4** | **Nova unit `ssl_openssl_icpbrasil_crl.pas` (CSL)** — download CRL via Synapse `httpsend` (já existe!), cache em pasta configurável (`TIcpBrasilCrlCache.SetCacheDir`), TTL respeitando `nextUpdate`, função `IsRevogado(ASerial: string): Boolean` | 3h |
| **C5** | **Nova unit `ssl_openssl_icpbrasil_ocsp.pas` (CSL)** — cliente OCSP (constrói request, envia POST via `httpsend`, parseia response, valida assinatura), `CheckRevogacaoOCSP(ACert, AIssuer): TOcspResult` | 3h |
| **C6** | **Orquestração em `ssl_openssl_chain_verify.pas`** — método `VerifyComRevogacao(ACert; AModo: TRevogacaoMode)` onde `TRevogacaoMode = (rmNone, rmCRL, rmOCSP, rmOCSPThenCRL, rmCRLThenOCSP)` | 1h 30min |
| **C7** | Integração em `LerDoPfx` (parâmetro `AVerificarRevogacao: TRevogacaoMode = rmNone`) | 30 min |
| **C8** | Tests + docs | 1h |

### Novos campos no record (S10)

```pascal
RevogacaoVerificada: Boolean;
Revogado:            Boolean;
RevogacaoMotivo:     string;     // 'keyCompromise' etc.
RevogacaoData:       TDateTime;
RevogacaoFonte:      string;     // 'CRL: http://crl…' ou 'OCSP: http://…'
```

### Resultado S10

Verificação completa de revogação sem depender de SO. Cache eficiente para batch processing. Pronto para validar lotes de NFe assinadas.

---

## 6. S11 — v41.8 — Subject enrichment + DOC-ICP-04 v8.x compliance (~10h)

> Adiciona o que falta para conformidade com DOC-ICP-04 v8.x (versão actual do ITI, 2024).

### Tarefas

| # | Acção | Esforço |
|---|---|---|
| **D1** | **Parser SubjectAlternativeName completo** — adiciona `DnsNames: array of string`, `IpAddresses: array of string`, `Uris: array of string`, `Emails: array of string` (de `rfc822Name` — popula campo `Email` existente). Parser via `asn1util.ASNItem` | 3h |
| **D2** | **Parser Key Usage (`2.5.29.15`)** — bitmask DigitalSignature/NonRepudiation/KeyEncipherment/etc.; popula `KeyUsage: set of TKeyUsageBit` | 1h 30min |
| **D3** | **Parser Extended Key Usage (`2.5.29.37`)** — array de OIDs (clientAuth, serverAuth, codeSigning, emailProtection, timeStamping, OCSPSigning, e ICP-Brasil OIDs como `1.3.6.1.4.1.311.20.2.2` SmartCardLogon); popula `ExtKeyUsage: array of string` | 1h 30min |
| **D4** | **OAB digital (`2.16.76.1.3.10`)** — parser do número OAB + UF | 1h |
| **D5** | **CAEPF parser diferenciado para `.6`** — DOC-ICP-04 v6+ trocou PIS/PASEP por CAEPF (14 dígitos) ou CEI (12); detectar pela quantidade | 1h |
| **D6** | **OIDs DOC-ICP-04 v8.x (2024)** — adicionar `2.16.76.1.3.11`, `.12`, `.13`, `.14`, `.15` se aplicável (verificar última versão do DOC-ICP-04) | 1h |
| **D7** | **Helper `ClassificacaoCertificado(ACert): TIcpBrasilClassificacao`** — enum `cicAplicacao`, `cicEquipamento`, `cicTituloEleitor`, `cicAtributo` etc. (DOC-ICP-04 reconhece subtipos) | 1h |
| **D8** | Tests + docs | 1h |

### Novos campos no record (S11)

```pascal
DnsNames:       array of string;
IpAddresses:    array of string;
Uris:           array of string;
Emails:         array of string;     // popula 'Email' principal também
KeyUsage:       set of TKeyUsageBit;
ExtKeyUsage:    array of string;
OabNumero:      string;
OabUf:          string;
Caepf:          string;       // DOC-ICP-04 v6+
Cei:            string;       // legacy (1988-2018)
Classificacao:  TIcpBrasilClassificacao;
```

### Resultado S11

Synapse cobre 100% dos campos DOC-ICP-04 v8.x. Detecta: e-CPF, e-CNPJ, equipamento, aplicação, título eleitor, OAB, atributos profissionais. ACBr cobre ~30% disso.

---

## 7. S12 — v41.9 — PKCS#7/CAdES + Time-stamping (~16h)

> **Maior diferenciador:** assinatura PKCS#7 nativa (NFe/eSocial usam isso) + RFC 3161 time-stamping (não-repúdio fiscal).

### Tarefas

| # | Acção | Esforço |
|---|---|---|
| **E1** | **Bindings PKCS#7/CMS** em `ssl_openssl3_lib`/`_lib4`: `PKCS7_new`, `PKCS7_sign`, `PKCS7_sign_add_signer`, `PKCS7_final`, `PKCS7_verify`, `PKCS7_get0_signers`, `i2d_PKCS7`, `d2i_PKCS7`, `CMS_sign`, `CMS_verify` (CAdES via CMS é mais moderno) | 3h |
| **E2** | **Bindings RFC 3161** (Time-stamp Protocol): `TS_REQ_new`, `TS_REQ_set_msg_imprint`, `TS_REQ_set_nonce`, `TS_RESP_*`, `TS_VERIFY_CTX_*`, `TS_RESP_verify_response` | 3h |
| **E3** | **Nova unit `ssl_openssl_pkcs7_signer.pas` (CSL)** — `TPkcs7Signer.AssinarBytes(ABytes; ACert; AKey; AModo)` onde `AModo = (psBinarioCAdES, psDetached, psAttached, psBinaryB64)`; suporta `addAttribute(signingTime, contentType, messageDigest)` | 4h |
| **E4** | **Nova unit `ssl_openssl_tsp_client.pas` (CSL)** — cliente TSP (constrói request via `TS_REQ`, envia HTTP POST via `httpsend`, parseia response, valida assinatura do TSA) | 3h |
| **E5** | **Helper `ssl_openssl_icpbrasil_signer.pas` (CSL)** — wrapper específico ICP-Brasil: `AssinarNFeXml(AXml: string; ACert; AKey): string` (CAdES detached + time-stamp opcional) | 2h |
| **E6** | Tests + docs (signing 1 NFe XML real e validar contra schema XmlDSig) | 1h |

### Resultado S12

Synapse passa a oferecer toda a stack de assinatura fiscal:
- Lê PFX
- Extrai cert+chave
- Assina NFe XML em CAdES detached
- Anexa time-stamp RFC 3161
- Tudo cross-platform

ACBr depende de XmlSec (multiplataforma) ou MSXML/WinCrypt (Windows). Synapse passa a competir directamente.

---

## 8. S13 — v42.0 — Hardware (PKCS#11 + Windows Store + A3) (~30h)

> A grande lacuna do Synapse (e do ACBr fora do Windows). Sprint mais longo.

### Tarefas

| # | Acção | Esforço |
|---|---|---|
| **F1** | **Stub PKCS#11 (Cryptoki) cross-platform** — definir tipos PKCS#11 v3.0 em Pascal (`CK_BYTE`, `CK_SLOT_ID`, `CK_SESSION_HANDLE`, `CK_FUNCTION_LIST`); load `dlopen('libpkcs11.so')` ou `LoadLibrary('eToken.dll')` | 6h |
| **F2** | **Nova unit `ssl_pkcs11_loader.pas` (CSL)** — `TPkcs11Loader.LoadModule(APath)`, `EnumerateSlots`, `OpenSession(ASlot, APin)`, `EnumerateCertificates`, `Sign(AHandle, AData)` | 6h |
| **F3** | **Nova unit `ssl_pkcs11_synapse.pas` (CSL)** — bridge para `TX509Ext` (cert lido via PKCS#11 vira `PX509`), permite usar leitor ICP-Brasil com cert em token | 4h |
| **F4** | **Bindings Windows MyStore (Win-only)** — `CertOpenSystemStore`, `CertEnumCertificatesInStore`, `CertGetCertificateContextProperty(CERT_KEY_PROV_INFO_PROP_ID)`, `CertCloseStore` | 4h |
| **F5** | **Nova unit `ssl_winstore.pas` (CSL)** — `TWinCertStore.OpenStore(slMy, slCurrentUser)`, `EnumerateCertificates`, retorna `PX509` carregado em memória OpenSSL | 4h |
| **F6** | **Detecção A3 via WinCrypt** — `CRYPT_IMPL_HARDWARE` flag (espelha ACBr); helper `IsCertificadoEmHardware(ACert): Boolean` | 2h |
| **F7** | **Auto-detecção PKCS#11 em Linux/macOS** — paths conhecidos (`/usr/lib/x86_64-linux-gnu/libsofthsm2.so`, `/usr/lib64/libeToken.so`, `/usr/lib/pkcs11/`); `TPkcs11Loader.AutoDetect` | 2h |
| **F8** | Tests com SoftHSM2 (Linux) + token físico se disponível | 2h |

### Resultado S13

Synapse passa a ser **a única biblioteca Pascal com A3 portátil cross-platform**. ACBr só tem A3 no Windows (CAPI). Habilita uso em Linux/Docker para servidores fiscais.

---

## 9. S14 — v42.1 — Helpers fiscais + audit + docs (~6h)

### Tarefas

| # | Acção | Esforço |
|---|---|---|
| **G1** | Helper `IsCertificadoNFe(ACert): Boolean` — verifica EKU clientAuth + ICP-Brasil reconhecida + e-CNPJ válido | 30 min |
| **G2** | Helper `IsCertificadoESocial(ACert): Boolean` — eSocial requer e-CNPJ ou e-CPF + EKU clientAuth | 30 min |
| **G3** | Helper `IsCertificadoSerpro(ACert): Boolean` — verifica AC SERPRO (subset ICP-Brasil) | 30 min |
| **G4** | Helper `IsCertificadoSefaz(ACert; AUf: string): Boolean` — verifica AC SEFAZ por UF | 30 min |
| **G5** | **Audit DOC-ICP-04 v8.x** — confirmar todos os OIDs adicionados batem com a versão actual do documento ITI; adicionar referência exacta ao header das units | 1h |
| **G6** | **Documentação completa** — atualizar `docs-extra/icpbrasil-oids.md`, `docs-extra/integration-guide.md`, criar `docs-extra/cades-signing.md`, `docs-extra/pkcs11-cross-platform.md`, `docs-extra/ac-raiz-bundle.md` | 2h |
| **G7** | **README.md + CHANGELOG.md** atualizar com matriz de comparação Synapse vs ACBr final | 1h |

### Resultado S14

Synapse pronto para distribuição pública como referência ICP-Brasil. ACBr ofuscado em todos os pontos.

---

## 10. Matriz final esperada (após S14)

| Feature | Synapse v42.1 | ACBr | Quem ganha |
|---|---|---|---|
| Leitura PFX A1 | ✅ | ✅ | Empate |
| Leitura A3/Token (Windows) | ✅ via WinStore | ✅ via WinCrypt | Empate |
| Leitura A3/Token (Linux/macOS) | ✅ via PKCS#11 | ❌ | **Synapse** |
| Cross-platform real (Linux/macOS) | ✅ | ⚠️ A1-only | **Synapse** |
| 12+ OIDs DOC-ICP-04 v8.x | ✅ | ❌ (2 OIDs) | **Synapse** |
| Mod-11 CPF/CNPJ | ✅ | ✅ | Empate |
| Comparação CNPJ raiz | ✅ | ✅ | Empate |
| Detecção A1 vs A3 | ✅ | ✅ | Empate |
| NumeroSerie/ThumbPrint/DERBase64 | ✅ | ✅ | Empate |
| **Chain validation programática offline** | ✅ | ❌ | **Synapse** |
| **Bundle AC-Raiz ICP-Brasil embarcado** | ✅ | ❌ | **Synapse** |
| **CRL programmatic verify** | ✅ | ❌ | **Synapse** |
| **OCSP client** | ✅ | ❌ | **Synapse** |
| **AIA / CDP auto-fetch** | ✅ | ❌ | **Synapse** |
| **PolicyIdentifier validation** | ✅ | ❌ | **Synapse** |
| Email / DNS / IP / URI no SAN | ✅ | ❌ | **Synapse** |
| Key Usage / Ext Key Usage parsing | ✅ | ⚠️ parcial | **Synapse** |
| OAB digital | ✅ | ❌ | **Synapse** |
| CAEPF (substituto CEI 2018+) | ✅ | ❌ | **Synapse** |
| **PKCS#7/CAdES signing nativo** | ✅ | ⚠️ via XmlSec/MS | **Synapse** |
| **Time-stamping RFC 3161 client** | ✅ | ❌ | **Synapse** |
| Helpers fiscais (NFe/eSocial/Serpro/Sefaz) | ✅ | ⚠️ ACBr só ValidarCNPJCertificado | **Synapse** |
| ASN.1 generic decoder reaproveitado | ✅ asn1util | ⚠️ binário ad-hoc | **Synapse** |

**Resultado:** Synapse v42.1 fica à frente do ACBr em **17 de 23 features**, empate em 6, sem perdas.

---

## 11. Decisão arquitectural — patches no vendor vs. units add-on

**Política:** seguir CLAUDE.md (vendor CSL fork): **adições aditivas em units novas; alterações em units existentes preservam compatibilidade binária e API upstream.**

### Units novas a criar (não toca upstream)

- `ssl_openssl_chain_verify.pas` (S9)
- `ssl_openssl_icpbrasil_acraiz.inc` (S9 — bundle PEM em Pascal include)
- `ssl_openssl_icpbrasil_policy.pas` (S9)
- `ssl_openssl_icpbrasil_crl.pas` (S10)
- `ssl_openssl_icpbrasil_ocsp.pas` (S10)
- `ssl_openssl_icpbrasil_san.pas` (S11 — parser SAN completo)
- `ssl_openssl_icpbrasil_keyusage.pas` (S11)
- `ssl_openssl_pkcs7_signer.pas` (S12)
- `ssl_openssl_tsp_client.pas` (S12)
- `ssl_openssl_icpbrasil_signer.pas` (S12)
- `ssl_pkcs11_loader.pas` (S13)
- `ssl_pkcs11_synapse.pas` (S13)
- `ssl_winstore.pas` (S13)

### Units existentes a alterar (com bump triplo sincronizado)

- [ssl_openssl3_lib.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl3_lib.pas) — adicionar bindings X509_STORE_*, CRL, OCSP, PKCS7, TSP (apenas declarações + GetProcAddress). Bump da fork CSL apenas.
- [ssl_openssl4_lib.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl4_lib.pas) — simétrico.
- [ssl_openssl_x509_ext.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_x509_ext.pas) — adicionar helpers (NID=17, Serial, Thumbprint, DER, Version). Bump CSL.
- [ssl_openssl_icpbrasil_oids.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_oids.pas) — OIDs ausentes (`.2`, `.3`, `.10`, `.11+`, policy `2.16.76.1.2.*`).
- [ssl_openssl_icpbrasil_types.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_types.pas) — record expandido (~25 → ~50 campos).
- [ssl_openssl_icpbrasil.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil.pas) — `LerDoPfx` orquestra chain/revogação/SAN/KU/EKU como opcional.
- [ssl_openssl_icpbrasil_othername.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_othername.pas) — refactor para `asn1util.ASNItem`; novos parsers `.5`/`.6`/`.8`/`.10`.
- [ssl_openssl_icpbrasil_subject.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_subject.pas) — `MatchCnpjRaiz`, `EstaValidoEm`.
- [synapse.dpk](e:/Dropbox/GDoc/src/modules/Synapse/synapse.dpk) + [laz_synapse.lpk](e:/Dropbox/GDoc/src/modules/Synapse/laz_synapse.lpk) — listar todas as novas units (simétricos).
- [Synapse.Version.inc](e:/Dropbox/GDoc/src/modules/Synapse/Synapse.Version.inc) — tags por sprint (`SYNAPSE_CSL_ICPBR_S8` … `SYNAPSE_CSL_ICPBR_S14`).
- [VERSION.md](e:/Dropbox/GDoc/src/modules/Synapse/VERSION.md) + [CHANGELOG.md](e:/Dropbox/GDoc/src/modules/Synapse/CHANGELOG.md) — registar cada bump.

---

## 12. Plano de execução incremental

**Recomendação:** entregar sprint-a-sprint, validando contra PFX real fiscal a cada sprint. Cada sprint é independente (não depende da entrega futura). O leitor v41.5 já é útil mesmo sem chain validation; o leitor v41.7 já é completo para revogação mesmo sem PKCS#7 signing.

**Sequência sugerida:** começar por S8 (5h) e validar antes de comprometer com S9. Ponto de decisão a cada sprint para ajustar escopo.

**Possível paralelização:** S11 (SAN/KU/EKU) e S12 (PKCS#7) podem rodar em paralelo após S10 — não há dependências cruzadas além do `asn1util` e bindings comuns.

---

## 13. Verificação por sprint

| Sprint | Smoke test | Tests adicionais |
|---|---|---|
| S8 | PFX `.3`-only retorna `ibtECnpj` populado | Fixtures `.3`/`.7`/ambos; record completo |
| S9 | PFX A1 real → `ChainValido=True`; self-signed → `ChainValido=False` | AC-Raiz v1–v10; policy fora ITI; cert expirado |
| S10 | PFX A1 real + CRL fetch → `Revogado=False`; cert revogado conhecido → `Revogado=True` | OCSP responder real; AIA auto-fetch; cache TTL |
| S11 | Email/DNS/KeyUsage extraídos | OAB cert; CAEPF cert; SAN com IP |
| S12 | NFe XML assinado por Synapse valida em SEFAZ homologação | Time-stamp anexado e verificado |
| S13 | Cert em SoftHSM2 (Linux) → `LerDoPfx` funcional via PKCS#11 | Token físico real (eToken/Giesecke) |
| S14 | `IsCertificadoNFe` filtra correctamente lote misto de PFX | Auditoria DOC-ICP-04 v8.x linha-a-linha |

---

## 14. Riscos e mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Bundle AC-Raiz ITI mudar (revogação de AC, nova versão) | Baixa | Médio | Script automatizado de re-fetch + CI mensal |
| OpenSSL 4.0 ainda incompleto/instável | Média | Médio | Manter compatibilidade dual (3.x e 4.0) |
| PKCS#11 fragmentação de drivers | Alta | Médio | Testar com SoftHSM2 + 2-3 tokens reais comuns no Brasil (eToken, SafeNet) |
| Performance — assinar PKCS#7 + time-stamp pode ser lento | Média | Baixo | Cache + assíncrono onde possível |
| ACBr lança feature equivalente | Baixa | Baixo | Synapse já distancia-se em portabilidade |

---

## 15. Decisão pedida ao utilizador

1. **Aprovar S8** isoladamente para começo imediato? (Mais barato e impactante.)
2. **Comprometer com roadmap completo S8→S14** (~97h, ~12 dias)?
3. **Subset cirúrgico** (e.g. S8+S9+S10 = ~35h cobre fiscal essencial sem PKCS#7/PKCS#11)?
4. **Adiar PKCS#11 (S13)** para um vendor separado fora do Synapse, mantendo o foco em parsing/validação?

A recomendação é **opção 3** (S8+S9+S10 = leitor + chain + revogação completo) seguida de revisão de prioridades antes de comprometer com S12/S13.
