# (Ararat) Synapse TCP/IP library for Pascal — CSL fork

**Synapse** provides blocking-socket networking and protocol clients/servers (HTTP, SMTP, FTP, LDAP, POP3, IMAP, etc.) for Delphi and Free Pascal.

Esta é uma **cópia CSL** do Synapse, derivada do upstream oficial em <https://github.com/geby/synapse>, com extensões proprietárias adicionadas pelo CSL Softwares ao longo de 14 sprints (S1–S14):

- **V41.0–V41.3** — OpenSSL 4.0 + DLL path helper + tri-plataforma POSIX em `ldapsend` + tipagem automática de atributos LDAP + `AddRaw` preservando 100% bytes binários
- **V41.4 (S1–S6)** — leitor PFX X509 cross-platform + tropicalização ICP-Brasil DOC-ICP-04
- **V41.5 (S8)** — quick wins ICP-Brasil: fallback OID `.3` legacy + record expandido (NumeroSerie/Thumbprint/Certificadora/DERBase64/Versão) + parsers `.5`/`.6`/`.8` + helpers fiscais `MatchCnpjRaiz`/`EstaValidoEm`
- **V41.6 (S9)** — chain validation programática offline (`TX509ChainVerifier`) + parser de Certificate Policies (`2.5.29.32`) + bundle AC-Raiz ICP-Brasil v1..v10
- **V41.7 (S10)** — revogação programática completa: CRL + OCSP + AIA + CDP (`TIcpBrasilCrlClient`/`TIcpBrasilOcspClient`)
- **V41.8 (S11)** — subject enrichment: SAN (DNS/IP/URI/email) + Key Usage + Extended Key Usage + OAB digital
- **V41.9 (S12)** — assinatura PKCS#7/CAdES-BES nativa (`TPkcs7Signer`) + Time-stamping RFC 3161 (`TTspClient`)
- **V42.0 (S13a + S13b)** — Windows Certificate Store (`TWinCertStore`) + A3 detection + PKCS#11 (Cryptoki v3) cross-platform (`TPkcs11Loader`)
- **V42.1 (S14)** — fiscal helpers `IsCertificadoNFe`/`IsCertificadoESocial`/`IsCertificadoSerpro`/`IsCertificadoSefaz`/`IsCertificadoEFDReinf` + cross-platform fixes

- **Upstream base:** Ararat Synapse 41.0 (copyright 1999-2023, Lukas Gebauer)
- **Fork CSL:** 2026-05-01, `CSL Softwares` — package version **42.1**
- **Referência de consulta do upstream actualizado** (não entra em build): `Packege/synapse.v41/` (snapshot do repo git acima; pode estar ligeiramente mais recente que `Packege/synapse/`)

---

## Índice

- [Extensões do fork](#extensões-do-fork-sem-precedente-upstream)
- [Quick Start — LDAPS + OpenSSL 4.0 + CBT em 20 linhas](#quick-start--ldaps--openssl-40--cbt)
- [API CSL-only — classe por classe](#api-csl-only--classe-por-classe)
  - [TOpenSSLPaths](#topensslpaths-unit-ssl_openssl_pathspas)
  - [TSSLOpenSSL4](#tsslopenssl4-unit-ssl_openssl4pas)
  - [TLDAPSend (extensões CSL)](#tldapsend-extensões-csl-unit-ldapsendpas)
  - [TLDAPAttribute (V1.7.1 + V1.7.2)](#tldapattribute-v171--v172-unit-ldapsendpas)
  - [TLDAPAttributeValue](#tldapattributevalue-v171-unit-ldapsendpas)
  - [TLDAPValueType + ResolveLDAPValueType](#tldapvaluetype--resolveldapvaluetype-v171-unit-ldapsendpas)
  - [TTCPBlockSocket.GetPeerCertSHA256Hash](#ttcpblocksocketgetpeercertsha256hash-unit-blcksockpas)
  - [FileTime helpers (TLDAPSend class functions)](#filetime-helpers-tldapsend-class-functions)
- [Selector OpenSSL](#selector-openssl-no-projecto-consumidor)
- [Compilação](#compilação)
- [Divergências vs upstream](#divergências-vs-upstream--consolidado)
- [Documentação e análise](#documentação-e-análise)
- [Licença](#licença)

---

## Extensões do fork (sem precedente upstream)

### v41.3 e anteriores (2026-04-21, contribuição CSL Tech Solutions)

| Unit | Propósito | Versão | Baseada em |
| --- | --- | --- | --- |
| `ssl_openssl4.pas` | SSL plugin para **OpenSSL 4.0.0** (classe `TSSLOpenSSL4`) | 001.004.000 | Fork mecânico de `ssl_openssl3.pas` — classe renomeada, `LibName` trocado |
| `ssl_openssl4_lib.pas` | Imports para `libcrypto-4*.dll` / `libssl-4*.dll` + `.so.4` + `.4.dylib` | 001.004.000 | Fork mecânico de `ssl_openssl3_lib.pas` — **8 DLL names renomeados** (`-3` → `-4`). Signatures Pascal **inalteradas** (ICS V9.6 confirma API unificada 3.x+4.0). |
| `ssl_openssl_paths.pas` | Helper opt-in `TOpenSSLPaths.{Apply,Resolve,SetCustomPath}` para `SetDllDirectory` | 001.000.000 | Unit 100% nova. Windows-only; POSIX é stub no-op. |

### v41.4 (2026-04-30, contribuição CSL Tech Solutions)

| Unit | Propósito | Versão |
| --- | --- | --- |
| `ssl_openssl_x509_ext.pas` | Companion cross-platform: leitor de PFX X509 via OpenSSL 3.x. `TX509Ext.PKCS12ReadFromBytes`, `X509GetNotBefore/After`, `X509GetAllExtensions`, `X509ASN1TimeToDateTimeUTC` | 001.001.000 (S8) |
| `ssl_openssl_icpbrasil_oids.pas` | Constantes OIDs DOC-ICP-04 + helpers `IsOidIcpBrasilPJ/PF` | 001.001.000 (S8) |
| `ssl_openssl_icpbrasil_types.pas` | Record `TIcpBrasilCertificado` + `TIcpBrasilTipo` enum + 3 excecoes especificas | 001.001.000 (S8) |
| `ssl_openssl_icpbrasil_subject.pas` | Parser CN `EMPRESA:CNPJ` / `NOME:CPF` + validadores CNPJ/CPF mod-11 (Receita Federal) | 001.001.000 (S8) |
| `ssl_openssl_icpbrasil_othername.pas` | Parsers ASN.1 OtherName ICP-Brasil v3 (`ParseEcnpjData`, `ParseEcpfData`, `ParseEcnpjResponsavel`) | 001.001.000 (S8) |
| `ssl_openssl_icpbrasil.pas` | API publica: `TIcpBrasilCertificadoReader.LerDoPfx(bytes, senha): TIcpBrasilCertificado` | 001.001.000 (S8) |

### v41.5 (2026-05-01, S8 quick wins — contribuição CSL Tech Solutions)

Direcção tomada após avaliação comparativa contra ACBr: corrigir lacuna crítica do leitor v41.4 (certs `.3`-only ignorados) + enriquecer record com campos de auditoria (NumeroSerie, Thumbprint, DERBase64, Certificadora, Versão) + entregar 3 parsers ASN.1 para os OIDs declarados mas não consumidos (`.5` Título Eleitor, `.6` PIS/PASEP/CAEPF/CEI, `.8` RG separado) + helpers fiscais cross-cutting (`MatchCnpjRaiz` para validação NFe/eSocial e métodos `EstaValidoEm`/`EstaValido`/`DiasParaExpirar` no record).

**Novos OIDs reconhecidos:**

| OID | Constante | Conteúdo | Consumido |
| --- | --- | --- | --- |
| `2.16.76.1.3.2` | `OID_ICPBR_PJ_NOME_LEGACY` | Nome PJ legacy (DOC-ICP-04 pré-v3) | Reconhecido em `IsOidIcpBrasilPJ` |
| `2.16.76.1.3.3` | `OID_ICPBR_E_CNPJ_LEGACY` | **CNPJ legacy — fallback crítico** | Sim — `TentarExtrairCnpjPJ` |
| `2.16.76.1.3.5` | `OID_ICPBR_E_CPF_TITULO` | Título de Eleitor | Sim — `ParseTituloEleitor` |
| `2.16.76.1.3.6` | `OID_ICPBR_E_CPF_INSS` | PIS/PASEP (v3) ou CAEPF/CEI (v6+) | Sim — `ParsePisOuCaepf` |
| `2.16.76.1.3.8` | `OID_ICPBR_E_CPF_RG` | RG separado | Sim — `ParseRgSeparado` |
| `2.16.76.1.3.10` | `OID_ICPBR_OAB` | OAB digital | Reconhecido (parser pendente em S11) |

**Novos campos no `TIcpBrasilCertificado`:**

| Campo | Tipo | Origem |
| --- | --- | --- |
| `Certificadora` | `string` | `Issuer.O=` (NID=17) |
| `NumeroSerie` / `NumeroSerieHex` | `string` | `X509_get_serialNumber` + BN_bn2dec/hex |
| `ThumbPrintSHA1` / `ThumbPrintSHA256` | `string` (hex uppercase) | `X509_digest` + EVP_sha1/256 |
| `DERBase64` | `string` | `i2d_X509` + Base64 |
| `Versao` | `Integer` | `X509_get_version` |
| `TituloEleitor` | `string` | OID `.5` |
| `PisOuCaepf` | `string` | OID `.6` |
| `RgSeparado` | `string` | OID `.8` |

**Novos métodos do record (`TIcpBrasilCertificadoHelper`):** `EstaValidoEm(AData)`, `EstaValido`, `DiasParaExpirar`.

**Novo helper público em `_subject.pas`:** `MatchCnpjRaiz(ACertCnpj, ADocCnpj): Boolean` — compara raiz 8 dígitos para validação fiscal (espelha política `ValidarCNPJCertificado` do ACBr).

**Novos helpers em `ssl_openssl_x509_ext.pas`:** `X509GetSubjectO`, `X509GetIssuerO`, `X509GetSerialNumberDec`, `X509GetSerialNumberHex`, `X509GetThumbprintSHA1`, `X509GetThumbprintSHA256`, `X509GetDERBytes`, `X509GetDERBase64`, `X509GetVersion`.

### v41.6 (2026-05-01, S9 — chain validation + Certificate Policies — contribuição CSL Tech Solutions)

S9 entrega validação programática de cadeia X509 **offline**, sem depender do TLS handshake. Posiciona o vendor à frente do ACBr (que delega validação ao SO).

**2 novas units CSL:**

| Unit | Propósito | Versão |
| --- | --- | --- |
| `ssl_openssl_chain_verify.pas` | `TX509ChainVerifier` com bindings auto-contidos para `X509_STORE_*`, `X509_STORE_CTX_*`, `X509_verify_cert`, `PEM_read_bio_X509`. API: `LoadStoreFromPEM`/`LoadStoreFromCertList`/`AddTrustedCert`/`Verify`. | 001.000.000 |
| `ssl_openssl_icpbrasil_policy.pas` | Parser da extensão Certificate Policies (`2.5.29.32`) via `asn1util.ASNItem`. Reconhece OIDs ITI prefix `2.16.76.1.2.*` e classifica como `AC-Raiz V1..V10`. | 001.000.000 |

**Novo overload em `LerDoPfx` (com options):**

```pascal
type
  TLerDoPfxOptions = record
    VerificarChain:    Boolean;
    AcRaizBundlePath:  string;       // '' = bundles/ac-raiz-icp-brasil.pem
    VerificarPolicy:   Boolean;
  end;

class function TIcpBrasilCertificadoReader.LerDoPfx(
  const APfxBytes: array of Byte;
  const ASenha: AnsiString;
  const AOptions: TLerDoPfxOptions): TIcpBrasilCertificado; overload;
```

**Novos campos no `TIcpBrasilCertificado` (populados quando options=True):**

| Campo | Tipo | Origem |
| --- | --- | --- |
| `ChainVerificado` | `Boolean` | Indica que caller pediu validação |
| `ChainValido` | `Boolean` | True se `X509_verify_cert` retornou 1 |
| `ChainErro` | `string` | Texto humano via `X509_verify_cert_error_string` |
| `ChainErroCodigo` | `Integer` | `X509_V_ERR_*` |
| `ChainProfundidade` | `Integer` | Profundidade até erro |
| `PolicyVerificada` | `Boolean` | Caller pediu policy parse |
| `PolicyOids` | `array of string` | Todos os policy OIDs encontrados |
| `PolicyValida` | `Boolean` | True se ao menos 1 OID ITI reconhecido |
| `AcRaizDetectada` | `string` | `'AC-Raiz V5'` etc. |
| `AcRaizVersao` | `Integer` | 1..10 ou 0 |

**Bundle AC-Raiz ICP-Brasil:**

- `bundles/AC-Raiz-ICP-Brasil-fetch.ps1` — script PowerShell que baixa AC-Raiz v1..v10 do ITI e gera `bundles/ac-raiz-icp-brasil.pem` (não commitado, gerado pelo consumidor).
- `bundles/README.md` — documentação de uso e refresh policy.
- [`docs-extra/ac-raiz-bundle.md`](docs-extra/ac-raiz-bundle.md) — guia completo da camada de chain validation.

**Compatibilidade:** o overload sem options (`LerDoPfx(bytes, senha)`) preserva comportamento V41.5 byte-a-byte. CRL/OCSP entregues em V41.7.

### v41.7 (2026-05-01, S10 — revogação programática completa — contribuição CSL Tech Solutions)

S10 fecha a maior lacuna estrutural face ao Fisco: revogação programática via CRL e OCSP, sem depender do SO. Detalhes em [`Documentation/docs-extra/revocation.md`](Documentation/docs-extra/revocation.md).

**3 novas units CSL:**

| Unit | Propósito | Versão |
| --- | --- | --- |
| `ssl_openssl_icpbrasil_crl.pas` | `TIcpBrasilCrlClient` com cache filesystem (TTL `nextUpdate`), download via `httpsend`. `LoadFromFile`/`LoadFromUrl`/`IsRevogado`/`VerifySignature`. | 001.000.000 |
| `ssl_openssl_icpbrasil_ocsp.pas` | `TIcpBrasilOcspClient` com bindings auto-contidos (`OCSP_REQUEST_*`, `OCSP_RESPONSE_*`, `OCSP_basic_verify`). POST `application/ocsp-request` via httpsend. | 001.000.000 |
| `ssl_openssl_icpbrasil_extparsers.pas` | Parsers AIA (`1.3.6.1.5.5.7.1.1`) + CDP (`2.5.29.31`) — extracao de URLs OCSP/caIssuers/CRL. | 001.000.000 |

**`ssl_openssl_chain_verify.pas`** ganha bindings CRL: `LoadCrlFromBytes`/`LoadCrlFromPEM`/`FreeCrl`/`VerifyCrlSignature`/`IsRevogadoNaCRL`.

**Novo enum + novos campos no record:**

```pascal
type
  TRevogacaoMode = (rmNone, rmCRL, rmOCSP, rmOCSPThenCRL, rmCRLThenOCSP);

  // TLerDoPfxOptions ganha:
  VerificarRevogacao: TRevogacaoMode;
  CrlCacheDir:        string;
  OcspTimeoutMs:      Integer;

  // TIcpBrasilCertificado ganha:
  RevogacaoVerificada: Boolean;
  Revogado:            Boolean;
  RevogacaoMotivo:     string;
  RevogacaoData:       TDateTime;
  RevogacaoFonte:      string;
  RevogacaoTimestamp:  TDateTime;
  OcspUrls:            array of string;
  CaIssuersUrls:       array of string;
  CrlUrls:             array of string;
```

### v41.8 (2026-05-01, S11 — subject enrichment SAN/KU/EKU/OAB)

Cobertura completa DOC-ICP-04 v8.x. Detalhes em [`Documentation/docs-extra/san-parsing.md`](Documentation/docs-extra/san-parsing.md) (a criar) e [`Documentation/docs-extra/oab-digital.md`](Documentation/docs-extra/oab-digital.md) (a criar).

**1 nova unit CSL:** `ssl_openssl_icpbrasil_san.pas` (001.000.000) — Parsers para extensões `2.5.29.17` (SAN), `2.5.29.15` (Key Usage), `2.5.29.37` (Extended Key Usage) + OID `2.16.76.1.3.10` (OAB digital).

**8 novos campos no record:** `DnsNames`, `IpAddresses`, `Uris`, `SanEmails`, `KeyUsageEncontrada`/`KeyUsageStr`, `ExtKeyUsageOids`/`ExtKeyUsageNames`, `OabNumero`/`OabUf`. Helper `KeyUsageToString` + dictionary `EkuOidName`.

### v41.9 (2026-05-01, S12 — PKCS#7/CAdES + RFC 3161 TSP)

Synapse passa a ser **standalone para emissão fiscal** — assinatura nativa sem dependência de XmlSec/MSXML. Detalhes em [`Documentation/docs-extra/cades-signing.md`](Documentation/docs-extra/cades-signing.md) (a criar).

**2 novas units CSL:**

| Unit | Propósito | Versão |
| --- | --- | --- |
| `ssl_openssl_icpbrasil_pkcs7.pas` | `TPkcs7Signer` com bindings `PKCS7_sign`/`PKCS7_verify`/`i2d_PKCS7`. Modos `psBinarioCMS`/`psDetached` (NFe)/`psAttached`/`psBase64`. | 001.000.000 |
| `ssl_openssl_icpbrasil_tsp.pas` | `TTspClient` (RFC 3161). Constroi TimeStampReq DER manualmente (sem dependência de OpenSSL TS_REQ). POST `application/timestamp-query` via httpsend. | 001.000.000 |

### v42.0 (2026-05-01, S13a + S13b — Hardware: Windows Store + PKCS#11 cross-platform)

A grande lacuna do Synapse face ao ACBr fechada — e mais ainda: **Synapse é a única biblioteca Pascal com PKCS#11 portátil** (Linux/macOS/Windows). Detalhes em [`Documentation/docs-extra/winstore.md`](Documentation/docs-extra/winstore.md) (a criar) e [`Documentation/docs-extra/pkcs11.md`](Documentation/docs-extra/pkcs11.md) (a criar).

**2 novas units CSL:**

| Unit | Propósito | Versão |
| --- | --- | --- |
| `ssl_openssl_icpbrasil_winstore.pas` (Windows-only) | `TWinCertStore` (slMy/slCurrentUser/slLocalMachine), `EnumerateCertificates`, `FindByThumbprint`. Função pública `IsCertificadoEmHardware` adapta `ACBrDFeWinCrypt.GetCertIsHardware` (LGPL v2.1). | 001.000.000 |
| `ssl_openssl_icpbrasil_pkcs11.pas` (cross-platform) | `TPkcs11Loader` com tipos PKCS#11 standalone. `LoadModule`/`AutoDetectAndLoad` (paths conhecidos: SoftHSM2, eToken, SafeNet em Linux/Windows/macOS). `OpenSession(slot, pin)`. `EnumerateCertificates` (CKO_CERTIFICATE) com extracao de DerBytes. | 001.000.000 |

**Atribuição LGPL:** `IsCertificadoEmHardware` deriva de ACBr LGPL v2.1. Header da unit S13a documenta atribuição explícita (estratégia dual-license).

### v42.1 (2026-05-01, S14 — fiscal helpers + cross-platform fixes)

Sprint final — helpers fiscais one-liner + correções cross-platform descobertas durante validação. Detalhes em [`Documentation/docs-extra/fiscal-helpers.md`](Documentation/docs-extra/fiscal-helpers.md) (a criar).

**1 nova unit CSL:** `ssl_openssl_icpbrasil_fiscal.pas` (001.000.000) — Funções one-liner:

```pascal
function IsCertificadoNFe(const ACert: TIcpBrasilCertificado): Boolean;
function IsCertificadoESocial(const ACert: TIcpBrasilCertificado): Boolean;
function IsCertificadoSerpro(const ACert: TIcpBrasilCertificado): Boolean;
function IsCertificadoSefaz(const ACert: TIcpBrasilCertificado; const AUf: string): Boolean;
function IsCertificadoEFDReinf(const ACert: TIcpBrasilCertificado): Boolean;
function HasExtKeyUsage(const ACert: TIcpBrasilCertificado; const AOID: string): Boolean;
```

**Cross-platform fixes (todos pré-existentes ou auto-introduzidos em S9/S10/S12/S13):** `{$IFDEF FPC}DynLibs.GetProcAddress` → `{$IFDEF MSWINDOWS}Windows.GetProcAddress` em 6 units (alinhamento com uses clause); `SetDllDirectoryW` declarado externamente para FPC em `ssl_openssl_paths.pas`.

**Build sanity final:** Delphi 12 (`dcc32`) — 65.715 linhas, 0 erros. FPC 3.3.1 Win64 — 12 units S9-S14 compilam isoladamente sem erros.

#### Quick start — leitura de PFX ICP-Brasil (v41.5)

```pascal
uses ssl_openssl_icpbrasil, ssl_openssl_icpbrasil_subject;

var
  LPfx: array of Byte;
  LCert: TIcpBrasilCertificado;
begin
  // Carregar bytes do PFX em LPfx (TFileStream, RTTI, etc).
  LCert := TIcpBrasilCertificadoReader.LerDoPfx(LPfx, AnsiString('senha'));

  case LCert.Tipo of
    ibtECnpj: WriteLn('e-CNPJ ', LCert.DocumentoFormatado);
    ibtECpf:  WriteLn('e-CPF  ', LCert.DocumentoFormatado);
  end;
  WriteLn('Titular:       ', LCert.SubjectTitular);
  WriteLn('Certificadora: ', LCert.Certificadora);              // novo S8
  WriteLn('Serie:         ', LCert.NumeroSerie);                // novo S8
  WriteLn('Thumbprint:    ', LCert.ThumbPrintSHA256);           // novo S8
  WriteLn('Versao X509:   v', IntToStr(LCert.Versao + 1));      // novo S8 (0=v1, 2=v3)
  WriteLn('Vence:         ', DateToStr(LCert.NotAfter));
  WriteLn('Dias restantes: ', LCert.DiasParaExpirar);           // novo S8 (helper)

  // Validacao fiscal (NFe / eSocial / EFD-Reinf):
  if LCert.EstaValido and                                        // novo S8
     MatchCnpjRaiz(LCert.SubjectDocumento, AnsiString('12345678000190')) then  // novo S8
    WriteLn('OK para assinar documento fiscal.')
  else
    WriteLn('Cert expirado ou CNPJ raiz divergente.');
end;
```

Excecoes possiveis: `EIcpBrasilSenhaInvalida`, `EIcpBrasilPfxCorrompido`,
`EIcpBrasilNaoIcpBrasil`. Versao tolerante: `TentarLerDoPfx` (devolve
`Tipo=ibtDesconhecido` em vez de raise para certs nao-ICP-Brasil).

**Compatibilidade de certs antigos (v41.5):** o leitor agora reconhece OID
`2.16.76.1.3.3` legacy (DOC-ICP-04 pré-v3) como fallback automático para
`2.16.76.1.3.7` — e-CNPJ A1 antigos que populavam apenas `.3` deixam de
falhar silenciosamente.

Documentacao adicional: [`docs-extra/icpbrasil-oids.md`](docs-extra/icpbrasil-oids.md),
[`docs-extra/integration-guide.md`](docs-extra/integration-guide.md),
[`docs-extra/cn-formats.md`](docs-extra/cn-formats.md),
[`docs-extra/security-considerations.md`](docs-extra/security-considerations.md).

Suite de testes: `tests-extra/ssl_openssl_icpbrasil_tests.lpr` (38 testes
DUnitX, vetores 100% sinteticos).

### Package

| Item | Versão atual |
| --- | --- |
| `synapse.dpk` | 42.1 (60 units) |
| `laz_synapse.lpk` | 42.1 (60 entries) |
| `VERSION.md` / `CHANGELOG.md` | 42.1 |

### `laz_synapse.lpk` (actualizado)

- Upstream: 41.0, 35 files.
- CSL fork: **42.1, 60 files** — V41.4 (6 units ICP-Brasil + `ssl_openssl_x509_ext`); V41.6 (`ssl_openssl_chain_verify` + `ssl_openssl_icpbrasil_policy`); V41.7 (`ssl_openssl_icpbrasil_crl` + `ssl_openssl_icpbrasil_ocsp` + `ssl_openssl_icpbrasil_extparsers`); V41.8 (`ssl_openssl_icpbrasil_san`); V41.9 (`ssl_openssl_icpbrasil_pkcs7` + `ssl_openssl_icpbrasil_tsp`); V42.0 (`ssl_openssl_icpbrasil_winstore` + `ssl_openssl_icpbrasil_pkcs11`); V42.1 (`ssl_openssl_icpbrasil_fiscal`).

---

## Quick Start — LDAPS + OpenSSL 4.0 + CBT

Autentica contra Active Directory via LDAPS (porta 636) usando OpenSSL 4.0 com DLLs em `<exe>/dll/v4/<arch>/`, captura hash SHA-256 do certificado servidor e faz bind SASL GSSAPI com Channel Binding Token (RFC 5929).

```pascal
program QuickStartLdapCbt;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  blcksock, ldapsend, ssl_openssl4, ssl_openssl_paths;

var
  LLdap: TLDAPSend;
  LCbt:  AnsiString;
begin
  // 1) Carregar OpenSSL 4.0 a partir de dll\v4\win64\ (relativo ao exe)
  TOpenSSLPaths.Apply(4);

  LLdap := TLDAPSend.Create;
  try
    LLdap.TargetHost := 'dc.empresa.local';
    LLdap.TargetPort := '636';
    LLdap.AutoTLS    := False;      // LDAPS puro, sem StartTLS
    LLdap.FullSSL    := True;
    LLdap.Version    := 3;

    // 2) SNI obrigatório para mTLS; verificação de certificado activada
    LLdap.Sock.SNIHost    := 'dc.empresa.local';
    LLdap.Sock.VerifyCert := True;

    if not LLdap.Login then
      raise Exception.CreateFmt('Login falhou: %s', [LLdap.Sock.LastErrorDesc]);

    // 3) Captura hash SHA-256 do certificado do servidor (32 bytes raw)
    LCbt := TSSLOpenSSL(LLdap.Sock.SSL).GetPeerCertSHA256Hash;

    // 4) Bind Kerberos com Channel Binding Token (tls-server-end-point)
    if not LLdap.BindGSSAPIWithCBT('ldap/dc.empresa.local', LCbt) then
      raise Exception.Create('Bind GSSAPI+CBT falhou');

    WriteLn('Autenticado com sucesso.');
  finally
    LLdap.Free;
  end;
end.
```

Dependências runtime: `libcrypto-4-x64.dll`, `libssl-4-x64.dll` em `dll\v4\win64\` ao lado do `.exe`. `secur32.dll` resolvida do `System32` (SSPI para Kerberos).

---

## API CSL-only — classe por classe

Esta secção documenta **apenas** o que o fork CSL acrescentou ou modificou em relação ao upstream. Para a API Synapse original (core `TLDAPSend`, `TTCPBlockSocket`, SMTP/IMAP/POP3/FTP/HTTP/DNS...) ver <https://www.ararat.cz/synapse/doku.php>. Para análise exaustiva por classe (7 secções) consultar [Documentation/Analise/](Documentation/Analise/).

---

### `TOpenSSLPaths` (unit `ssl_openssl_paths.pas`)

Helper **opt-in** para resolver o path das DLLs OpenSSL via `SetDllDirectory` do Windows. 100% nova no fork CSL (sem equivalente upstream). POSIX é stub no-op (use `LD_LIBRARY_PATH` ou equivalente).

**Classe estática** (apenas `class procedure` / `class function` — não se instancia).

| Método | Assinatura | Propósito |
| --- | --- | --- |
| `SetCustomPath` | `class procedure SetCustomPath(const APath: string); static;` | Define path custom a usar por `Apply`/`Resolve`. Passar string vazia limpa e volta ao path calculado (`<exe>\dll\v<N>\<arch>\`). |
| `Resolve` | `class function Resolve(AVersion: Integer): string; static;` | Devolve o path que `Apply` usaria, sem aplicar. Útil para diagnóstico/logging. Se `SetCustomPath` foi chamado, devolve esse path. |
| `Apply` | `class procedure Apply(AVersion: Integer); static;` | Chama `SetDllDirectory(<path>)` com o path resolvido. Windows tenta esse path primeiro no próximo `LoadLibrary`. POSIX é no-op. |

**Comportamento do `Apply`:**

1. Se `SetCustomPath` foi chamado com path não-vazio, usa-o.
2. Senão, calcula `<pasta_do_exe>\dll\v<AVersion>\<arch>\` onde `<arch>` é `win32` ou `win64`.
3. Chama `SetDllDirectory(LPath)`. Se a pasta não existir, Windows continua nos fallbacks padrão (pasta do `.exe`, `PATH`, `System32`).

**Exemplo — path default:**

```pascal
uses ssl_openssl_paths;

begin
  // Tenta carregar OpenSSL 3 de <exe>\dll\v3\win64\libssl-3-x64.dll
  TOpenSSLPaths.Apply(3);
  // ... LoadLibrary subsequente usa esse path primeiro
end;
```

**Exemplo — path custom (override):**

```pascal
uses ssl_openssl_paths;

begin
  // Força carregamento de OpenSSL 4 a partir de pasta específica
  TOpenSSLPaths.SetCustomPath('C:\Program Files\OpenSSL-4.0\bin\');
  TOpenSSLPaths.Apply(4);
  // Diagnostic: confirmar onde foi apontado
  WriteLn(TOpenSSLPaths.Resolve(4));  // 'C:\Program Files\OpenSSL-4.0\bin\'
end;
```

**Exemplo — diagnóstico antes de aplicar:**

```pascal
var
  LResolvedPath: string;
begin
  LResolvedPath := TOpenSSLPaths.Resolve(4);
  if not DirectoryExists(LResolvedPath) then
    WriteLn('Aviso: pasta ' + LResolvedPath + ' não existe; OpenSSL cairá em fallback');
  TOpenSSLPaths.Apply(4);
end;
```

---

### `TSSLOpenSSL4` (unit `ssl_openssl4.pas`)

Plugin SSL/TLS para **OpenSSL 4.0.0**. Fork mecânico de `TSSLOpenSSL3` — classe renomeada, DLLs bumped de `-3` para `-4`. API Pascal **idêntica** ao `TSSLOpenSSL3` (ICS V9.6 confirma que OpenSSL 4.0 mantém API unificada com 3.x).

**Herança:** `TSSLOpenSSL4 → TCustomSSL → TObject`.

**Uso:** basta listar `ssl_openssl4` no `uses`. A secção `initialization` da unit regista automaticamente `SSLImplementation := TSSLOpenSSL4` — o próximo socket TCP criado usa este plugin.

**DLLs esperadas:**

- Windows Win32: `libcrypto-4.dll` + `libssl-4.dll`
- Windows Win64: `libcrypto-4-x64.dll` + `libssl-4-x64.dll`
- Linux: `libcrypto.so.4` + `libssl.so.4`
- macOS: `libcrypto.4.dylib` + `libssl.4.dylib`

**Exemplo — HTTPS via OpenSSL 4.0:**

```pascal
uses httpsend, ssl_openssl4, ssl_openssl_paths;

var
  LHttp: THTTPSend;
begin
  TOpenSSLPaths.Apply(4);    // carrega de dll\v4\<arch>\

  LHttp := THTTPSend.Create;
  try
    // SSLImplementation já apontado para TSSLOpenSSL4 via initialization
    LHttp.Sock.SSL.SNIHost := 'api.exemplo.com';
    if LHttp.HTTPMethod('GET', 'https://api.exemplo.com/v1/ping') then
      WriteLn('Resposta: ', LHttp.ResultCode, ' ', LHttp.ResultString);
  finally
    LHttp.Free;
  end;
end;
```

**Exemplo — LDAPS com selector em compile-time:**

```pascal
uses ldapsend,
  {$IFDEF USE_OPENSSL4} ssl_openssl4
  {$ELSE}               ssl_openssl3
  {$ENDIF}, ssl_openssl_paths;

begin
  {$IFDEF USE_OPENSSL4} TOpenSSLPaths.Apply(4);
  {$ELSE}               TOpenSSLPaths.Apply(3);
  {$ENDIF}
  // ... LDAPSend herda o SSLImplementation registado via initialization
end;
```

---

### `TLDAPSend` (extensões CSL, unit `ldapsend.pas`)

A classe base é do upstream (cliente LDAP v2/v3 genérico); o fork CSL acrescentou 15+ métodos para Active Directory moderno: controles MS proprietários, SASL GSSAPI via SSPI, operações de senha AD, LDAP Signing, RootDSE.

#### Controles AD (RFC + OIDs Microsoft)

| Método | Assinatura | OID | Propósito |
| --- | --- | --- | --- |
| `SearchDirSync` | `function SearchDirSync(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean;` | `1.2.840.113556.1.4.841` | Busca incremental. Estado em `DirSyncCookie`, flags em `DirSyncFlags`, limite em `DirSyncMaxBytes`. |
| `SearchWithSDFlags` | `function SearchWithSDFlags(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; ASDFlags: Integer; const AAttributes: TStrings): Boolean;` | `1.2.840.113556.1.4.801` | Partes de `nTSecurityDescriptor`. Flags: `LDAP_SD_OWNER`, `LDAP_SD_GROUP`, `LDAP_SD_DACL`, `LDAP_SD_SACL`, `LDAP_SD_ALL`. |
| `SearchWithExtendedDN` | `function SearchWithExtendedDN(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings; AFlag: Integer = LDAP_EXTENDED_DN_STANDARD): Boolean;` | `1.2.840.113556.1.4.529` | DNs com GUID/SID embutidos. `AFlag`: `LDAP_EXTENDED_DN_HEX_STRING` (0) ou `LDAP_EXTENDED_DN_STANDARD` (1). |
| `SearchShowDeleted` | `function SearchShowDeleted(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean;` | `1.2.840.113556.1.4.1338` | Inclui objectos tombstoned (container `Deleted Objects`). |
| `SearchShowRecycled` | `function SearchShowRecycled(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean;` | `1.2.840.113556.1.4.2064` | Inclui objectos na Recycle Bin do AD. |
| `SearchWithServerSort` | `function SearchWithServerSort(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const ASortAttribute: AnsiString; const AAttributes: TStrings): Boolean;` | `1.2.840.113556.1.4.473` | Ordenação server-side. |
| `ModifyPermissive` | `function ModifyPermissive(const AObj: AnsiString; AOp: TLDAPModifyOp; const AValue: TLDAPAttribute): Boolean;` | `1.2.840.113556.1.4.1413` | Modify que ignora valores redundantes (ex.: add membro já existente). |
| `DeleteTree` | `function DeleteTree(const AObj: AnsiString): Boolean;` | `1.2.840.113556.1.4.805` | Apaga subtree completa (OU com todos os filhos). |

**Exemplo — `SearchDirSync` incremental:**

```pascal
var
  LLdap: TLDAPSend;
  LAttrs: TStringList;
  i, j: Integer;
begin
  // ... LLdap.Login + Bind
  LAttrs := TStringList.Create;
  try
    LAttrs.Add('cn');
    LAttrs.Add('objectGUID');
    LAttrs.Add('whenChanged');
    LLdap.DirSyncCookie := '';                    // primeira chamada: cookie vazio
    if LLdap.SearchDirSync('DC=empresa,DC=local', '(objectClass=user)',
                           SS_WholeSubtree, LAttrs) then
    begin
      for i := 0 to LLdap.SearchResult.Count - 1 do
        for j := 0 to LLdap.SearchResult[i].Attributes.Count - 1 do
          WriteLn(LLdap.SearchResult[i].Attributes[j].AttributeName, ' = ',
                  LLdap.SearchResult[i].Attributes[j].Value.AsString);
      // Guardar LLdap.DirSyncCookie para próxima chamada incremental
    end;
  finally
    LAttrs.Free;
  end;
end;
```

**Exemplo — `DeleteTree` (cuidado, destrutivo):**

```pascal
if LLdap.DeleteTree('OU=Temporarios,DC=empresa,DC=local') then
  WriteLn('OU e todos os filhos apagados.');
```

#### SASL GSSAPI/Kerberos (Windows-only — SSPI inline)

| Método | Assinatura | Propósito |
| --- | --- | --- |
| `BindGSSAPI` | `function BindGSSAPI(const ASPN: AnsiString): Boolean;` | Bind Kerberos via SSPI. `ASPN` = Service Principal Name (ex.: `'ldap/dc.empresa.local'`). Requer máquina no domínio. |
| `BindGSSAPIWithCBT` | `function BindGSSAPIWithCBT(const ASPN, ACertHash: AnsiString): Boolean;` | Bind Kerberos + Channel Binding Token `tls-server-end-point` (RFC 5929). `ACertHash` = `GetPeerCertSHA256Hash` do socket SSL. Protege contra MitM em LDAPS. |

POSIX: stub que retorna `False` com mensagem `"GSSAPI via SSPI nao disponivel em POSIX -- use Kerberos via libgssapi_krb5 (agendado V2.0.0)"`. Port real em roadmap V2.0.0.

**Exemplo — ver [Quick Start](#quick-start--ldaps--openssl-40--cbt) acima.**

#### Operações de senha (requer LDAPS ou StartTLS)

| Método | Assinatura | Propósito |
| --- | --- | --- |
| `ChangePassword` | `function ChangePassword(const AUserDN, AOldPassword, ANewPassword: AnsiString): Boolean;` | Utilizador muda a sua própria senha. Requer conhecer a senha antiga. |
| `SetPassword` | `function SetPassword(const AUserDN, ANewPassword: AnsiString): Boolean;` | Admin define senha de terceiros. Requer permissão `Reset Password`. |
| `ForcePasswordChange` | `function ForcePasswordChange(const AUserDN: AnsiString): Boolean;` | Define `pwdLastSet = 0`; força utilizador a mudar no próximo login. |

Todas as operações de senha usam UTF-16LE (quote + senha + quote) conforme MS-ADTS §3.1.1.3.1.5. Implementação interna trata a codificação.

**Exemplo — admin reset de senha:**

```pascal
if LLdap.SetPassword('CN=joao,OU=Usuarios,DC=empresa,DC=local', 'Nova@Senha123!') then
  WriteLn('Senha redefinida.');
if LLdap.ForcePasswordChange('CN=joao,OU=Usuarios,DC=empresa,DC=local') then
  WriteLn('Utilizador vai mudar senha no próximo login.');
```

#### Class functions — status de conta (decodificam `userAccountControl`)

| Método | Assinatura | Flag |
| --- | --- | --- |
| `IsAccountLocked` | `class function IsAccountLocked(AUac: Integer): Boolean;` | `$0010` (UF_LOCKOUT) |
| `IsAccountDisabled` | `class function IsAccountDisabled(AUac: Integer): Boolean;` | `$0002` (UF_ACCOUNTDISABLE) |
| `IsPasswordExpired` | `class function IsPasswordExpired(AUac: Integer): Boolean;` | `$800000` (UF_PASSWORD_EXPIRED) |

**Exemplo:**

```pascal
var
  LUac: Integer;
begin
  LUac := StrToIntDef(LLdap.SearchResult[0].Attributes.GetAttrByName('userAccountControl').Value.AsString, 0);
  if TLDAPSend.IsAccountDisabled(LUac) then
    WriteLn('Conta desactivada.');
  if TLDAPSend.IsPasswordExpired(LUac) then
    WriteLn('Senha expirada.');
end;
```

#### RootDSE

| Método | Assinatura | Propósito |
| --- | --- | --- |
| `GetRootDSE` | `function GetRootDSE(const AAttributes: TStrings): Boolean;` | Busca o RootDSE (entrada anónima no topo da árvore). Útil para `defaultNamingContext`, `supportedControl`, `dnsHostName`, `serverName`. |

---

### `TLDAPAttribute` (V1.7.1 + V1.7.2, unit `ldapsend.pas`)

Classe upstream estendida pelo fork CSL com tipagem automática (V1.7.1 / 001.007.004) e preservação de bytes binários (V1.7.2 / 001.007.005).

#### Método público novo (V1.7.2)

| Método | Assinatura | Propósito |
| --- | --- | --- |
| `AddRaw` | `function AddRaw(const ARaw: AnsiString): Integer;` | Adiciona valor **sem nenhuma conversão**. Bypassa `UnicodeToRawAnsi`, `UnquoteStr` e `EncodeBase64`. Armazena bytes directamente em `FRawValues`. Preserva 100% dos 256 bytes 0x00-0xFF. **Usado pelo parser ASN.1 interno** (`TLDAPSend.Search` + `DoSearchAD`). |

#### Properties novas (V1.7.1)

| Property | Tipo | Acesso | Propósito |
| --- | --- | --- | --- |
| `ValueType` | `TLDAPValueType` | read-only | Resolvido automaticamente ao chamar `SetAttributeName` via `ResolveLDAPValueType`. |
| `Value` | `TLDAPAttributeValue` | read-only | Acessor do índice 0 (singular, caso mais comum). |
| `Values[Index: Integer]` | `TLDAPAttributeValue` | read-only | Acessor multi-valued por índice. |

#### Overrides (V1.7.1 + V1.7.2)

- `procedure Clear; override;` — reseta `FRawValues` em sincronia com `TStringList` interno (futuro-proof contra paths que reusem instância via `Clear+Add`).
- `function Get(Index: integer): string; override;` — devolve string já decodificada conforme `FValueType` (GUID → `{XXX-XXX}`, SID → `S-1-5-21-...`, inteiro → decimal, data ISO-like, hex). Blindado com `try/except` duplo + fallback `RawToHex`.
- `procedure Put(Index: integer; const Value: string); override;` — defensivo: salta `UnquoteStr` quando `FValueType in [vtGUID, vtSID, vtOctetString, vtBitString]`.

**Exemplo — acesso tipado após Search:**

```pascal
var
  LAttr: TLDAPAttribute;
begin
  // ... LLdap.Search(...)
  LAttr := LLdap.SearchResult[0].Attributes.GetAttrByName('objectGUID');
  if LAttr <> nil then
  begin
    WriteLn('Raw bytes: ', Length(LAttr.Value.Raw));        // 16
    WriteLn('Formatted: ', LAttr.Value.AsString);            // '{E22791BE-5255-4665-951F-4A630F4AE269}'
    WriteLn('As GUID:   ', GUIDToString(LAttr.Value.AsGuid));
    WriteLn('ValueType: ', Ord(LAttr.ValueType));            // Ord(vtGUID) = 11
  end;
end;
```

**Exemplo — atributo multi-valued (`memberOf`):**

```pascal
var
  LAttr: TLDAPAttribute;
  i: Integer;
begin
  LAttr := LLdap.SearchResult[0].Attributes.GetAttrByName('memberOf');
  if LAttr <> nil then
    for i := 0 to LAttr.Count - 1 do
      WriteLn('Grupo ', i, ': ', LAttr.Values[i].AsString);
end;
```

---

### `TLDAPAttributeValue` (V1.7.1, unit `ldapsend.pas`)

Record público, 100% CSL, acessor tipado estilo `TField` (Data.DB) para um valor individual de `TLDAPAttribute`. Por valor — sem gestão de memória pelo consumidor.

**Obtido via** `TLDAPAttribute.Value` (singular) ou `TLDAPAttribute.Values[Index]` (multi-valued). Nunca instanciado directamente pelo consumidor.

#### Métodos de conversão (nunca lançam excepção — devolvem default sintáctico)

| Método | Retorno | Default se tipo não casar |
| --- | --- | --- |
| `IsNull` | `Boolean` | — (verdade se valor vazio) |
| `AsString` | `string` | `''` |
| `AsInteger` | `Int64` | `0` |
| `AsFloat` | `Double` | `0.0` |
| `AsBoolean` | `Boolean` | `False` |
| `AsDateTime` | `TDateTime` | `0` (NullDate) |
| `AsBinary` | `TBytes` | array vazio |
| `AsHex` | `string` | `''` |
| `AsSid` | `string` | `''` (formato `S-1-5-21-...`) |
| `AsGuid` | `TGUID` | `TGUID.Empty` |
| `AsVariant` | `Variant` | `Null` |
| `Raw` | `AnsiString` (property) | bytes crus tal como vieram do socket |
| `ValueType` | `TLDAPValueType` (property) | `vtUnknown` |

**Exemplo — decodificação de atributos heterogéneos:**

```pascal
var
  LResult: TLDAPResult;
  LUac, LPwdLastSet: TLDAPAttributeValue;
begin
  LResult := LLdap.SearchResult[0];
  LUac        := LResult.Attributes.GetAttrByName('userAccountControl').Value;
  LPwdLastSet := LResult.Attributes.GetAttrByName('pwdLastSet').Value;

  WriteLn('UAC: ', LUac.AsInteger);                          // decimal
  WriteLn('Password expired: ',
          TLDAPSend.IsPasswordExpired(LUac.AsInteger));       // boolean
  WriteLn('pwdLastSet (FileTime): ', LPwdLastSet.AsInteger); // Int64 FileTime
  WriteLn('pwdLastSet (DateTime): ',
          DateTimeToStr(TLDAPSend.FileTimeToDateTime(LPwdLastSet.AsInteger)));
end;
```

---

### `TLDAPValueType` + `ResolveLDAPValueType` (V1.7.1, unit `ldapsend.pas`)

Enum público de 16 tipos LDAP cobrindo RFC 4517 + extensões MS-ADTS. 100% CSL.

```pascal
type
  TLDAPValueType = (
    vtUnknown, vtDirectoryString, vtIA5String, vtInteger, vtBoolean,
    vtOctetString, vtGeneralizedTime, vtUTCTime, vtDN, vtOID,
    vtSID, vtGUID, vtBitString, vtNumericString, vtEnhancedGuide, vtFileTime
  );
```

#### Constante companion — `LDAP_KNOWN_ATTRIBUTE_TYPES`

Mapa estático com ~110 atributos AD default: `objectGUID → vtGUID`, `objectSid → vtSID`, `userAccountControl → vtInteger`, `pwdLastSet → vtFileTime`, `whenCreated → vtGeneralizedTime`, `thumbnailPhoto → vtOctetString`, `userCertificate → vtOctetString`, `nTSecurityDescriptor → vtOctetString`, DNs, Directory Strings, etc.

#### Função pública — `ResolveLDAPValueType`

| Assinatura | Propósito |
| --- | --- |
| `function ResolveLDAPValueType(const AAttributeName: AnsiString): TLDAPValueType;` | Resolve o tipo pelo nome do atributo. Tolera sufixos `;binary` e `;range=...`. Devolve `vtUnknown` se não mapeado. |

**Exemplo — resolver tipo manualmente:**

```pascal
uses ldapsend;

begin
  Assert(ResolveLDAPValueType('objectGUID')         = vtGUID);
  Assert(ResolveLDAPValueType('objectGUID;binary')  = vtGUID);  // tolera sufixo
  Assert(ResolveLDAPValueType('member;range=0-499') = vtDN);    // tolera range
  Assert(ResolveLDAPValueType('atributoCustom')     = vtUnknown);
end;
```

**Exemplo — tratamento por tipo em loop genérico:**

```pascal
var
  LAttr: TLDAPAttribute;
  i: Integer;
begin
  for i := 0 to LResult.Attributes.Count - 1 do
  begin
    LAttr := LResult.Attributes[i];
    case LAttr.ValueType of
      vtFileTime:
        WriteLn(LAttr.AttributeName, ': ',
                DateTimeToStr(TLDAPSend.FileTimeToDateTime(LAttr.Value.AsInteger)));
      vtGUID:
        WriteLn(LAttr.AttributeName, ': ', LAttr.Value.AsString);  // '{XXX}'
      vtSID:
        WriteLn(LAttr.AttributeName, ': ', LAttr.Value.AsSid);      // 'S-1-5-...'
      vtInteger:
        WriteLn(LAttr.AttributeName, ': ', LAttr.Value.AsInteger);
    else
      WriteLn(LAttr.AttributeName, ': ', LAttr.Value.AsString);
    end;
  end;
end;
```

---

### `TTCPBlockSocket.GetPeerCertSHA256Hash` (unit `blcksock.pas`)

Única adição CSL em `blcksock.pas` (fork histórico 13/04/2026). Extrai hash SHA-256 do certificado servidor para uso como Channel Binding Token `tls-server-end-point` (RFC 5929).

| Método | Assinatura | Propósito |
| --- | --- | --- |
| `GetPeerCertSHA256Hash` | `function GetPeerCertSHA256Hash: AnsiString;` | Devolve 32 bytes raw (binário, não hex). Disponível em `TSSLOpenSSL`, `TSSLOpenSSL3`, `TSSLOpenSSL4`. Chamar apenas **depois** de `Connect` + handshake TLS completo. |

**Uso:** parâmetro `ACertHash` do `TLDAPSend.BindGSSAPIWithCBT`. Ver [Quick Start](#quick-start--ldaps--openssl-40--cbt).

**Exemplo — validação standalone (HTTPS):**

```pascal
var
  LHttp: THTTPSend;
  LHash: AnsiString;
  i: Integer;
  LHex: string;
begin
  LHttp := THTTPSend.Create;
  try
    LHttp.Sock.SNIHost := 'exemplo.com';
    if LHttp.HTTPMethod('GET', 'https://exemplo.com/') then
    begin
      LHash := TSSLOpenSSL(LHttp.Sock.SSL).GetPeerCertSHA256Hash;
      LHex := '';
      for i := 1 to Length(LHash) do
        LHex := LHex + IntToHex(Ord(LHash[i]), 2);
      WriteLn('Cert SHA-256: ', LHex);  // 64 caracteres hex
    end;
  finally
    LHttp.Free;
  end;
end;
```

---

### FileTime helpers (`TLDAPSend` class functions)

Duas `class function` estáticas para converter entre `TDateTime` Delphi e FileTime de 64 bits do AD. Usadas em atributos `pwdLastSet`, `lastLogon`, `accountExpires`, `badPasswordTime`, `whenCreated`/`whenChanged` (quando armazenados como FileTime).

| Método | Assinatura | Propósito |
| --- | --- | --- |
| `FileTimeToDateTime` | `class function FileTimeToDateTime(AFileTime: Int64): TDateTime;` | Converte FileTime (100-nanoseconds desde 1601-01-01 UTC) para `TDateTime`. Retorna `0` se `AFileTime = 0` (nunca) ou `$7FFFFFFFFFFFFFFF` (sempre). |
| `DateTimeToFileTime` | `class function DateTimeToFileTime(ADateTime: TDateTime): Int64;` | Conversão inversa. Útil para filtros LDAP com comparação temporal. |

**Exemplo — última alteração de senha de um utilizador:**

```pascal
var
  LPwdLastSetAttr: TLDAPAttribute;
  LFileTime: Int64;
begin
  // ... LLdap.Search('CN=joao,...', SS_BaseObject, '(objectClass=*)', Attrs)
  LPwdLastSetAttr := LLdap.SearchResult[0].Attributes.GetAttrByName('pwdLastSet');
  LFileTime := LPwdLastSetAttr.Value.AsInteger;
  if LFileTime = 0 then
    WriteLn('Senha nunca foi definida.')
  else
    WriteLn('Senha alterada em: ',
            DateTimeToStr(TLDAPSend.FileTimeToDateTime(LFileTime)));
end;
```

**Exemplo — filtro para contas activas nas últimas 24h:**

```pascal
var
  LCutoff: Int64;
  LFilter: AnsiString;
begin
  LCutoff := TLDAPSend.DateTimeToFileTime(Now - 1);    // 24h atrás
  LFilter := AnsiString(Format('(&(objectClass=user)(lastLogon>=%d))', [LCutoff]));
  LLdap.Search('DC=empresa,DC=local', False, LFilter, Attrs);
end;
```

---

## Selector OpenSSL (no projecto consumidor)

O consumidor (ex.: `ActiveDirectoryORM`) selecciona qual unit SSL usar via define em `ORM.Defines.inc`:

| Define | Unit usada | DLLs esperadas | Via |
| --- | --- | --- | --- |
| _(nenhum)_ | `ssl_openssl.pas` (legacy) | `libeay32.dll`/`ssleay32.dll` (PATH/System32) | Comportamento Synapse padrão |
| `USE_OPENSSL3` | `ssl_openssl3.pas` | `libcrypto-3*.dll` + `libssl-3*.dll` | `TOpenSSLPaths.Apply(3)` → `dll/v3/<arch>/` |
| `USE_OPENSSL4` | `ssl_openssl4.pas` (fork CSL) | `libcrypto-4*.dll` + `libssl-4*.dll` | `TOpenSSLPaths.Apply(4)` → `dll/v4/<arch>/` |

Definir ambos `USE_OPENSSL3` e `USE_OPENSSL4` dispara `{$MESSAGE FATAL}` em compile time.

---

## Compilação

### Delphi (via package `synapse.dpk`)

```powershell
dcc32 -M -B Packege\synapse\synapse.dpk
```

Gera `synapse.bpl` em `$(BDSCOMMONDIR)\Bpl`.

### Lazarus/FPC (via `laz_synapse.lpk`)

Abrir `Packege/synapse/laz_synapse.lpk` no Lazarus, "Use → Install".

### Consumo sem package (source units via `-U` path)

Em `dcc32.cfg`/`dcc64.cfg`:

```text
-U"Packege\synapse"
```

Em `fpc32.opts`/`fpc64.opts`:

```text
-FuPackege/synapse
```

---

## Divergências vs upstream — consolidado

A cópia CSL tem 2 camadas de modificações sobre o upstream:

1. **Fork histórico (13/04/2026)** — pré-existente a esta sessão. Ficheiros modificados preservam backup em `bak/*.bak` (baseline original).
2. **Fork sessões 21-22/04/2026 (V1.7.0 → V1.7.2)** — 3 ficheiros novos + patches em `ldapsend.pas` + `laz_synapse.lpk` bumped + `synapse.dpk` novo.

### Fork histórico (13/04/2026) — 8 ficheiros modificados com backup em `bak/`

A pasta `bak/` preserva o estado original **antes** das modificações CSL históricas. `diff bak/X.bak X` mostra as mudanças aplicadas.

| Ficheiro | Actual | Diff vs bak | Notas CSL |
| --- | --- | --- | --- |
| `ldapsend.pas` | 001.007.005 | ~1000+ linhas | Extensões maiores: GSSAPI+CBT, controles AD, LDAP Signing, FileTime utils, V1.7.0/V1.7.1/V1.7.2 |
| `jedi.inc` | — | ~4350 linhas | Reescrita completa (base de defines de compilador; diverge de upstream) |
| `blcksock.pas` | 009.011.001 | ~140 linhas | LDAPS tweaks + `GetPeerCertSHA256Hash` para CBT RFC 5929 |
| `synautil.pas` | 004.016.003 | ~70 linhas | Utils helpers |
| `synafpc.pas` | — | ~24 linhas | FPC compat tweaks |
| `ssl_openssl.pas` | 001.004.001 | ~25 linhas | Minor (baseline igual upstream v41) |
| `synacode.pas` | 002.002.003 | ~4 linhas | Whitespace/EOL |
| `synaip.pas` | — | ~4 linhas | Whitespace/EOL |

**Backups inactivos** (`ssl_openssl_lib.pas.bak`, `synsock.pas.bak` têm conteúdo idêntico ao actual — cópia preventiva sem modificação real).

### Fork 2026-04-21 (sessão V1.7.0) — 3 novas units + packages

| Item | Tipo | Propósito |
| --- | --- | --- |
| `ssl_openssl4.pas` | Unit nova | SSL plugin para OpenSSL 4.0 (classe `TSSLOpenSSL4`, fork mecânico de `ssl_openssl3.pas`) |
| `ssl_openssl4_lib.pas` | Unit nova | Imports para `libcrypto-4*` / `libssl-4*` (8 DLL names renomeados; signatures Pascal inalteradas — API unificada 3.x+4.0) |
| `ssl_openssl_paths.pas` | Unit nova | `TOpenSSLPaths.{Apply,Resolve,SetCustomPath}` para `SetDllDirectory` (Windows) |
| `synapse.dpk` | Package novo | Runtime Delphi 12/13 (40 units), simétrico ao `laz_synapse.lpk` |
| `laz_synapse.lpk` | Package actualizado | 41.0 → 41.1 (35 → 42 files com as 3 novas + 4 SSL legacy) |

### Fork 2026-04-22 (sessão V1.7.1) — tipagem automática de atributos LDAP em `ldapsend.pas`

`ldapsend.pas` bumped **001.007.003 → 001.007.004** com API nova para tipagem automática de atributos LDAP e fix cirúrgico do `EEncodingError 'No mapping for the Unicode character...'` em `TLDAPAttribute.Put`. **API pública preservada** — consumidores existentes recebem strings já formatadas sem alteração de código.

Acréscimos: enum `TLDAPValueType`, mapa `LDAP_KNOWN_ATTRIBUTE_TYPES`, função `ResolveLDAPValueType`, record `TLDAPAttributeValue`, properties `ValueType`/`Value`/`Values[Index]` em `TLDAPAttribute`, campo privado `FRawValues`, helpers file-private (`UnicodeToRawAnsi`, `SafeUtf8Decode`, `RawToSid`, `RawBytesToGuid`, `RawToGuidString`, `RawToFileTime`, `RawToGeneralizedTime`, `RawToHex`). Detalhes e exemplos em [API CSL-only](#api-csl-only--classe-por-classe).

**Backup:** `bak/ldapsend.20260421_2335.bak` (81 696 bytes — baseline 001.007.003).

### Fork 2026-04-22 (sessão V1.7.2) — `AddRaw` preservando 100% bytes binários em `ldapsend.pas`

`ldapsend.pas` bumped **001.007.004 → 001.007.005** com método público novo `TLDAPAttribute.AddRaw(const ARaw: AnsiString): Integer` que bypassa toda a conversão e armazena bytes directamente em `FRawValues`. Parser ASN.1 modificado em 2 callsites (`TLDAPSend.Search` ~linha 2157 e `TLDAPSend.DoSearchAD` ~linha 2330): `a.Add(u)` substituído por `a.AddRaw(u)`.

Complementos defensivos: `Put` salta `UnquoteStr` para tipos binários, `Get` blindado com `try/except` duplo + fallback `RawToHex`, `Clear` override, `RawToFileTime`/`RawToGeneralizedTime` usam `SafeUtf8Decode`, nova flag `;binary` em `Put`.

**Validação real:** AD `cslsolucoes.com.br`, `CN=Administrador,...`: `objectGUID={E22791BE-5255-4665-951F-4A630F4AE269}` (16 bytes completos) em vez de `BE1827E2555265461F4A630F4AE269` (15 bytes truncados pelo bug pré-fix). 33/33 atributos do Administrador listados sem perda.

**Backups:**

- `bak/ldapsend.20260422_0124.bak` (estado intermediário V1.7.1.1 antes do `AddRaw`)
- `bak/ldapsend.20260422_0057.bak` (V1.7.1 antes dos defensive fixes)

### Apenas no upstream (não trazidos)

| Ficheiro | Motivo de não trazer |
| --- | --- |
| `ssl_schannel.pas` | Windows Schannel (CryptoAPI nativo, sem OpenSSL). Alternativa interessante mas fora do escopo — o projecto usa OpenSSL. |
| `ssl_schannel_lib.pas` | Idem. |

### Gap de versão vs upstream (evolução upstream desde o fork)

Ficheiros onde o upstream ficou à frente da cópia CSL após as modificações históricas. **Merge não é trivial** (CSL tem modificações em cima do baseline antigo). Considerar em sprint dedicado:

| Ficheiro | Actual (CSL) | Upstream v41 |
| --- | --- | --- |
| `blcksock.pas` | 009.011.001 | 009.012.000 |
| `pingsend.pas` | 004.000.004 | 004.000.005 |
| `ssl_openssl11.pas` | 002.000.001 | 002.000.002 |
| `ssl_openssl11_lib.pas` | 004.000.001 | 004.000.002 |
| `ssl_openssl3.pas` | 001.000.001 | 001.001.000 |
| `ssl_openssl3_lib.pas` | 001.000.002 | 001.000.003 |
| `synacode.pas` | 002.002.003 | 002.002.004 |
| `synamisc.pas` | 001.004.000 | 001.004.001 |
| `imapsend.pas`, `pop3send.pas` | — | divergência sem bump |

---

## Documentação e análise

- [Documentation/README.md](Documentation/README.md) — hub de documentação CSL das units principais (LDAPSend, TCPBlockSocket, SSLOpenSSL).
- [Documentation/LDAPSend.md](Documentation/LDAPSend.md) — análise da classe `TLDAPSend`.
- [Documentation/TCPBlockSocket.md](Documentation/TCPBlockSocket.md) — análise do `TTCPBlockSocket`.
- [Documentation/SSLOpenSSL.md](Documentation/SSLOpenSSL.md) — análise da família `TSSLOpenSSL*` (1, 11, 3, 4).
- [Documentation/FLOWCHART.md](Documentation/FLOWCHART.md) — diagrama de autenticação LDAPS.
- [Documentation/Analise/](Documentation/Analise/) — análise exaustiva por unit/classe (49 docs, padrão de 7 secções: O que é, Características, Engine, Funcionalidades, Aplicabilidades, Exemplos de uso, Relacionamentos).
- [VERSION.md](VERSION.md) — política de versionamento + inventário de 50 units + changelog consolidado.

---

## Licença

- **Upstream Synapse:** BSD style — ver cabeçalho de cada `.pas`.
- **Fork CSL 2026-04-21** (`ssl_openssl4*`, `ssl_openssl_paths`, `synapse.dpk`): ver cabeçalho de cada ficheiro. Portions created by CSL Softwares Copyright (c)2026.
- **Fork CSL 2026-04-30** (V41.4 — leitor PFX X509 + tropicalização ICP-Brasil DOC-ICP-04): ver cabeçalho de cada ficheiro. Portions created by CSL Tech Solutions Copyright (c)2026.
- **Fork CSL 2026-05-01** (V41.5 — S8 quick wins ICP-Brasil): mesmas 7 units bumped 001.000.000 → 001.001.000. Portions created by CSL Tech Solutions Copyright (c)2026.
- **Fork CSL 2026-05-01** (V41.6 — S9 chain validation + Certificate Policies): 2 novas units (`ssl_openssl_chain_verify.pas`, `ssl_openssl_icpbrasil_policy.pas`) + bumps 001.001.000 → 001.002.000 em `ssl_openssl_icpbrasil.pas` e `ssl_openssl_icpbrasil_types.pas`. Bundle script `bundles/AC-Raiz-ICP-Brasil-fetch.ps1`. Portions created by CSL Tech Solutions Copyright (c)2026.
- **Fork CSL 2026-05-01** (V41.7 — S10 revogação CRL+OCSP+AIA+CDP): 3 novas units (`ssl_openssl_icpbrasil_crl.pas`, `ssl_openssl_icpbrasil_ocsp.pas`, `ssl_openssl_icpbrasil_extparsers.pas`) + bumps 001.001.000 → 001.002.000 em `ssl_openssl_chain_verify.pas`. Portions created by CSL Tech Solutions Copyright (c)2026.
- **Fork CSL 2026-05-01** (V41.8 — S11 SAN/KU/EKU/OAB): 1 nova unit (`ssl_openssl_icpbrasil_san.pas`). Portions created by CSL Tech Solutions Copyright (c)2026.
- **Fork CSL 2026-05-01** (V41.9 — S12 PKCS#7/CAdES + RFC 3161 TSP): 2 novas units (`ssl_openssl_icpbrasil_pkcs7.pas`, `ssl_openssl_icpbrasil_tsp.pas`). Portions created by CSL Tech Solutions Copyright (c)2026.
- **Fork CSL 2026-05-01** (V42.0 — S13a Windows Store + S13b PKCS#11): 2 novas units (`ssl_openssl_icpbrasil_winstore.pas`, `ssl_openssl_icpbrasil_pkcs11.pas`). `IsCertificadoEmHardware` adapta `ACBrDFeWinCrypt.GetCertIsHardware` (ACBr LGPL v2.1) — atribuição no header. Portions created by CSL Tech Solutions Copyright (c)2026.
- **Fork CSL 2026-05-01** (V42.1 — S14 fiscal helpers): 1 nova unit (`ssl_openssl_icpbrasil_fiscal.pas`) + cross-platform fixes em 6 units. Portions created by CSL Tech Solutions Copyright (c)2026.

Para integrações com RESTRequest4Delphi (`RR4D_SYNAPSE`) ver documentação GestorERP externa.
