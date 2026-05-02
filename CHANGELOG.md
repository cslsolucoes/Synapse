# Changelog - Ararat Synapse (fork CSL)

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versionamento: ver `VERSION.md`.

## [Unreleased] - 2026-05-02

### Changed

- **chore(headers): unificacao do rotulo `Ararat Synapse (CSL fork)` em todas as 17 units CSL ICP-Brasil** + companion `ssl_openssl_x509_ext` — alinhado com `ssl_openssl_paths.pas` e `ssl_openssl4.pas` (referencia canonica). Antes, units 100% CSL (de S1 a S14) estavam rotuladas como `Ararat Synapse` (rotulo upstream Gebauer), o que era incorreto.
  Arquivos: `ssl_openssl_x509_ext.pas`, `ssl_openssl_icpbrasil.pas`, `_oids.pas`, `_othername.pas`, `_subject.pas`, `_types.pas`, `ssl_openssl_chain_verify.pas`, `_icpbrasil_policy.pas`, `_icpbrasil_crl.pas`, `_ocsp.pas`, `_extparsers.pas`, `_san.pas`, `_pkcs7.pas`, `_tsp.pas`, `_winstore.pas`, `_pkcs11.pas`, `_fiscal.pas`.
- **bump retroativo `ssl_openssl_x509_ext.pas` `001.001.000` → `001.005.000`** com History CSL completo documentando contribuicoes:
  S1 (`001.000.000`) — companion baseline cross-platform.
  S8 (`001.001.000`) — Issuer.O=, Serial, Thumbprint SHA1/256, DERBase64.
  S9 (`001.002.000`) — bindings `X509_STORE_*`, `X509_verify_cert`.
  S10 (`001.003.000`) — bindings CRL + OCSP.
  S12 (`001.004.000`) — bindings PKCS7/CMS + RFC 3161 TSP.
  S13/14 (`001.005.000`) — refinamentos para WinStore + PKCS11.

### Documentation

- **VERSION.md** secao Inventario expandida com **17 units ICP-Brasil** listadas individualmente (versoes + sprint + papel); contagem de units actualizada para `67 Pascal + 5 include + 2 packages` (50 upstream/CSL-patched + 17 CSL ICP-Brasil).
- **VERSION.md** secao Roadmap reorganizada em "Entregue" (V41.4 → V42.1, todas as 7 sprints S8-S14) + "Futuro nao agendado" (V42.2/V42.3/V43.0 + PR upstream ACBr opcional) + "Roadmap historico" (V41.0-V41.3 pre-S8).
- **VERSION.md** Packages count corrigido: `60 files (35 upstream + 25 CSL)` → `57 units (.pas) + 2 includes` (alinhado com contagem real).
- **VERSION.md** data Generated `2026-04-22` → `2026-05-02`; scope path actualizado para `src/modules/Synapse/`.

### Verificacao

- Build dcc64 Delphi 12 (23.0): 58.743 linhas, 0 erros (so warnings expectados — `W1035` em wrappers `GetProcAddress`).
- Suite DUnitX: 38/38 testes verdes, 0 leaks.
- Pacotes `laz_synapse.lpk` ↔ `synapse.dpk` simetricos sem alteracao (57 .pas em ambos).

## [42.1] - 2026-05-01

### Added

- **S14 — Fiscal helpers (NFe/eSocial/Serpro/Sefaz/EFD-Reinf):**
  - `ssl_openssl_icpbrasil_fiscal.pas` (NEW, 001.000.000) — funcoes
    `IsCertificadoNFe`, `IsCertificadoESocial`, `IsCertificadoSerpro`,
    `IsCertificadoSefaz(AUf)`, `IsCertificadoEFDReinf`, `HasExtKeyUsage`.
    Combinam `Tipo`/`DocumentoValido`/`EstaValido`/`ExtKeyUsageOids` +
    match heuristico em `Certificadora`/`Issuer`.
- Tags Synapse.Version.inc: `SYNAPSE_V42_1_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S14`.

### Fixed

- Cross-platform compatibility (FPC Windows): `{$IFDEF FPC}DynLibs.GetProcAddress`
  substituido por `{$IFDEF MSWINDOWS}Windows.GetProcAddress` em
  `ssl_openssl_chain_verify.pas`, `ssl_openssl_x509_ext.pas`,
  `ssl_openssl_icpbrasil_crl.pas`, `ssl_openssl_icpbrasil_ocsp.pas`,
  `ssl_openssl_icpbrasil_pkcs7.pas`, `ssl_openssl_icpbrasil_pkcs11.pas` —
  alinha com uses clause (FPC Windows tem `Windows`, nao `DynLibs`).
- `ssl_openssl_paths.pas` (pre-existente): `SetDllDirectoryW` declarado
  externamente para FPC (RTL Windows pode nao expor o alias).
- `laz_synapse.lpk` `Files Count="59"` corrigido para `60` (alinhado com
  itens reais).

### Changed

- `synapse.dpk` 42.0 → 42.1, `laz_synapse.lpk` 42.0 → 42.1 (58 → 60 files).

## [42.0] - 2026-05-01

### Added

- **S13a — Windows Certificate Store + A3 detection:**
  - `ssl_openssl_icpbrasil_winstore.pas` (NEW, 001.000.000, Windows-only) —
    `TWinCertStore` com `OpenStore` (slMy/slCurrentUser/slLocalMachine),
    `EnumerateCertificates`, `FindByThumbprint`. Bindings auto-contidos
    para Crypt32.dll (`CertOpenStore`, `CertEnumCertificatesInStore`,
    `CertGetCertificateContextProperty`).
  - Funcao publica `IsCertificadoEmHardware(DerBytes): Boolean` adapta
    `ACBrDFeWinCrypt.GetCertIsHardware` (LGPL v2.1) para detectar A3 via
    `CRYPT_IMPL_HARDWARE` flag (CSP) ou `NCRYPT_IMPL_HARDWARE_FLAG` (CNG).
- **S13b — PKCS#11 (Cryptoki v3) cross-platform:**
  - `ssl_openssl_icpbrasil_pkcs11.pas` (NEW, 001.000.000) — `TPkcs11Loader`
    cross-platform com:
    - Tipos PKCS#11 standalone (CK_BYTE, CK_ULONG, CK_SLOT_ID,
      CK_SESSION_HANDLE, CK_OBJECT_HANDLE, CK_FUNCTION_LIST, CK_ATTRIBUTE)
    - `LoadModule(APath)` + `AutoDetectAndLoad` com paths conhecidos
      (SoftHSM2, eToken, SafeNet em Linux/Windows/macOS)
    - `EnumerateSlots(AOnlyWithToken)` — info de slot + token
    - `OpenSession(ASlotId, APin)` com login CKU_USER
    - `EnumerateCertificates` — extracao de DerBytes/Label/Subject/ID via
      `C_FindObjectsInit`/`C_FindObjects`/`C_GetAttributeValue`
- Tags Synapse.Version.inc: `SYNAPSE_V42_0_OR_HIGHER`, `SYNAPSE_MAJOR_42`,
  `SYNAPSE_V42_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S13A`,
  `SYNAPSE_CSL_ICPBR_S13B`.

### Notes

- **A3 cross-platform:** Synapse v42.0 e a **unica biblioteca Pascal**
  com PKCS#11 portatil (Linux/macOS/Windows). ACBr so suporta A3 no
  Windows via WinCrypt.
- **Atribuicao LGPL:** `IsCertificadoEmHardware` deriva de ACBr LGPL v2.1.
  Headers das units S13a documentam atribuicao explicita.

### Changed

- `synapse.dpk` 41.9 → 42.0, `laz_synapse.lpk` 41.9 → 42.0 (56 → 58 files).
- `Synapse.Version.inc` MAJOR bumped 41.x → 42.x.

## [41.9] - 2026-05-01

### Added

- **S12 — PKCS#7/CAdES-BES signing nativo:**
  - `ssl_openssl_icpbrasil_pkcs7.pas` (NEW, 001.000.000) — `TPkcs7Signer`
    com bindings auto-contidos para `PKCS7_sign`, `PKCS7_verify`,
    `i2d_PKCS7`, `d2i_PKCS7`. Modos `psBinarioCMS`, `psDetached` (default
    NFe), `psAttached`, `psBase64`. `AssinarBytes(ABytes, ACert, AKey,
    AMode): TPkcs7SignResult` produz CAdES-BES.
- **S12 — RFC 3161 Time-Stamp Protocol client:**
  - `ssl_openssl_icpbrasil_tsp.pas` (NEW, 001.000.000) — `TTspClient`
    constroi TimeStampReq DER manualmente (SHA-256 hash + nonce randomico
    8 bytes), envia POST `application/timestamp-query` via Synapse
    `httpsend`, retorna `TimestampToken` (DER bytes). Sem dependencia de
    OpenSSL TS_REQ helpers.
- Tags Synapse.Version.inc: `SYNAPSE_V41_9_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S12`.

### Notes

- **Synapse standalone para emissao fiscal:** com PKCS#7 + TSP, deixa de
  precisar de XmlSec/MSXML para gerar CAdES-T (padrao NFe + eSocial).
- **CAdES-T:** anexar timestamp como counter-signature na PKCS#7
  signature (caller responsavel; Synapse fornece os blocos).

### Changed

- `synapse.dpk` 41.8 → 41.9, `laz_synapse.lpk` 41.8 → 41.9 (54 → 56 files).

## [41.8] - 2026-05-01

### Added

- **S11 — Subject enrichment (SAN/KU/EKU/OAB):**
  - `ssl_openssl_icpbrasil_san.pas` (NEW, 001.000.000) — Parsers para:
    - **SubjectAlternativeName** (`2.5.29.17`): rfc822Name (email),
      dNSName, iPAddress (IPv4 + IPv6), uniformResourceIdentifier (URI).
      Implementa GeneralName CHOICE [0..8].
    - **KeyUsage** (`2.5.29.15`): bitmask `digitalSignature`,
      `nonRepudiation`, `keyEncipherment`, `dataEncipherment`,
      `keyAgreement`, `keyCertSign`, `cRLSign`, `encipherOnly`,
      `decipherOnly`.
    - **ExtendedKeyUsage** (`2.5.29.37`): array de OIDs com nomes
      humano-legiveis (`clientAuth`, `serverAuth`, `codeSigning`,
      `emailProtection`, `timeStamping`, `OCSPSigning`, `smartCardLogon`).
    - **OAB digital** (OID `2.16.76.1.3.10`): heuristica de extracao
      de numero OAB + UF.
  - Helper `KeyUsageToString` e dictionary `EkuOidName`.
- 8 novos campos no record `TIcpBrasilCertificado`: `DnsNames`,
  `IpAddresses`, `Uris`, `SanEmails`, `KeyUsageEncontrada`/`KeyUsageStr`,
  `ExtKeyUsageOids`/`ExtKeyUsageNames`, `OabNumero`/`OabUf`.
- Tags Synapse.Version.inc: `SYNAPSE_V41_8_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S11`.

### Changed

- `ssl_openssl_icpbrasil_types.pas` 001.003.000 → 001.004.000.
- `ssl_openssl_icpbrasil.pas` 001.003.000 → 001.004.000 — chamada
  automatica de `ColherEnriquecimentoSubject` em `LerDoPfx` (custo baixo).
- `synapse.dpk` 41.7 → 41.8, `laz_synapse.lpk` 41.7 → 41.8 (53 → 54 files).

### Notes

- DOC-ICP-04 v8.x (vigente 2024+) cobertura completa de campos.

## [41.7] - 2026-05-01

### Added

- **S10 — Revogacao programatica (CRL + OCSP + AIA + CDP):**
  - `ssl_openssl_icpbrasil_crl.pas` (NEW, 001.000.000) — `TIcpBrasilCrlClient`
    com cache em filesystem (TTL respeitando `nextUpdate`), download via
    `httpsend`. Metodos `LoadFromFile`, `LoadFromUrl`, `IsRevogado`,
    `VerifySignature`. Cross-platform.
  - `ssl_openssl_icpbrasil_ocsp.pas` (NEW, 001.000.000) — `TIcpBrasilOcspClient`
    com bindings auto-contidos (`OCSP_REQUEST_*`, `OCSP_RESPONSE_*`,
    `OCSP_basic_verify`, `OCSP_resp_find_status`). Constroi request, envia
    POST `application/ocsp-request` via httpsend, valida status
    (`ocspGood`/`ocspRevoked`/`ocspUnknown`/`ocspError`).
  - `ssl_openssl_icpbrasil_extparsers.pas` (NEW, 001.000.000) — Parsers
    para extensao `1.3.6.1.5.5.7.1.1` (AIA: caIssuers + OCSP responder
    URLs) e `2.5.29.31` (CRL Distribution Points). Heuristica de extracao
    de URLs no buffer ASN.1 raw.
- 9 novos campos no record para revogacao: `RevogacaoVerificada`,
  `Revogado`, `RevogacaoMotivo`, `RevogacaoData`, `RevogacaoFonte`,
  `RevogacaoTimestamp` + arrays `OcspUrls`, `CaIssuersUrls`, `CrlUrls`.
- Novo enum `TRevogacaoMode`: `rmNone`/`rmCRL`/`rmOCSP`/`rmOCSPThenCRL`/
  `rmCRLThenOCSP`.
- `TLerDoPfxOptions` ganha campos `VerificarRevogacao`, `CrlCacheDir`,
  `OcspTimeoutMs`.
- Tags Synapse.Version.inc: `SYNAPSE_V41_7_OR_HIGHER`,
  `SYNAPSE_CSL_ICPBR_S10`, `SYNAPSE_X509_CRL_BINDINGS`,
  `SYNAPSE_ICPBR_OCSP_CLIENT`, `SYNAPSE_ICPBR_CRL_CLIENT`,
  `SYNAPSE_ICPBR_AIA_CDP_PARSER`, `SYNAPSE_ICPBR_REVOCATION_MODE`.

### Changed

- `ssl_openssl_chain_verify.pas` 001.000.000 → 001.001.000 — bindings CRL
  adicionados (`d2i_X509_CRL`, `X509_CRL_verify`, `X509_CRL_get0_*`,
  `X509_REVOKED_get0_*`); class methods `LoadCrlFromBytes`,
  `LoadCrlFromPEM`, `FreeCrl`, `VerifyCrlSignature`, `IsRevogadoNaCRL`.
- `ssl_openssl_icpbrasil_types.pas` 001.002.000 → 001.003.000.
- `ssl_openssl_icpbrasil.pas` 001.002.000 → 001.003.000 — helpers
  internos `ColherUrlsAIAeCDP` (sempre) e `VerificarRevogacaoSeRequisitado`
  (opcional).
- `synapse.dpk` 41.6 → 41.7, `laz_synapse.lpk` 41.6 → 41.7 (50 → 53 files).

### Notes

- **Limitacao:** OCSP integrado a `LerDoPfx` exige cert do issuer carregado
  para construir request — em S10 isto ainda nao e automatico, fluxo OCSP
  retorna sem-acao se issuer ausente. Caller pode usar `TIcpBrasilOcspClient`
  directamente quando tiver issuer carregado. CRL via CDP funciona stand-alone.

## [41.6] - 2026-05-01

### Added

- **S9 — Validacao de cadeia X509 offline (sem depender do TLS handshake):**
  - `ssl_openssl_chain_verify.pas` (NEW, 001.000.000) — `TX509ChainVerifier`
    com bindings auto-contidos: `X509_STORE_new`, `X509_STORE_free`,
    `X509_STORE_add_cert`, `X509_STORE_CTX_new`, `X509_STORE_CTX_init`,
    `X509_STORE_CTX_free`, `X509_STORE_CTX_get_error`,
    `X509_STORE_CTX_get_error_depth`, `X509_verify_cert`,
    `X509_verify_cert_error_string`, `PEM_read_bio_X509`. API:
    `LoadStoreFromPEM`, `LoadStoreFromCertList`, `AddTrustedCert`, `Verify`.
  - Cross-platform via `DynLibs IFDEF` (Windows + FPC Linux/macOS).
  - Reusa `TX509Ext.Init` para coordenar com o restante do leitor.
- **S9 — Parser de Certificate Policies:**
  - `ssl_openssl_icpbrasil_policy.pas` (NEW, 001.000.000) — usa
    `asn1util.ASNItem` para decodificar a extensao X509 `2.5.29.32`
    (Certificate Policies, RFC 5280 §4.2.1.4). Funcao publica
    `ParseCertificatePolicies`; helper `IsIcpBrasilPolicyOid` que
    classifica OIDs ITI prefix `2.16.76.1.2.*` por versao de AC-Raiz
    (V1..V10). Reconhece DOC-ICP-04 v8.x (vigente 2024+).
- **S9 — Integracao em `LerDoPfx`:**
  - Novo overload `LerDoPfx(bytes, senha, options): TIcpBrasilCertificado`
    onde `TLerDoPfxOptions` permite habilitar `VerificarChain`,
    `AcRaizBundlePath` (default `bundles/ac-raiz-icp-brasil.pem`) e
    `VerificarPolicy`. Overload sem options preservado para
    compatibilidade V41.5.
  - 9 novos campos no record `TIcpBrasilCertificado` (populados
    apenas com options=True): `ChainVerificado`, `ChainValido`,
    `ChainErro`, `ChainErroCodigo`, `ChainProfundidade`,
    `PolicyVerificada`, `PolicyOids`, `PolicyValida`,
    `AcRaizDetectada`, `AcRaizVersao`.
- **S9 — Bundle AC-Raiz:**
  - `bundles/AC-Raiz-ICP-Brasil-fetch.ps1` (NEW) — script PowerShell
    que baixa AC-Raiz v1..v10 do ITI (estrutura.iti.gov.br) e
    converte DER→PEM, gerando `bundles/ac-raiz-icp-brasil.pem`.
  - `bundles/README.md` (NEW) — documentacao de uso e refresh policy.
  - `docs-extra/ac-raiz-bundle.md` (NEW) — guia de uso da camada de
    chain validation, codigos de erro X509_V_ERR_*, AC-Raiz
    reconhecidas, troubleshooting.
- **Tags `Synapse.Version.inc`:** `SYNAPSE_V41_6_OR_HIGHER`,
  `SYNAPSE_CSL_ICPBR_S9`, `SYNAPSE_X509_CHAIN_VERIFY`,
  `SYNAPSE_ICPBR_POLICY_PARSER`, `SYNAPSE_ICPBR_LER_DO_PFX_OPT`,
  `SYNAPSE_ICPBR_AC_RAIZ_BUNDLE`.

### Changed

- `ssl_openssl_icpbrasil_types.pas` 001.001.000 → **001.002.000** —
  record com 9 novos campos para chain/policy + nova `TLerDoPfxOptions`.
- `ssl_openssl_icpbrasil.pas` 001.001.000 → **001.002.000** —
  novo overload `LerDoPfx` com options; helpers internos
  `VerificarChainSeRequisitado` e `VerificarPolicySeRequisitado`.
- `synapse.dpk` 41.5 → 41.6, lista 2 units novas.
- `laz_synapse.lpk` 41.5 → 41.6, files count 48 → 50.
- `.gitignore` — `ac-raiz-icp-brasil*.pem` (gerado pelo script).

### Notes

- Compatibilidade preservada: o overload `LerDoPfx(bytes, senha)`
  (sem options) mantem o comportamento V41.5 byte-a-byte. Codigo
  V41.5 continua a funcionar sem recompilar.
- **Validacao em V41.6 e opt-in.** Bundle AC-Raiz deve ser baixado
  pelo consumidor (rodar `bundles/AC-Raiz-ICP-Brasil-fetch.ps1`)
  antes de usar `VerificarChain=True`.
- Bindings X509_STORE/STORE_CTX/verify_cert sao **adicionados em unit
  nova** (`ssl_openssl_chain_verify.pas`), preservando upstream
  `ssl_openssl3_lib.pas` e `ssl_openssl4_lib.pas` sem patches.
- CRL e OCSP **ainda nao implementados** (agendados para S10/V41.7).
  V41.6 valida cadeia mas nao verifica revogacao.

## [41.5] - 2026-05-01

### Added

- ICP-Brasil S8 quick wins (driver: avaliacao comparativa contra ACBr):
  - `OID_ICPBR_E_CNPJ_LEGACY` (`2.16.76.1.3.3`) e `OID_ICPBR_PJ_NOME_LEGACY` (`2.16.76.1.3.2`) - OIDs
    DOC-ICP-04 pre-v3 (compat e-CNPJ A1 antigos ainda em circulacao).
  - `OID_ICPBR_OAB` (`2.16.76.1.3.10`) - OAB digital (parser pendente em S11).
  - `TIcpBrasilCertificado` expandido com 11 novos campos: `Certificadora` (Issuer.O=),
    `NumeroSerie`, `NumeroSerieHex`, `ThumbPrintSHA1`, `ThumbPrintSHA256`, `DERBase64`,
    `Versao`, `TituloEleitor` (OID `.5`), `PisOuCaepf` (OID `.6` - PIS legacy /
    CAEPF/CEI), `RgSeparado` (OID `.8`).
  - Helper de record `TIcpBrasilCertificadoHelper`: `EstaValidoEm(AData)`, `EstaValido`,
    `DiasParaExpirar`.
  - Parsers ASN.1: `ParseTituloEleitor`, `ParsePisOuCaepf`, `ParseRgSeparado`.
  - Helpers fiscais em `ssl_openssl_icpbrasil_subject.pas`: `MatchCnpjRaiz` (8 digitos -
    permite filiais usarem cert da matriz, padrao NFe/eSocial).
- `ssl_openssl_x509_ext.pas` ganhou helpers cross-platform:
  - `X509GetSubjectO` / `X509GetIssuerO` (NID_organizationName=17).
  - `X509GetSerialNumberDec` / `X509GetSerialNumberHex` (via `ASN1_INTEGER_to_BN` +
    `BN_bn2dec`/`BN_bn2hex`).
  - `X509GetThumbprintSHA1` / `X509GetThumbprintSHA256` (via `X509_digest` + `EVP_sha1`/`EVP_sha256`).
  - `X509GetDERBytes` / `X509GetDERBase64` (via `i2d_X509` + `synacode.EncodeBase64`).
  - `X509GetVersion` (X509_get_version retorna long; tratado via NativeInt para
    compatibilidade Windows LLP64 + Linux LP64).
- Tags `Synapse.Version.inc`: `SYNAPSE_V41_5_OR_HIGHER`, `SYNAPSE_V41_4_OR_HIGHER`,
  `SYNAPSE_CSL_ICPBR_S8`, `SYNAPSE_CSL_ICPBR_S1_S6`, `SYNAPSE_ICPBR_OID_3_FALLBACK`,
  `SYNAPSE_ICPBR_RICH_RECORD`, `SYNAPSE_ICPBR_FISCAL_HELPERS`,
  `SYNAPSE_X509_HELPERS_THUMBPRINT`, `SYNAPSE_ICPBR_PFX_READER`,
  `SYNAPSE_X509_EXT_HELPERS`.

### Changed

- `ClassificarPorExtensoes` em `ssl_openssl_icpbrasil.pas`: tenta OID `.7`
  (DOC-ICP-04 v3+) primeiro, depois fallback para OID `.3` (legacy). Antes ignorava
  certificados que populavam apenas `.3`.
- `LerDoPfx` popula automaticamente os 6 novos campos X509 (Certificadora, NumeroSerie,
  Thumbprints, DERBase64, Versao) sem custo adicional.
- `synapse.dpk` / `laz_synapse.lpk` bumped 41.4 -> 41.5.
- `VERSION.md` bumped 41.4 -> 41.5.

### Notes

- Zero novas units, zero alteracoes em `ssl_openssl{3,4}_lib.pas`. Apenas adicoes em
  `ssl_openssl_x509_ext` (CSL fork) e nas 5 units ICP-Brasil (CSL fork).
- Compatibilidade binaria preservada (campos novos no fim do record).
- Cross-platform: novos GetProcAddress fazem fallback gracioso (nil) se simbolos
  ausentes na libcrypto carregada.

## [41.4] - 2026-04-30

### Added

- `ssl_openssl_x509_ext.pas` - cross-platform X509 PFX companion unit
  (Windows + FPC Linux + macOS via DynLibs IFDEF).
  - `TX509Ext.X509GetNotBefore` / `X509GetNotAfter` (ASN1_TIME accessors)
  - `TX509Ext.X509ASN1TimeToDateTimeUTC` (ASN1_TIME -> TDateTime UTC)
  - `TX509Ext.X509GetSubjectCN` / `X509GetIssuerCN` (NID_commonName helpers)
  - `TX509Ext.X509GetAllExtensions: TX509ExtensionArray`
  - `TX509Ext.PKCS12ReadFromBytes` (managed PFX wrapper)
  - Self-loads libcrypto-3 in own handle (no modification of `ssl_openssl3_lib.pas`).
- ICP-Brasil DOC-ICP-04 tropicalization (5 units):
  - `ssl_openssl_icpbrasil_oids.pas` - OID constants (functions, due to `WRITEABLECONST OFF`).
  - `ssl_openssl_icpbrasil_types.pas` - `TIcpBrasilCertificado` record + 3 exceptions.
  - `ssl_openssl_icpbrasil_subject.pas` - Subject CN parser + CNPJ/CPF mod-11 validators.
  - `ssl_openssl_icpbrasil_othername.pas` - ASN.1 OtherName parsers.
  - `ssl_openssl_icpbrasil.pas` - public reader `TIcpBrasilCertificadoReader.LerDoPfx`.
- `tests-extra/` - DUnitX suite (38 tests, 100% synthetic vectors).

### Changed

- `synapse.dpk` lists 6 new units; description bumped to v41.4.
- `laz_synapse.lpk` lists 6 new units (Files Count 42 -> 48).
- `VERSION.md` bumped 41.3 -> 41.4.

### Notes

- Zero modification of existing `ssl_openssl{3,4}_lib.pas` files.
  Mitigates upstream rebase risk - all v41.4 extensions in new files.
- Cross-platform via `{$IFDEF MSWINDOWS} ... {$ELSE FPC DynLibs} ... {$ENDIF}`.
- DOC-ICP-04 reference: <https://www.gov.br/iti/pt-br>.
- Fork extensions in v41.4 contributed by CSL Tech Solutions.

## [41.3] - 2026-04-22

### Changed

- AddRaw method preserves 100% binary bytes when writing LDAP attributes.

## [41.2] - earlier

### Added

- Automatic LDAP attribute typing.

## [41.1] - earlier

### Added

- OpenSSL 4.0 support (`ssl_openssl4*.pas`).
- DLL path resolution helper (`ssl_openssl_paths.pas`).
- AD WS 2025 compatibility (LDAPS + CBT + tri-platform POSIX).

## [41.0] - 2023

### Initial

- Forked from Synapse upstream (copyright 1999-2023, Lukas Gebauer).
