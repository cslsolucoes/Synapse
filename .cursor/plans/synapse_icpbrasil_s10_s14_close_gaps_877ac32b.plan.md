# Plano de execução S10–S14 — Cobertura total das lacunas

> **Continuação** de [`fa-a-uma-avalia-o-do-glistening-rabbit.md`](fa-a-uma-avalia-o-do-glistening-rabbit.md) (Revisão 5).
> Detalha as 5 sprints restantes para zerar lacunas vs. ACBr e cobrir DOC-ICP-04 v8.x integralmente.

## 1. Estado de partida (v41.6, S8+S9 entregues)

**Synapse à frente do ACBr em 15 features** (chain validation programática offline, bundle AC-Raiz, parser PolicyIdentifier, 9 OIDs DOC-ICP-04 reconhecidos, etc.).

**3 lacunas pendentes** vs. ACBr (todas roadmapped):
- Detecção A1/A3 e Windows Store → S13
- PKCS#11 cross-platform → S13
- PKCS#7/CAdES signing nativo → S12

**Lacunas estruturais comuns** (nem ACBr nem Synapse cobrem hoje):
- CRL programmatic verify → S10
- OCSP client → S10
- AIA/CDP auto-fetch → S10
- SAN/KU/EKU parsing → S11
- OAB digital parser → S11
- Time-stamping RFC 3161 → S12
- Helpers fiscais NFe/eSocial/Serpro/Sefaz → S14

**Refactor adiado** de S9:
- StripASN1OctetWrapper → asn1util.ASNItem → bloco extra ou S10

---

## 2. Visão executiva — 5 sprints + bloco extra

| Sprint | Versão | Tema | Esforço | Lacunas fechadas |
|---|---|---|---|---|
| **S10** | v41.7 | Revogação (CRL + OCSP + AIA + CDP) + refactor ASN.1 | ~18h | 4 |
| **S11** | v41.8 | Subject enrichment (SAN/KU/EKU/OAB) + DOC-ICP-04 v8.x audit | ~10h | 4 |
| **S12** | v41.9 | PKCS#7/CAdES + RFC 3161 (signing fiscal nativo) | ~16h | 2 |
| **S13** | v42.0 | Hardware (PKCS#11 + Windows Store + A3) | ~30h | 3 |
| **S14** | v42.1 | Helpers fiscais + audit final + docs | ~6h | 1 |

**Total: ~80h** (≈10 dias/pessoa em fluxo contínuo).

---

## 3. Sprint S10 — V41.7 — Revogação programática + refactor ASN.1 (~18h)

> Lacuna estrutural ausente em ambos (Synapse e ACBr). Aqui o Synapse assume liderança no ecossistema Pascal.

### Tarefas

| # | Acção | Ficheiro(s) | Esforço |
|---|---|---|---|
| **C1** | **Bindings CRL** em `ssl_openssl_chain_verify.pas` (estende vez de criar nova): `d2i_X509_CRL`, `i2d_X509_CRL`, `X509_CRL_free`, `X509_CRL_get0_by_serial`, `X509_CRL_verify`, `X509_CRL_get_lastUpdate`/`get_nextUpdate`, `X509_REVOKED_get0_serialNumber`, `X509_REVOKED_get0_revocationDate`, `X509_REVOKED_get_reason` | [ssl_openssl_chain_verify.pas](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_chain_verify.pas) | 2h |
| **C2** | **Bindings OCSP** em nova `ssl_openssl_ocsp_lib.pas` (separado para isolamento): `OCSP_REQUEST_new`, `OCSP_request_add0_id`, `OCSP_REQUEST_add_ext`, `OCSP_REQUEST_free`, `i2d_OCSP_REQUEST`, `d2i_OCSP_RESPONSE`, `OCSP_response_status`, `OCSP_response_get1_basic`, `OCSP_basic_verify`, `OCSP_resp_find_status`, `OCSP_check_validity`, `OCSP_RESPONSE_free`, `OCSP_BASICRESP_free`, `OCSP_cert_to_id` | nova: `ssl_openssl_ocsp_lib.pas` (CSL) | 3h |
| **C3** | **Parsers AIA + CDP** em nova `ssl_openssl_icpbrasil_extparsers.pas`: usar `asn1util.ASNItem` para extrair URLs de `1.3.6.1.5.5.7.1.1` (AIA — caIssuers + OCSP) e `2.5.29.31` (CDP — distributionPoint URLs) | nova: `ssl_openssl_icpbrasil_extparsers.pas` (CSL) | 2h |
| **C4** | **Nova unit `ssl_openssl_icpbrasil_crl.pas` (CSL)** — `TIcpBrasilCrlClient` com cache em pasta configurável, TTL respeitando `nextUpdate`, métodos: `LoadFromFile(path)`, `LoadFromUrl(url, cacheDir)`, `IsRevogado(serial: string): TCrlCheckResult`. Usa Synapse `httpsend` para download. | nova: `ssl_openssl_icpbrasil_crl.pas` (CSL) | 3h |
| **C5** | **Nova unit `ssl_openssl_icpbrasil_ocsp.pas` (CSL)** — `TIcpBrasilOcspClient`: constrói request, envia POST via `httpsend`, parseia response, valida assinatura OCSP responder. Método: `CheckRevogacao(ACert, AIssuer): TOcspResult`. | nova: `ssl_openssl_icpbrasil_ocsp.pas` (CSL) | 3h |
| **C6** | **Refactor `StripASN1OctetWrapper` → `asn1util.ASNItem`** (bloco extra adiado de S9 — encaixa naturalmente aqui pois extparsers já depende de asn1util) | [ssl_openssl_icpbrasil_othername.pas:103-150](e:/Dropbox/GDoc/src/modules/Synapse/ssl_openssl_icpbrasil_othername.pas#L103) | 2h |
| **C7** | **Orquestração em `ssl_openssl_chain_verify.pas`** — método `VerifyComRevogacao(ACert; AIssuer; AModo): TVerifyResultExtended` onde `TRevogacaoMode = (rmNone, rmCRL, rmOCSP, rmOCSPThenCRL, rmCRLThenOCSP)`. AIA auto-fetch se issuer não no store. | ssl_openssl_chain_verify.pas | 1.5h |
| **C8** | **Integração em `LerDoPfx`** — adicionar `VerificarRevogacao: TRevogacaoMode` em `TLerDoPfxOptions`; popula campos novos no record | ssl_openssl_icpbrasil_types.pas, ssl_openssl_icpbrasil.pas | 30 min |
| **C9** | Tests + docs | `tests-extra/`, `docs-extra/revocation.md` (novo) | 1h |

### Novos campos no record (S10)

```pascal
RevogacaoVerificada:  Boolean;
Revogado:             Boolean;
RevogacaoMotivo:      string;     // 'keyCompromise' / 'unspecified' / etc.
RevogacaoData:        TDateTime;
RevogacaoFonte:       string;     // 'CRL: http://...' ou 'OCSP: http://...'
RevogacaoTimestamp:   TDateTime;  // when this check was performed
```

### Novas extensões em `TLerDoPfxOptions`

```pascal
VerificarRevogacao:   TRevogacaoMode;
CrlCacheDir:          string;     // '' = caches/crl/
OcspTimeout:          Integer;    // ms; 0 = 5000 default
```

### Resultado S10

Synapse passa a verificar revogação completa **offline** (cache CRL) e **online** (OCSP) sem depender do SO. ACBr continua sem isso.

---

## 4. Sprint S11 — V41.8 — Subject enrichment + DOC-ICP-04 v8.x compliance (~10h)

> Adiciona o que falta para conformidade com DOC-ICP-04 v8.x (vigente 2024+) e parsing rico do SAN.

### Tarefas

| # | Acção | Esforço |
|---|---|---|
| **D1** | **Parser `SubjectAlternativeName` completo** (ext `2.5.29.17`) — extrai e popula no record: `DnsNames: array of string`, `IpAddresses: array of string`, `Uris: array of string`, `Emails: array of string` (rfc822Name — popula campo `Email` existente também). Parser via `asn1util.ASNItem`. | 3h |
| **D2** | **Parser `Key Usage`** (ext `2.5.29.15`) — bitmask `digitalSignature` / `nonRepudiation` / `keyEncipherment` / `dataEncipherment` / `keyAgreement` / `keyCertSign` / `cRLSign` / `encipherOnly` / `decipherOnly`; popula `KeyUsage: set of TKeyUsageBit` | 1.5h |
| **D3** | **Parser `Extended Key Usage`** (ext `2.5.29.37`) — array de OIDs: `clientAuth` (`1.3.6.1.5.5.7.3.2`), `serverAuth`, `codeSigning`, `emailProtection`, `timeStamping`, `OCSPSigning`, e ICP-Brasil OIDs como SmartCardLogon (`1.3.6.1.4.1.311.20.2.2`); popula `ExtKeyUsage: array of string` + helper `IsForSigning`/`IsForAuth` | 1.5h |
| **D4** | **OAB digital (`2.16.76.1.3.10`)** — parser do número OAB + UF; campos `OabNumero` e `OabUf` no record. Detecta entidades: cert advogado, juiz, MP, etc. | 1h |
| **D5** | **CAEPF parser diferenciado para OID `.6`** — DOC-ICP-04 v6+ trocou PIS/PASEP (11 dígitos) por CAEPF (14 dígitos) ou CEI legacy (12 dígitos); detectar pela quantidade. Já parcial em S8 — agora distinguir e popular campos separados (`Pis`, `Caepf`, `Cei`). | 1h |
| **D6** | **OIDs DOC-ICP-04 v8.x (2024)** — verificar última versão do documento ITI; adicionar OIDs `2.16.76.1.3.11`, `.12`, `.13`, `.14`, `.15` se aplicáveis | 1h |
| **D7** | **Helper `ClassificacaoCertificado(ACert): TIcpBrasilClassificacao`** — enum `cicAplicacao`, `cicEquipamento`, `cicTituloEleitor`, `cicAtributo`, `cicOAB`, `cicSefaz` (DOC-ICP-04 reconhece subtipos via OIDs específicos) | 1h |
| **D8** | Tests + docs (`docs-extra/san-parsing.md`, `docs-extra/oab-digital.md`) | 1h |

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
Pis:            string;       // legacy (separado de PisOuCaepf agora)
Classificacao:  TIcpBrasilClassificacao;
```

### Resultado S11

Synapse cobre 100% dos campos DOC-ICP-04 v8.x. Detecta: e-CPF, e-CNPJ, equipamento, aplicação, título eleitor, OAB, atributos profissionais. ACBr cobre ~30%.

---

## 5. Sprint S12 — V41.9 — Assinatura PKCS#7/CAdES + Time-stamping (~16h)

> **Maior diferenciador final:** assinatura PKCS#7 nativa (NFe/eSocial usam isso) + RFC 3161 time-stamping. Permite Synapse ser **standalone** para emissão de documentos fiscais — sem dependência de XmlSec/MS.

### Tarefas

| # | Acção | Esforço |
|---|---|---|
| **E1** | **Bindings PKCS#7/CMS** em nova `ssl_openssl_pkcs7_lib.pas`: `PKCS7_new`, `PKCS7_free`, `PKCS7_sign`, `PKCS7_sign_add_signer`, `PKCS7_final`, `PKCS7_verify`, `PKCS7_get0_signers`, `i2d_PKCS7`, `d2i_PKCS7`, `BIO_new`, `BIO_write`, `CMS_sign`, `CMS_verify`, `CMS_add0_recipient_key` (CAdES via CMS — mais moderno). | 3h |
| **E2** | **Bindings RFC 3161** (Time-stamp Protocol) em nova `ssl_openssl_tsp_lib.pas`: `TS_REQ_new`, `TS_REQ_set_msg_imprint`, `TS_REQ_set_nonce`, `TS_REQ_set_cert_req`, `TS_REQ_free`, `i2d_TS_REQ`, `d2i_TS_RESP`, `TS_RESP_get_status_info`, `TS_RESP_get_token`, `TS_VERIFY_CTX_new`, `TS_RESP_verify_response`, `TS_RESP_free`. | 3h |
| **E3** | **Nova unit `ssl_openssl_pkcs7_signer.pas` (CSL)** — `TPkcs7Signer.AssinarBytes(ABytes; ACert; AKey; AModo): TBytes` onde `TPkcs7Mode = (psBinarioCAdES, psDetached, psAttached, psBinaryB64)`; suporta `AddAttribute(signingTime, contentType, messageDigest, signingCertificateV2)` per CAdES-BES. | 4h |
| **E4** | **Nova unit `ssl_openssl_tsp_client.pas` (CSL)** — `TTspClient.RequestTimestamp(AHash; ATsaUrl): TTimestampResult` (constrói TS_REQ via `TS_REQ`, envia HTTP POST via `httpsend`, parseia response, valida assinatura do TSA). | 3h |
| **E5** | **Helper `ssl_openssl_icpbrasil_signer.pas` (CSL)** — wrapper específico ICP-Brasil: `AssinarNFeXml(AXml: string; ACert; AKey): string` (CAdES detached + time-stamp opcional + XmlDSig wrapping). | 2h |
| **E6** | Tests com NFe XML real (homologação SEFAZ) + validação contra schema XmlDSig + docs (`docs-extra/cades-signing.md`, `docs-extra/timestamping.md`). | 1h |

### API exposta (S12)

```pascal
// Signing
TPkcs7Signer = class
  function AssinarBytes(const AData: TBytes; ACert: PX509; AKey: SslPtr;
                        AMode: TPkcs7Mode = psBinarioCAdES): TBytes;
  function VerificarAssinatura(const ASigned: TBytes;
                               ATrustStore: TX509ChainVerifier): TVerifyResult;
end;

// Time-stamping
TTspClient = class
  function RequestTimestamp(const ADataHash: TBytes; const ATsaUrl: string;
                            const AHashAlgo: string = 'SHA-256'): TTimestampResult;
end;

// ICP-Brasil specific
function AssinarNFeXml(const AXml: string; ACert: PX509; AKey: SslPtr;
                      const ATsaUrl: string = ''): string;
```

### Resultado S12

Synapse passa a oferecer toda a stack de assinatura fiscal:

- Lê PFX
- Valida cadeia + revogação
- Extrai cert+chave
- Assina XML NFe em CAdES detached
- Anexa time-stamp RFC 3161
- Tudo cross-platform

ACBr depende de XmlSec (multiplataforma) ou MSXML/WinCrypt (Windows). Synapse passa a competir directamente em Linux/macOS, onde ACBr não funciona para esta capacidade.

---

## 6. Sprint S13 — V42.0 — Hardware (PKCS#11 + Windows Store + A3) (~30h)

> A grande lacuna do Synapse (e do ACBr fora do Windows). Sprint mais longo. **Pode ser dividido em 2 sub-sprints** (S13a Windows-only, S13b PKCS#11 cross-platform).

### Sub-sprint S13a — Windows Store + A3 detection (~12h)

| # | Acção | Esforço |
|---|---|---|
| **F1** | **Bindings Windows MyStore** em nova `ssl_winstore_lib.pas` (Windows-only): `CertOpenSystemStore`, `CertEnumCertificatesInStore`, `CertGetCertificateContextProperty`, `CertGetCertificateChain`, `CertCloseStore`, `CryptAcquireCertificatePrivateKey`, `CertCompareCertificateName` | 3h |
| **F2** | **Nova unit `ssl_winstore.pas` (CSL, Windows-only)** — `TWinCertStore.OpenStore(slMy/slCurrentUser/slLocalMachine)`, `EnumerateCertificates: TArray<TWinCertEntry>`, `LoadCertAsX509(handle): PX509` (converte CERT_CONTEXT → PX509 via DER export) | 4h |
| **F3** | **Detecção A3 via WinCrypt** — `CRYPT_IMPL_HARDWARE` flag + CNG `NCRYPT_IMPL_HARDWARE_FLAG` (espelha ACBr [`ACBrDFeWinCrypt.GetCertIsHardware`](e:/GDoc/src/package/ACBr/Fontes/ACBrDFe/ACBrDFeWinCrypt.pas)); helper `IsCertificadoEmHardware(ACertContext): Boolean` em `ssl_winstore.pas`. **Cópia adaptada do ACBr (LGPL)** com créditos no header. | 2h |
| **F4** | **Bridge `TWinCertEntry → TIcpBrasilCertificado`** — método `LerCertWindowsStore(AThumbprint: string; AOpts: TLerDoPfxOptions): TIcpBrasilCertificado` em `ssl_openssl_icpbrasil.pas` que aceita cert por thumbprint do Windows Store em vez de PFX bytes. | 2h |
| **F5** | Tests com Windows Store real (cert teste em `slCurrentUser\My`) + docs | 1h |

### Sub-sprint S13b — PKCS#11 cross-platform (~18h)

| # | Acção | Esforço |
|---|---|---|
| **F6** | **Stub PKCS#11 (Cryptoki) cross-platform** em nova `ssl_pkcs11_types.pas` — definir tipos PKCS#11 v3.0 em Pascal: `CK_BYTE`, `CK_ULONG`, `CK_SLOT_ID`, `CK_SESSION_HANDLE`, `CK_OBJECT_HANDLE`, `CK_FUNCTION_LIST`, `CK_ATTRIBUTE`, `CK_MECHANISM`, `CK_INFO`, `CK_TOKEN_INFO`, `CK_SLOT_INFO`. Tipos gerados conforme `pkcs11.h` da OASIS. | 4h |
| **F7** | **Nova unit `ssl_pkcs11_loader.pas` (CSL)** — `TPkcs11Loader.LoadModule(APath)` (`dlopen` ou `LoadLibrary`), resolve `C_GetFunctionList`, expõe API tipada: `EnumerateSlots`, `OpenSession(ASlot, APin)`, `EnumerateCertificates`, `Sign(AHandle, AData, AMech): TBytes`. | 5h |
| **F8** | **Auto-detecção PKCS#11 paths conhecidos** em `TPkcs11Loader.AutoDetect`: Linux (`/usr/lib/x86_64-linux-gnu/libsofthsm2.so`, `/usr/lib64/libeToken.so`, `/usr/lib/pkcs11/`), Windows (`C:\Windows\SysWOW64\eTPKCS11.dll`, `C:\Program Files\SafeNet\Authentication\SAC\x64\eTPKCS11.dll`), macOS (`/usr/local/lib/pkcs11/`) | 2h |
| **F9** | **Bridge PKCS#11 → OpenSSL** em nova `ssl_pkcs11_synapse.pas` — converter cert lido via PKCS#11 (`CKA_VALUE` em DER) para `PX509` OpenSSL via `d2i_X509`. Usar `EVP_PKEY` "engine" para signing remoto via PKCS#11. | 4h |
| **F10** | **Integração com `LerDoPfx`** — método `LerCertPkcs11(AModulePath; ASlotId; APin: string): TIcpBrasilCertificado`; permite usar o leitor ICP-Brasil completo com cert em token. | 2h |
| **F11** | Tests com SoftHSM2 (Linux Docker) + token físico se disponível | 1h |

### Resultado S13

Synapse passa a ser **a única biblioteca Pascal com A3 portátil cross-platform**. ACBr só tem A3 no Windows (CAPI). Habilita uso em Linux/Docker para servidores fiscais (eSocial em produção em containers, por exemplo).

---

## 7. Sprint S14 — V42.1 — Helpers fiscais + audit + docs (~6h)

### Tarefas

| # | Acção | Esforço |
|---|---|---|
| **G1** | Helper `IsCertificadoNFe(ACert): Boolean` — verifica EKU clientAuth + ICP-Brasil reconhecida (Policy V3+) + e-CNPJ válido + não-revogado | 30 min |
| **G2** | Helper `IsCertificadoESocial(ACert): Boolean` — eSocial requer e-CNPJ ou e-CPF + EKU clientAuth | 30 min |
| **G3** | Helper `IsCertificadoSerpro(ACert): Boolean` — verifica AC SERPRO (subset ICP-Brasil) | 30 min |
| **G4** | Helper `IsCertificadoSefaz(ACert; AUf: string): Boolean` — verifica AC SEFAZ por UF | 30 min |
| **G5** | Helper `IsCertificadoEFDReinf(ACert): Boolean` — EFD-Reinf | 30 min |
| **G6** | **Audit DOC-ICP-04 v8.x** — confirmar todos os OIDs adicionados batem com a versão actual do documento ITI; adicionar referência exacta ao header das units | 1h |
| **G7** | **Documentação completa** — atualizar [`docs-extra/icpbrasil-oids.md`](e:/Dropbox/GDoc/src/modules/Synapse/docs-extra/icpbrasil-oids.md), [`integration-guide.md`](e:/Dropbox/GDoc/src/modules/Synapse/docs-extra/integration-guide.md), criar `docs-extra/cades-signing.md`, `docs-extra/pkcs11-cross-platform.md`, `docs-extra/winstore.md`, `docs-extra/revocation.md`, `docs-extra/oab-digital.md`. | 2h |
| **G8** | **README.md + CHANGELOG.md** atualizar com matriz final V42.1 vs ACBr | 30 min |

### Resultado S14

Synapse pronto para distribuição pública como referência ICP-Brasil. ACBr ofuscado em todas as features fiscais.

---

## 8. Matriz final esperada (após S14, V42.1)

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
| NumeroSerie/ThumbPrint/DERBase64/Versao | ✅ todos | ⚠️ parcial | **Synapse** |
| **Chain validation programática offline** | ✅ S9 | ❌ | **Synapse** |
| **Bundle AC-Raiz ICP-Brasil v1..v10** | ✅ S9 | ❌ | **Synapse** |
| **CRL programmatic verify** | ✅ S10 | ❌ | **Synapse** |
| **OCSP client** | ✅ S10 | ❌ | **Synapse** |
| **AIA / CDP auto-fetch** | ✅ S10 | ❌ | **Synapse** |
| **PolicyIdentifier validation + AC-Raiz V1..V10** | ✅ S9 | ❌ | **Synapse** |
| Email/DNS/IP/URI no SAN | ✅ S11 | ❌ | **Synapse** |
| Key Usage / Ext Key Usage parsing | ✅ S11 | ⚠️ parcial | **Synapse** |
| OAB digital | ✅ S11 | ❌ | **Synapse** |
| CAEPF/CEI/PIS distinguidos | ✅ S11 | ❌ | **Synapse** |
| **PKCS#7/CAdES signing nativo** | ✅ S12 | ⚠️ via XmlSec/MS | **Synapse** |
| **Time-stamping RFC 3161 client** | ✅ S12 | ❌ | **Synapse** |
| Helpers fiscais (NFe/eSocial/Serpro/Sefaz/EFD) | ✅ S14 | ⚠️ ACBr só ValidarCNPJCertificado | **Synapse** |
| ASN.1 generic decoder reaproveitado | ✅ asn1util | ⚠️ binário ad-hoc | **Synapse** |

**Resultado:** Synapse v42.1 fica à frente do ACBr em **18 de 23 features**, empate em 5, sem perdas.

---

## 9. Plano de execução incremental

**Recomendação:** entregar sprint-a-sprint, validando contra PFX real fiscal a cada sprint.

**Sequência sugerida:**

```
S10 (revogação) ──> S11 (subject) ──> S12 (signing) ──> S13a (WinStore) ──> S13b (PKCS#11) ──> S14 (helpers + docs)
```

**Pontos de decisão:**

- Após **S10**: já temos validação completa (chain + revogação) → pode parar aqui se foco for só leitura/validação.
- Após **S11**: cobertura DOC-ICP-04 v8.x completa → pode parar se signing for fora do escopo.
- Após **S12**: signing nativo entregue → pode parar se A3 não for prioridade (Linux server-side com A1 cobre 80% dos casos).
- **S13 é opcional** se o consumidor não usa A3 (muitos casos fiscais usam apenas A1).
- **S13a** (Windows Store) é mais barato e pode ser entregue isolado de S13b (PKCS#11).

**Possível paralelização:**

- S11 (D1-D8) e S12 (E1-E6) podem rodar em paralelo após S10 — não há dependências cruzadas além do `asn1util` e bindings comuns.
- S13a e S13b podem rodar em paralelo (S13a Windows-only, S13b cross-platform — não se tocam).

---

## 10. Verificação por sprint

| Sprint | Smoke test | Tests adicionais |
|---|---|---|
| S10 | PFX real + cert revogado conhecido → `Revogado=True`; cert não-revogado → `Revogado=False` | OCSP responder real; AIA auto-fetch funcional; cache TTL respeitado |
| S11 | Email/DNS/KeyUsage extraídos de cert real | OAB cert; CAEPF cert; SAN com IP; cert SmartCardLogon (EKU) |
| S12 | NFe XML assinado por Synapse valida em SEFAZ homologação | Time-stamp anexado e verificado; CAdES-BES + CAdES-T |
| S13a | Cert do Windows Store carregado via `LerCertWindowsStore` | Detecção A3 (`IsCertificadoEmHardware`) funcional |
| S13b | Cert em SoftHSM2 (Linux) → `LerCertPkcs11` funcional via PKCS#11 | Token físico real (eToken/Giesecke); auto-detecção paths |
| S14 | `IsCertificadoNFe` filtra correctamente lote misto de PFX | Auditoria DOC-ICP-04 v8.x linha-a-linha; matriz V42.1 confirmada |

---

## 11. Riscos e mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Bundle AC-Raiz ITI mudar (revogação de AC, nova versão V11+) | Baixa | Médio | Script automatizado `AC-Raiz-ICP-Brasil-fetch.ps1` + CI mensal |
| OpenSSL 4.0 ainda incompleto/instável para PKCS#7 | Média | Médio | Manter compatibilidade dual (3.x e 4.0); testar primeiro com 3.x |
| PKCS#11 fragmentação de drivers (eToken vs SafeNet vs Giesecke) | Alta | Médio | Testar com SoftHSM2 + 2-3 tokens reais comuns no Brasil |
| Performance — assinar PKCS#7 + time-stamp pode ser lento | Média | Baixo | Cache de TSA tokens + assinatura assíncrona onde aplicável |
| ACBr lança feature equivalente | Baixa | Baixo | Synapse já distancia-se em portabilidade (Linux/macOS); manter LP |
| Cert XmlDSig wrapping (NFe usa XmlDSig dentro de PKCS#7) | Média | Alto | S12-E5 trata isso; se complexo demais, oferecer só CAdES e deixar XmlDSig wrapping para consumidor (`ActiveDirectoryORM` ou equivalente) |
| RFC 3161 TSA URLs públicas mudarem | Baixa | Baixo | Aceitar URL configurável; documentar TSAs gratuitas conhecidas (DigiCert, FreeTSA, SerproDigital) |
| OpenSSL `BN_bn2dec` retornar valores muito grandes para `Integer` | Baixa | Baixo | S8 já trata via `_CopyAndFreeOpenSSLString` retornando string |

---

## 12. Decisão pedida ao utilizador

1. **Aprovar S10 isolado** (~18h, revogação + refactor ASN.1)? Mais barato e fecha lacuna fiscal grande.
2. **S10+S11 combinado** (~28h, revogação + subject completo)? Cobre validação fiscal pleno.
3. **S10+S11+S12** (~44h, validação + signing nativo)? Synapse standalone para emissão fiscal Linux.
4. **S10+S11+S12+S13a** (~56h, + Windows Store)? Cobertura Windows total.
5. **Comprometer com roadmap completo S10→S14** (~80h, ~10 dias)? Cobertura 100% paritária ou superior ao ACBr.

A recomendação é **opção 3** (S10+S11+S12 = ~44h) — entrega Synapse 100% fiscal-capable em Linux, fecha as lacunas estruturais comuns (CRL/OCSP) e dá assinatura nativa. S13 (hardware) fica como decisão depois de validar que o stack S10-S12 cobre o caso de uso real.

---

## 13. Pendências documentais ao fechar

- `README.md` — actualizar matriz final V42.1
- `CHANGELOG.md` — entradas Keep-a-Changelog para cada sprint
- `VERSION.md` — bump consolidado V41.6 → V42.1
- `Synapse.Version.inc` — tags S10/S11/S12/S13/S14 (`SYNAPSE_CSL_ICPBR_S10` etc.)
- `Documentation/README.md` — actualizar hub
- `CLAUDE.md` — package version + changelog
- `docs-extra/` — adicionar 6 novos guias técnicos
- `bundles/` — script para CRL refresh (se precisar — bundle de CRL crescer pode justificar)
