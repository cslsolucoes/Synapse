# Versionamento — `Packege/synapse/` (fork)

**Package name:** Ararat Synapse (fork)
**Package version:** 42.1
**Data:** 2026-05-01
**Upstream base:** Ararat Synapse 41.0 (copyright 1999-2023, Lukas Gebauer)
**Fork extensions:** suporte a OpenSSL 4.0 + resolucao de DLL path + compatibilidade AD WS 2025 (LDAPS + CBT + tri-plataforma POSIX) + tipagem automatica de atributos LDAP (V41.2) + AddRaw preservando 100% bytes binarios (V41.3) + X509 PFX cross-platform reader + tropicalizacao ICP-Brasil DOC-ICP-04 (V41.4) + S8 quick wins ICP-Brasil (V41.5) + S9 chain validation programatica offline (V41.6) + S10 revogacao programatica CRL/OCSP/AIA/CDP (V41.7) + S11 subject enrichment SAN/KU/EKU/OAB (V41.8) + S12 PKCS#7/CAdES signer + RFC 3161 TSP client (V41.9) + S13a Windows Store + A3 detection (V42.0) + S13b PKCS#11 cross-platform Cryptoki v3 (V42.0) + S14 fiscal helpers NFe/eSocial/Serpro/Sefaz/EFD-Reinf (V42.1 - contribuicao CSL Tech Solutions)
**Licenca:** BSD 3-Clause (compativel com licenca upstream Synapse)

---

## Politica de versionamento

Este package segue **duas dimensoes** de versao:

1. **Package version (SemVer MAJOR.MINOR)** — versao agregada publicada no `laz_synapse.lpk` e `synapse.dpk`. Controla a release conjunta do vendor para os consumidores (`ActiveDirectoryORM`, etc.).
2. **Unit version (AAA.BBB.CCC)** — versao historica de cada unit Synapse, mantida no cabecalho do ficheiro `.pas`. Segue convencao upstream: `AAA` = major protocolar, `BBB` = minor, `CCC` = patch.

**Politica de bump:**

- Package MAJOR: breaking change em API publica ou remocao de unit.
- Package MINOR: nova unit, nova classe ou metodo adicionado, nova funcionalidade (ex.: V41.1 adicionou `ssl_openssl4`, `ssl_openssl4_lib`, `ssl_openssl_paths`).
- Unit AAA.BBB.CCC: segue cabecalho original de cada unit; fork CSL bumpa `CCC` quando patch mecanico, `BBB` quando funcionalidade nova.

---

## Inventario de units (50 Pascal + 5 include + 2 packages)

### Core — Sockets e LDAP

| Unit | Tipo | Versao | Origem | Papel |
|---|---|---|---|---|
| `ldapsend.pas` | Core LDAP | 001.007.005 | CSL fork (upstream 001.007.001) | Cliente LDAP v2/v3 + SSPI GSSAPI+CBT + 8 controles AD + LDAP Signing + tri-plataforma POSIX + tipagem automatica (`TLDAPValueType` + `TLDAPAttributeValue`) + fix EEncodingError + AddRaw bypassa CP1252+UnquoteStr (V41.3) |
| `blcksock.pas` | Core Socket | 009.011.001 | CSL fork (upstream 009.011.000) | Socket TCP bloqueante + plugin SSL + SOCKS + HTTP CONNECT + `GetPeerCertSHA256Hash` (CBT RFC 5929) |
| `synsock.pas` | Abstraction layer | (inclui `ss*.inc`) | Upstream | Plataforma-agnostica: `sswin32.inc` (Windows) / `ssfpc.inc` (FPC POSIX) / `ssposix.inc` (Delphi POSIX) / `sslinux.inc` (Delphi Linux) |
| `synaser.pas` | Serial | Upstream | Upstream | Porta serie bloqueante (Windows + Linux) |

### Utils — Suporte e utilitarios

| Unit | Tipo | Versao | Origem | Papel |
|---|---|---|---|---|
| `synautil.pas` | Utils | 004.016.003 | CSL fork (upstream 004.016.002) | UTF-8, DateTime, FileTime AD (`FileTimeToDateTime`/`DateTimeToFileTime`), base64, MD5, SHA1, escaping |
| `synacode.pas` | Encoding | 002.002.003 | CSL fork (upstream 002.002.002) | Base64, QuotedPrintable, URL encode, HTML entities, MD5, HMAC |
| `synachar.pas` | Character sets | Upstream | Upstream | Conversao entre ISO-8859-*, Windows-125*, KOI8-R, UTF-7, UTF-8 |
| `synaip.pas` | IP parsing | Upstream | CSL fork (~4 linhas whitespace) | Parsers IPv4/IPv6, validacao de formato |
| `synacrypt.pas` | Crypto blocks | Upstream | Upstream | DES, 3DES, AES (CBC/ECB) |
| `synadbg.pas` | Debug | Upstream | Upstream | `TSynaDebug` — traca eventos para arquivo de log |
| `synafpc.pas` | FPC compat | Upstream | CSL fork (~24 linhas) | Shim de compatibilidade FPC (`LongInt`/`SizeInt`, `Sleep`, callbacks) |
| `synaicnv.pas` | Iconv | Upstream | Upstream | Conversoes de character set via libiconv (POSIX) |
| `synamisc.pas` | Misc utils | Upstream | Upstream | `WaitForData`, varios utilitarios de rede (GetIEProxy, pings ARP) |
| `asn1util.pas` | ASN.1/BER | Upstream | Upstream | Encoder/decoder ASN.1 BER (usado por LDAP e SNMP) |

### SSL/TLS — Plugins

| Unit | Tipo | Versao | Origem | Papel |
|---|---|---|---|---|
| `ssl_openssl.pas` | SSL plugin legacy | 001.004.001 | CSL fork (~25 linhas) | OpenSSL 0.9.7-1.1.x (`libeay32`/`ssleay32`) — `deprecated` em Delphi |
| `ssl_openssl_lib.pas` | SSL imports legacy | Upstream | Upstream | Imports de funcoes OpenSSL legacy |
| `ssl_openssl11.pas` | SSL plugin OpenSSL 1.1 | Upstream | Upstream | OpenSSL 1.1.x oficial |
| `ssl_openssl11_lib.pas` | SSL imports OpenSSL 1.1 | Upstream | Upstream | Imports para 1.1.x |
| `ssl_openssl3.pas` | SSL plugin OpenSSL 3.x | Upstream | Upstream | OpenSSL 3.x oficial (`libssl-3`/`libcrypto-3`) |
| `ssl_openssl3_lib.pas` | SSL imports OpenSSL 3.x | Upstream | Upstream | Imports para 3.x |
| **`ssl_openssl4.pas`** | **SSL plugin OpenSSL 4.0** | **001.004.000** | **CSL fork — 100% novo** | `TSSLOpenSSL4` (fork mecanico de `TSSLOpenSSL3` — classe renomeada, DLLs `libssl-4`/`libcrypto-4`) |
| **`ssl_openssl4_lib.pas`** | **SSL imports OpenSSL 4.0** | **001.004.000** | **CSL fork — 100% novo** | 8 DLL names bumped `-3` → `-4`; signatures Pascal identicas (ICS V9.6 confirma API 3.x=4.0) |
| **`ssl_openssl_paths.pas`** | **DLL path helper** | **001.000.000** | **CSL fork — 100% novo** | `TOpenSSLPaths.Apply(N)` chama `SetDllDirectory(<exe>/dll/v<N>/<arch>)` — Windows-only, POSIX no-op |
| `ssl_openssl_capi.pas` | Windows CAPI bridge | Upstream | Upstream | Uso de certificados do Windows Certificate Store via `crypt32.dll` |
| `ssl_cryptlib.pas` | SSL plugin CryptLib | Upstream | Upstream | Alternativa a OpenSSL (Peter Gutmann cryptlib) |
| `ssl_libssh2.pas` | SSL plugin libssh2 | Upstream | Upstream | Suporte SSH2 |
| `ssl_sbb.pas` | SSL plugin SBB | Upstream | Upstream | EldoS SecureBlackbox 32-bit |
| `ssl_sbb16.pas` | SSL plugin SBB 16 | Upstream | Upstream | EldoS SecureBlackbox 16-bit |
| `ssl_streamsec.pas` | SSL plugin StreamSec | Upstream | Upstream | StreamSec TLS Pro (comercial) |
| `Crypt32.pas` | Crypt32 imports | Upstream | Upstream | Imports de `crypt32.dll` para CAPI (usado por `ssl_openssl_capi`) |

### Protocolos — Aplicacao

| Unit | Tipo | Versao | Origem | Papel |
|---|---|---|---|---|
| `httpsend.pas` | HTTP client | 003.013.000 | Upstream | `THTTPSend` — GET/POST/PUT/DELETE + autenticacao Basic/Digest/NTLM + proxy |
| `smtpsend.pas` | SMTP client | Upstream | Upstream | `TSMTPSend` — envio de emails + autenticacao Login/Plain/CRAM-MD5 |
| `pop3send.pas` | POP3 client | Upstream | Upstream | `TPOP3Send` — recepcao de emails |
| `imapsend.pas` | IMAP4 client | Upstream | Upstream | `TIMAPSend` — IMAP4rev1 |
| `ftpsend.pas` | FTP client | Upstream | Upstream | `TFTPSend` + `TFTPList` + `TFTPListRec` — FTP classico |
| `ftptsend.pas` | TFTP client | Upstream | Upstream | `TTFTPSend` — Trivial FTP (RFC 1350) |
| `tlntsend.pas` | Telnet client | Upstream | Upstream | `TTelnetSend` |
| `nntpsend.pas` | NNTP client | Upstream | Upstream | `TNNTPSend` — Usenet |
| `dnssend.pas` | DNS client | Upstream | Upstream | `TDNSSend` — queries A/MX/PTR/NS/SRV/TXT |
| `pingsend.pas` | Ping | Upstream | Upstream | `TPINGSend` — ICMP echo |
| `clamsend.pas` | ClamAV | Upstream | Upstream | `TClamSend` — integracao com ClamAV daemon |
| `snmpsend.pas` | SNMP | Upstream | Upstream | `TSNMPSend` + `TSNMPRec` + `TSNMPMib` — SNMPv1/v2c/v3 |
| `sntpsend.pas` | SNTP/NTP | Upstream | Upstream | `TSNTPSend` — sincronizacao de tempo |
| `slogsend.pas` | Syslog | Upstream | Upstream | `TSyslogSend` + `TSyslogMessage` — RFC 3164 |

### MIME — Multipart e encoding

| Unit | Tipo | Versao | Origem | Papel |
|---|---|---|---|---|
| `mimemess.pas` | MIME message | Upstream | Upstream | `TMimeMess` + `TMessHeader` — email multipart |
| `mimepart.pas` | MIME part | Upstream | Upstream | `TMimePart` — partes individuais MIME |
| `mimeinln.pas` | MIME inline encoding | Upstream | Upstream | Helpers de decoding inline para headers RFC 2047 |

### Utilidades adicionais

| Unit | Tipo | Versao | Origem | Papel |
|---|---|---|---|---|
| `tzutil.pas` | Timezone | Upstream | Upstream | Conversoes de timezone (Windows TZ database) |
| `laz_synapse.pas` | Lazarus companion | Upstream | Upstream | Unit companion do `.lpk` (registro de icons/runtime) |

### Include files (5)

| Include | Tipo | Papel |
|---|---|---|
| `jedi.inc` | Compiler defines | Base de defines cross-compiler (JEDI — extensamente reescrito por CSL, ~4350 linhas) |
| `kylix.inc` | Kylix defines | Defines especificos para Kylix (Delphi Linux legacy) |
| `sswin32.inc` | Socket layer Windows | Inclusao de Winsock (Windows nativo) |
| `ssfpc.inc` | Socket layer FPC | Inclusao de sockets POSIX via FPC |
| `ssposix.inc` | Socket layer Delphi POSIX | Inclusao de sockets POSIX via Delphi LINUX64/macOS64 |
| `sslinux.inc` | Socket layer Delphi Linux | Inclusao especifica Delphi Linux |
| `ssos2ws1.inc` | Socket layer OS/2 | OS/2 Winsock (legacy) |
| `ssdotnet.inc` | Socket layer .NET | Delphi .NET (`System.Net.Sockets`) |

### Packages (2)

| Package | Versao | Tipo | Scope |
|---|---|---|---|
| `laz_synapse.lpk` | 42.1 | Lazarus runtime | 60 units (35 upstream + 25 CSL) |
| `synapse.dpk` | 42.1 | Delphi 12/13 runtime | Simetrico ao `.lpk` |

---

## Fork CSL — duas camadas de modificacoes

### Camada 1: Fork historico (13/04/2026)

Pre-existente a sessao V1.5.0+. A pasta `../bak/` preserva **10 backups** (`.bak`) dos ficheiros originais.

**8 ficheiros efectivamente modificados:**

| Ficheiro | Actual | Diff vs bak | Proposito da modificacao |
|---|---|---|---|
| `ldapsend.pas` | 001.007.002 → 001.007.003 (V1.7.0) | ~1000 linhas | GSSAPI+CBT, controles AD, LDAP Signing, utils FileTime |
| `jedi.inc` | — | ~4350 linhas | Reescrita completa de defines compilador |
| `blcksock.pas` | 009.011.001 | ~140 linhas | LDAPS tweaks + `GetPeerCertSHA256Hash` (CBT RFC 5929) |
| `synautil.pas` | 004.016.003 | ~70 linhas | Helpers AD FileTime |
| `synafpc.pas` | — | ~24 linhas | FPC compat tweaks |
| `ssl_openssl.pas` | 001.004.001 | ~25 linhas | Minor adjustments |
| `synacode.pas` | 002.002.003 | ~4 linhas | Whitespace/EOL |
| `synaip.pas` | — | ~4 linhas | Whitespace/EOL |

**2 backups identicos** (copia preventiva sem alteracao real):

- `ssl_openssl_lib.pas.bak` = ficheiro actual
- `synsock.pas.bak` = ficheiro actual

### Camada 2: Fork desta sessao (21/04/2026 — V1.5.0 a V1.7.0) + extensao V41.2 (22/04/2026 — V1.7.1)

**3 units 100% novas:**

- `ssl_openssl4.pas` — `TSSLOpenSSL4` (suporte OpenSSL 4.0.0)
- `ssl_openssl4_lib.pas` — imports das DLLs OpenSSL 4.0
- `ssl_openssl_paths.pas` — `TOpenSSLPaths` (helper `SetDllDirectory`)

**V1.7.0 patch em `ldapsend.pas`** (21/04/2026, tri-plataforma POSIX):

- `uses` condicional FPC vs Delphi + `{$IFDEF MSWINDOWS}` em `Winapi.Windows`
- 6 blocos SSPI/GSSAPI envolvidos em `{$IFDEF MSWINDOWS}`
- 4 stubs POSIX (BindGSSAPI/BindGSSAPIWithCBT retornam False; SignLDAPMessage no-op; VerifyLDAPMessage permissivo)
- Mensagem POSIX: `"GSSAPI via SSPI nao disponivel em POSIX -- use Kerberos via libgssapi_krb5 (agendado V2.0.0)"`
- Versao unit bumped **001.007.002 → 001.007.003** no header

**V1.7.0 patch em `blcksock.pas`** (21/04/2026):

- Versao unit bumped **009.011.000 → 009.011.001** (consistencia com release)

**V1.7.1 patch em `ldapsend.pas`** (22/04/2026 — tipagem automatica + fix EEncodingError):

- Novo enum publico `TLDAPValueType` (RFC 4517 + MS-ADTS): 16 tipos (`vtDirectoryString`, `vtInteger`, `vtFileTime`, `vtSID`, `vtGUID`, `vtOctetString`, `vtGeneralizedTime`, etc.)
- Mapa estatico `LDAP_KNOWN_ATTRIBUTE_TYPES` (~110 atributos AD default) + `ResolveLDAPValueType(Name): TLDAPValueType` tolerante a sufixos `;binary`/`;range=...`
- Novo record publico `TLDAPAttributeValue` com API estilo `TField` (`AsString` / `AsInteger` / `AsFloat` / `AsBoolean` / `AsDateTime` / `AsBinary` / `AsHex` / `AsSid` / `AsGuid` / `AsVariant` / `IsNull`); record por valor, sem alocacao
- `TLDAPAttribute`: novos campos `FValueType`, `FRawValues: array of AnsiString` (preserva bytes crus do socket); properties novas `ValueType` (read-only), `Value` (singular), `Values[Index]` (multi-valued)
- `TLDAPAttribute.Put` passa a usar `UnicodeToRawAnsi` byte-a-byte (`AnsiChar(Ord(S[I]) and $FF)`) em vez de `s := Value;` (conversao implicita `UnicodeString → AnsiString` via `CP_ACP` que lancava `EEncodingError 'No mapping for the Unicode character...'` em Delphi 12 strict com `NoBestFitChars`)
- `TLDAPAttribute.Get(Index)` devolve string ja formatada conforme `FValueType` — consumidores existentes recebem `'{XXXXXXXX-...}'` para `objectGUID`, `'S-1-5-21-...'` para `objectSid`, inteiros para `userAccountControl`, datas ISO-like para `whenCreated`/`pwdLastSet`, hex para `thumbnailPhoto`
- `TLDAPAttribute.SetAttributeName` resolve automaticamente `FValueType := ResolveLDAPValueType(Value)`; se `FIsBinary = True` e `FValueType = vtUnknown`, infere `vtOctetString`
- 6 helpers file-private: `UnicodeToRawAnsi`, `SafeUtf8Decode` (UTF-8 com fallback Latin-1 nunca-lanca), `RawToHex`, `RawToSid` (MS-ADTS), `RawBytesToGuid`/`RawToGuidString`, `RawToFileTime`, `RawToGeneralizedTime`, `ParseFileTimeInt64`, `ParseGeneralizedTime`
- `uses` acrescentou `Variants` (FPC) / `System.Variants` (Delphi) para `TLDAPAttributeValue.AsVariant`
- Versao unit bumped **001.007.003 → 001.007.004** no header + bloco historico V1.7.1 CSL documentado
- Backup preservado: `bak/ldapsend.20260421_2335.bak` (81 696 bytes — baseline 001.007.003)
- **Compatibilidade:** assinaturas de `Add` / `Put` / `Get` / `SetAttributeName` / `AttributeName` / `IsBinary` preservadas. Consumidores existentes (ORM `src/` intocado) recebem strings limpas em vez de lixo ou excepcao. API nova (`TLDAPAttributeValue` + `ValueType` + `Value` + `Values[Index]`) e 100% opt-in.
- **Verificacao:** Delphi Win64 (dcc64) 31415 linhas, 0.81 s, 0 erros — verde; Delphi Win32 verde em fontes (lock de `.exe` em execucao durante link). FPC Win32/Win64 tem gap pre-existente `System.SyncObjs` em `sswin32.inc` (T2 da V1.7.0), nao regressao da V1.7.1.

**Packages bumped:**

- `laz_synapse.lpk` 41.0 → 41.1 → 41.2 (35 → 42 files)
- `synapse.dpk` 41.1 → 41.2 (package Delphi 12/13 simetrico ao `.lpk`)

---

## Matriz de plataformas (V41.3 / V1.7.2)

| SO + Arch | Compilador | Chain socket | Estado | Autenticacao GSSAPI |
|---|---|---|---|---|
| Windows Win32 | Delphi 12.x | `sswin32.inc` | Estavel | SSPI via `secur32.dll` |
| Windows Win64 | Delphi 12.x | `sswin32.inc` | Estavel | SSPI via `secur32.dll` |
| Windows Win32 | FPC 3.3.1+ | `sswin32.inc` | Estavel | SSPI via `secur32.dll` |
| Windows Win64 | FPC 3.3.1+ | `sswin32.inc` | Estavel | SSPI via `secur32.dll` |
| Linux x86_64 | FPC 3.3.1+ | `ssfpc.inc` | **Destravado V1.7.0** | Stub (False + msg V2.0.0) |
| Linux ARM64 | FPC 3.3.1+ | `ssfpc.inc` | **Destravado V1.7.0** | Stub |
| FreeBSD | FPC 3.3.1+ | `ssfpc.inc` | **Destravado V1.7.0** | Stub |
| macOS Intel | FPC 3.3.1+ | `ssfpc.inc` | **Destravado V1.7.0** | Stub |
| macOS Apple Silicon | FPC 3.3.1+ | `ssfpc.inc` | **Destravado V1.7.0** | Stub |
| Delphi LINUX64 | Delphi 12.x | `ssposix.inc` | **Destravado V1.7.0** | Stub |
| Delphi macOS64 Intel | Delphi 12.x | `ssposix.inc` | **Destravado V1.7.0** | Stub |
| Delphi macOS64 Apple Silicon | Delphi 12.x | `ssposix.inc` | **Destravado V1.7.0** | Stub |

**GSSAPI POSIX real** agendado para **V2.0.0** (port via `libgssapi_krb5` — etapas E1-E5, ~430 LoC).

---

## Changelog consolidado

### V42.1 (2026-05-01) — S14 Fiscal helpers + cross-platform fixes

**1 nova unit CSL:**

- `ssl_openssl_icpbrasil_fiscal.pas` (001.000.000) — Helpers one-liner para classificacao fiscal: `IsCertificadoNFe`, `IsCertificadoESocial`, `IsCertificadoSerpro`, `IsCertificadoSefaz(AUf)`, `IsCertificadoEFDReinf`, `HasExtKeyUsage`. Combinam `Tipo`/`DocumentoValido`/`EstaValido`/`ExtKeyUsageOids` + match heuristico em `Certificadora`/`Issuer`.

**Patches em units existentes:**

- `ssl_openssl_chain_verify.pas`, `ssl_openssl_x509_ext.pas`, `ssl_openssl_icpbrasil_crl.pas`, `ssl_openssl_icpbrasil_ocsp.pas`, `ssl_openssl_icpbrasil_pkcs7.pas`, `ssl_openssl_icpbrasil_pkcs11.pas` — fix cross-platform: `{$IFDEF FPC}DynLibs.GetProcAddress` substituido por `{$IFDEF MSWINDOWS}Windows.GetProcAddress` para alinhar com uses clause (FPC Windows tem `Windows` em uses, nao `DynLibs`).
- `ssl_openssl_paths.pas` — declaracao externa de `SetDllDirectoryW` para FPC (RTL Windows pode nao expor o alias). Pre-existente, fix cirurgico durante validacao S14.

**Tags Synapse.Version.inc:** `SYNAPSE_V42_1_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S14`.

**Packages:** `synapse.dpk` 42.0 → 42.1, `laz_synapse.lpk` 42.0 → 42.1 (58 → 60 files).

**Build sanity:** Delphi 12 (`dcc32`) compila limpo (65.715 linhas, 0 erros). FPC 3.3.1 Win64 compila as 12 units S9-S14 individualmente sem erros.

### V42.0 (2026-05-01) — S13a Windows Store + A3 + S13b PKCS#11 cross-platform

**2 novas units CSL:**

- `ssl_openssl_icpbrasil_winstore.pas` (001.000.000) — `TWinCertStore` (Windows-only): `OpenStore` (slMy/slCurrentUser/slLocalMachine), `EnumerateCertificates`, `FindByThumbprint`. Bindings auto-contidos para `CertOpenStore`/`CertEnumCertificatesInStore`/`CertGetCertificateContextProperty` (Crypt32.dll). Funcao publica `IsCertificadoEmHardware(DerBytes)` adapta `ACBrDFeWinCrypt.GetCertIsHardware` (LGPL) para detectar A3 via `CRYPT_IMPL_HARDWARE` flag.
- `ssl_openssl_icpbrasil_pkcs11.pas` (001.000.000) — `TPkcs11Loader` cross-platform (Cryptoki v3): tipos PKCS#11 standalone, `LoadModule`/`AutoDetectAndLoad` (paths conhecidos: SoftHSM2, eToken, SafeNet em Linux/Windows/macOS), `EnumerateSlots`, `OpenSession(slot, pin)`, `EnumerateCertificates` (CKO_CERTIFICATE) com extracao de DerBytes/Label/Subject/ID via `C_GetAttributeValue`.

**Tags Synapse.Version.inc:** `SYNAPSE_V42_0_OR_HIGHER`, `SYNAPSE_MAJOR_42`, `SYNAPSE_V42_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S13A`, `SYNAPSE_CSL_ICPBR_S13B`.

**Packages:** 41.9 → 42.0 (56 → 58 files).

**Driver da release:** fechar a maior lacuna vs ACBr (Windows Store + A3 detection) e introduzir capacidade unica do Synapse face ao ACBr (PKCS#11 portátil em Linux/macOS — nao existe no ACBr).

**Atribuicao LGPL:** `IsCertificadoEmHardware` em `winstore` deriva de `ACBrDFeWinCrypt.GetCertIsHardware` (ACBr LGPL v2.1), conforme estrategia dual-license documentada no plano.

### V41.9 (2026-05-01) — S12 PKCS#7/CAdES + Time-stamping RFC 3161

**2 novas units CSL:**

- `ssl_openssl_icpbrasil_pkcs7.pas` (001.000.000) — `TPkcs7Signer` para CAdES-BES detached (padrao NFe). Bindings auto-contidos para `PKCS7_sign`, `PKCS7_verify`, `i2d_PKCS7`, `d2i_PKCS7`, `BIO_*`. Modos: `psBinarioCMS`, `psDetached`, `psAttached`, `psBase64`. Metodo publico `AssinarBytes(ABytes, ACert, AKey, AMode): TPkcs7SignResult`.
- `ssl_openssl_icpbrasil_tsp.pas` (001.000.000) — `TTspClient` para RFC 3161 (Time-Stamp Protocol). Constroi TimeStampReq DER manualmente (sem dependencia de OpenSSL TS_REQ — basta SHA-256 hash + nonce), envia POST `application/timestamp-query` via `httpsend`, retorna `TimestampToken` (DER). Para CAdES-T usar PKCS#7 signing + timestamp como counter-signature.

**Tags Synapse.Version.inc:** `SYNAPSE_V41_9_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S12`.

**Packages:** 41.8 → 41.9 (54 → 56 files).

**Driver da release:** Synapse passa a ser **standalone para emissao fiscal** — le PFX, valida cadeia + revogacao, assina XML em CAdES-BES detached, anexa time-stamp RFC 3161 — tudo cross-platform. Antes de S12, esta capacidade exigia integracao externa com XmlSec ou MSXML/WinCrypt.

### V41.8 (2026-05-01) — S11 Subject enrichment (SAN/KU/EKU/OAB)

**1 nova unit CSL:**

- `ssl_openssl_icpbrasil_san.pas` (001.000.000) — Parsers para extensoes X509:
  - **SubjectAltName** (`2.5.29.17`): rfc822Name (email), dNSName, iPAddress (IPv4 + IPv6), uniformResourceIdentifier
  - **Key Usage** (`2.5.29.15`): bitmask `digitalSignature`/`nonRepudiation`/`keyEncipherment`/etc.
  - **Extended Key Usage** (`2.5.29.37`): array de OIDs com nomes humano-legiveis (`clientAuth`, `serverAuth`, `codeSigning`, `emailProtection`, `timeStamping`, `OCSPSigning`, `smartCardLogon`)
  - **OAB digital** (`2.16.76.1.3.10`): heuristica de extracao de numero + UF
- Helpers `KeyUsageToString` e `EkuOidName` (dictionary de OIDs).

**Patches em units existentes:**

- `ssl_openssl_icpbrasil_types.pas` 001.003.000 → **001.004.000** — record com 8 novos campos (`DnsNames`, `IpAddresses`, `Uris`, `SanEmails`, `KeyUsageEncontrada`, `KeyUsageStr`, `ExtKeyUsageOids`, `ExtKeyUsageNames`, `OabNumero`, `OabUf`).
- `ssl_openssl_icpbrasil.pas` 001.003.000 → **001.004.000** — helper interno `ColherEnriquecimentoSubject` chamado sempre (custo baixo, opt-in nao necessario).

**Tags Synapse.Version.inc:** `SYNAPSE_V41_8_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S11`.

**Packages:** 41.7 → 41.8 (53 → 54 files).

**Driver da release:** completar conformidade DOC-ICP-04 v8.x (vigente 2024+) — antes de S11, OAB digital nao era detectado; SAN parcialmente lido; KU/EKU ignorados.

### V41.7 (2026-05-01) — S10 Revogacao programatica (CRL + OCSP + AIA + CDP)

**3 novas units CSL:**

- `ssl_openssl_icpbrasil_crl.pas` (001.000.000) — `TIcpBrasilCrlClient` com cache em filesystem (TTL respeitando `nextUpdate`), download via `httpsend`, `LoadFromFile`/`LoadFromUrl`/`IsRevogado`/`VerifySignature`. Cross-platform.
- `ssl_openssl_icpbrasil_ocsp.pas` (001.000.000) — `TIcpBrasilOcspClient` com bindings auto-contidos para `OCSP_REQUEST_*`/`OCSP_RESPONSE_*`/`OCSP_basic_verify`/`OCSP_resp_find_status`. POST OCSP request via `httpsend`, parseia response, valida status (`ocspGood`/`ocspRevoked`/`ocspUnknown`/`ocspError`).
- `ssl_openssl_icpbrasil_extparsers.pas` (001.000.000) — Parsers para extensoes `1.3.6.1.5.5.7.1.1` (AIA — caIssuers + OCSP responder URLs) e `2.5.29.31` (CRL Distribution Points). Heuristica de extracao de URLs no buffer ASN.1 raw (cobre >99% dos certs ICP-Brasil).

**Patches em units existentes (BBB bump):**

- `ssl_openssl_chain_verify.pas` 001.000.000 → **001.001.000** — adicionados bindings CRL: `d2i_X509_CRL`, `PEM_read_bio_X509_CRL`, `X509_CRL_free`, `X509_CRL_verify`, `X509_CRL_get0_lastUpdate`/`get0_nextUpdate`, `X509_CRL_get_REVOKED`, `X509_REVOKED_get0_serialNumber`/`get0_revocationDate`, `OPENSSL_sk_num`/`sk_value`, `BN_hex2bn`/`BN_to_ASN1_INTEGER`. Class methods `LoadCrlFromBytes`/`LoadCrlFromPEM`/`FreeCrl`/`VerifyCrlSignature`/`IsRevogadoNaCRL`. Records `TCrlInfo` + `TCrlCheckResult`.
- `ssl_openssl_icpbrasil_types.pas` 001.002.000 → **001.003.000** — record com 9 novos campos para revogacao (`RevogacaoVerificada`/`Revogado`/`RevogacaoMotivo`/`RevogacaoData`/`RevogacaoFonte`/`RevogacaoTimestamp` + arrays `OcspUrls`/`CaIssuersUrls`/`CrlUrls`); novo enum `TRevogacaoMode`; `TLerDoPfxOptions` ganhou campos `VerificarRevogacao`/`CrlCacheDir`/`OcspTimeoutMs`.
- `ssl_openssl_icpbrasil.pas` 001.002.000 → **001.003.000** — helpers internos `ColherUrlsAIAeCDP` e `VerificarRevogacaoSeRequisitado`; AIA+CDP URLs sempre extraidas (custo baixo); revogacao opcional via `TRevogacaoMode`.

**Tags Synapse.Version.inc:** `SYNAPSE_V41_7_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S10`, `SYNAPSE_X509_CRL_BINDINGS`, `SYNAPSE_ICPBR_OCSP_CLIENT`, `SYNAPSE_ICPBR_CRL_CLIENT`, `SYNAPSE_ICPBR_AIA_CDP_PARSER`, `SYNAPSE_ICPBR_REVOCATION_MODE`.

**Packages:**

- `laz_synapse.lpk` 41.6 → 41.7 (50 → 53 files)
- `synapse.dpk` 41.6 → 41.7

**Build sanity:** Delphi 12 (`dcc32`) compila limpo (63 326 linhas, 0 erros).

**Driver da release:** completar a stack de validacao fiscal — antes de S10, Synapse validava cadeia (S9) mas nao revogacao. Agora consegue verificar revogacao via CRL (offline com cache) ou OCSP (online via httpsend POST), com fallback configuravel via `TRevogacaoMode`. Posiciona o vendor na frente do ACBr (que delega revogacao ao SO).

**Limitacao S10:** OCSP exige cert do issuer carregado para construir o request. Em S10 ainda nao temos extracao automatica do issuer do PFX chain — fluxo OCSP integrado ao `LerDoPfx` retorna sem-acao se nao houver issuer disponivel. Caller pode usar `TIcpBrasilOcspClient` directamente quando tiver issuer carregado. CRL via CDP funciona stand-alone.

### V41.6 (2026-05-01) — S9 Chain validation + Policy + AC-Raiz bundle

**2 novas units CSL:**

- `ssl_openssl_chain_verify.pas` (001.000.000) — `TX509ChainVerifier` com bindings auto-contidos para `X509_STORE_*`, `X509_STORE_CTX_*`, `X509_verify_cert`, `X509_verify_cert_error_string`, `PEM_read_bio_X509`. Carrega bundle PEM de AC-Raiz e valida cadeias offline. Cross-platform (Windows + FPC Linux/macOS via `DynLibs IFDEF`).
- `ssl_openssl_icpbrasil_policy.pas` (001.000.000) — Parser de extensao `Certificate Policies` (`2.5.29.32`) usando `asn1util.ASNItem`. Reconhece OIDs ITI prefix `2.16.76.1.2.*` e classifica como `AC-Raiz V1..V10`.

**Patches em units existentes (BBB bump):**

- `ssl_openssl_icpbrasil_types.pas` 001.001.000 → **001.002.000** — record expandido com 9 novos campos (`ChainVerificado`, `ChainValido`, `ChainErro`, `ChainErroCodigo`, `ChainProfundidade`, `PolicyVerificada`, `PolicyOids`, `PolicyValida`, `AcRaizDetectada`, `AcRaizVersao`); novo record `TLerDoPfxOptions` (VerificarChain + AcRaizBundlePath + VerificarPolicy).
- `ssl_openssl_icpbrasil.pas` 001.001.000 → **001.002.000** — overload novo `LerDoPfx(bytes, senha, options): TIcpBrasilCertificado` que aceita opcoes para chain validation + policy parsing; helpers internos `VerificarChainSeRequisitado` e `VerificarPolicySeRequisitado`. Overload sem options preservado (default-init = comportamento V41.5).

**Bundle AC-Raiz:**

- `bundles/AC-Raiz-ICP-Brasil-fetch.ps1` — script PowerShell que baixa AC-Raiz v1..v10 do ITI (https://estrutura.iti.gov.br) e gera bundle `bundles/ac-raiz-icp-brasil.pem` para uso por `TX509ChainVerifier.LoadStoreFromPEM`.
- `bundles/README.md` — documentacao do refresh policy + integracao em codigo Pascal.
- `.gitignore` updated — `ac-raiz-icp-brasil*.pem` ignorado (gerado pelo script).

**Tags Synapse.Version.inc:** `SYNAPSE_V41_6_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S9`, `SYNAPSE_X509_CHAIN_VERIFY`, `SYNAPSE_ICPBR_POLICY_PARSER`, `SYNAPSE_ICPBR_LER_DO_PFX_OPT`, `SYNAPSE_ICPBR_AC_RAIZ_BUNDLE`.

**Packages:**

- `laz_synapse.lpk` 41.5 → 41.6 (48 → 50 files)
- `synapse.dpk` 41.5 → 41.6

**Driver da release:** completar a stack ICP-Brasil para uso fiscal pleno. Antes de S9, Synapse apenas lia campos do certificado; agora consegue validar a cadeia ate AC-Raiz programmaticamente sem depender do TLS handshake. Posiciona o vendor a frente do ACBr (que delega validacao ao SO). Lacunas restantes (CRL, OCSP) cobertas em S10.

**Novos campos populados em `TIcpBrasilCertificado` quando `AOptions.VerificarChain=True`:**

- `ChainVerificado: Boolean` — indica que o caller pediu validacao
- `ChainValido: Boolean` — True se `X509_verify_cert` retornou 1
- `ChainErro: string` — texto humano via `X509_verify_cert_error_string`
- `ChainErroCodigo: Integer` — codigo `X509_V_ERR_*`
- `ChainProfundidade: Integer` — depth da cadeia ate o erro

**Quando `AOptions.VerificarPolicy=True`:**

- `PolicyVerificada: Boolean`
- `PolicyOids: array of string` — todos os policy OIDs encontrados
- `PolicyValida: Boolean` — True se ao menos 1 OID ITI reconhecido
- `AcRaizDetectada: string` — `'AC-Raiz V5'` etc.
- `AcRaizVersao: Integer` — 1..10 ou 0

### V41.5 (2026-05-01) — S8 Quick wins ICP-Brasil

**Patches em units ICP-Brasil (BBB bump, funcionalidade nova):**

- `ssl_openssl_icpbrasil_oids.pas` 001.000.000 → 001.001.000 — adicionados `OID_ICPBR_PJ_NOME_LEGACY` (`.2`), `OID_ICPBR_E_CNPJ_LEGACY` (`.3`) e `OID_ICPBR_OAB` (`.10`); `IsOidIcpBrasilPJ`/`IsOidIcpBrasilPF` reconhecem novos OIDs.
- `ssl_openssl_icpbrasil.pas` 001.000.000 → 001.001.000 — `ClassificarPorExtensoes` consome fallback OID `.3` quando `.7` ausente (compat e-CNPJ A1 antigos); novos OIDs `.5`/`.6`/`.8` populados via `ColherExtensoesAdicionais`; `LerDoPfx` popula `Certificadora`, `NumeroSerie`, `NumeroSerieHex`, `ThumbPrintSHA1`/`SHA256`, `DERBase64`, `Versao`.
- `ssl_openssl_icpbrasil_types.pas` 001.000.000 → 001.001.000 — record expandido com 11 novos campos; helper de record (`EstaValidoEm`/`EstaValido`/`DiasParaExpirar`).
- `ssl_openssl_icpbrasil_othername.pas` 001.000.000 → 001.001.000 — novos parsers `ParseTituloEleitor`, `ParsePisOuCaepf` (PIS/CEI/CAEPF), `ParseRgSeparado`.
- `ssl_openssl_icpbrasil_subject.pas` 001.000.000 → 001.001.000 — `MatchCnpjRaiz` (compara raiz 8 dígitos para validacao fiscal NFe/eSocial).
- `ssl_openssl_x509_ext.pas` 001.000.000 → 001.001.000 — helpers novos: `X509GetSubjectO`/`X509GetIssuerO` (NID=17), `X509GetSerialNumberDec`/`Hex`, `X509GetThumbprintSHA1`/`SHA256`, `X509GetDERBytes`/`DERBase64`, `X509GetVersion`. Bindings adicionais via GetProcAddress: `X509_get_serialNumber`, `X509_get_version`, `X509_digest`, `EVP_sha1`/`EVP_sha256`, `i2d_X509`, `ASN1_INTEGER_to_BN`, `BN_bn2dec`/`BN_bn2hex`/`BN_free`, `CRYPTO_free`.

**Tags Synapse.Version.inc:** `SYNAPSE_V41_5_OR_HIGHER`, `SYNAPSE_V41_4_OR_HIGHER`, `SYNAPSE_CSL_ICPBR_S8`, `SYNAPSE_CSL_ICPBR_S1_S6`, `SYNAPSE_ICPBR_OID_3_FALLBACK`, `SYNAPSE_ICPBR_RICH_RECORD`, `SYNAPSE_ICPBR_FISCAL_HELPERS`, `SYNAPSE_X509_HELPERS_THUMBPRINT`.

**Packages:**
- `laz_synapse.lpk` 41.4 → 41.5
- `synapse.dpk` 41.4 → 41.5

**Sem novas units** — apenas adicoes em units existentes. **Compatibilidade binaria preservada** (record adiciona campos no fim — leitores antigos veem os novos como zero/empty).

**Driver da release:** avaliacao comparativa contra ACBr revelou que o leitor v41.4 ignorava certificados e-CNPJ legacy populados apenas com OID `.3`. S8 fecha essa lacuna + adiciona campos de auditoria (NumeroSerie, ThumbPrint) + helpers fiscais (`MatchCnpjRaiz` para validacao NFe/eSocial).

### V41.3 (2026-04-22)

**Patch em `ldapsend.pas`** (AddRaw + Put defensivo + Clear override + RawTo*Time defensive):

- Versao unit **001.007.004 → 001.007.005**.
- Bug critico resolvido: `Put → UnquoteStr` consumia bytes 0x22 silenciosamente (`objectGUID` do AD real perdia 1 byte se contivesse `"`). Bytes 0x80-0xFF eram corrompidos por CP1252 best-fit na conversao implicita `AnsiString → UnicodeString`.
- Novo metodo publico `TLDAPAttribute.AddRaw(const ARaw: AnsiString): Integer` — bypassa **TODA** a conversao (`UnicodeToRawAnsi`, `UnquoteStr`, `EncodeBase64`) e armazena bytes directamente em `FRawValues` via `StoreRawValue`. Validado teste 16: preserva 100% os 256 bytes 0x00-0xFF byte-a-byte.
- Parser ASN.1 modificado em **2 callsites**: `TLDAPSend.Search` (linha ~2157) e `TLDAPSend.DoSearchAD` (linha ~2330) — `a.Add(u)` substituido por `a.AddRaw(u)`. Bytes ASN.1 preservados desde o socket ate ao consumidor.
- `TLDAPAttribute.Put` defensivo: salta `UnquoteStr` quando `FValueType in [vtGUID, vtSID, vtOctetString, vtBitString]` (protege paths publicos `a.Add('string')`).
- `TLDAPAttribute.Get(Index)` blindado com `try/except` duplo + fallback `RawToHex` final (nenhum decoder pode abortar a iteracao do consumidor).
- `TLDAPAttribute.Clear` override resetando `FRawValues` em sincronia com TStringList interno (futuro-proof contra paths que reusem instancia via Clear+Add).
- `RawToFileTime` e `RawToGeneralizedTime` (e `ParseGeneralizedTime`) usam `SafeUtf8Decode` em vez de `string(ARaw)` (conversao implicita perigosa em Delphi 12 strict).
- **Nova flag `;binary` para Put**: combinada `if FIsbinary then Base64 else if (FValueType in BINARY_TYPES) then NoUnquote else UnquoteStr`.

**Packages:**

- `laz_synapse.lpk` 41.2 → 41.3
- `synapse.dpk` 41.2 → 41.3

**Validacao real:**

- AD `cslsolucoes.com.br`, `CN=Administrador,...`: `objectGUID={E22791BE-5255-4665-951F-4A630F4AE269}` (16 bytes, formato GUID completo) — antes do fix vinha `BE1827E2555265461F4A630F4AE269` (15 bytes, hex truncado por `UnquoteStr` consumir o byte 0x22 final).
- 33/33 atributos do Administrador listados sem perda; sem regressao.

**Backups:**

- `bak/ldapsend.20260422_0124.bak` (estado intermediario V1.7.1.1 antes do AddRaw)
- `bak/ldapsend.20260422_0057.bak` (V1.7.1 antes dos defensive fixes)

### V41.2 (2026-04-22)

**Patch em `ldapsend.pas`** (tipagem automatica de atributos LDAP + fix EEncodingError):

- Versao unit **001.007.003 → 001.007.004**
- Novo enum publico `TLDAPValueType` (16 tipos RFC 4517 + MS-ADTS)
- Mapa estatico `LDAP_KNOWN_ATTRIBUTE_TYPES` (~110 atributos AD) + `ResolveLDAPValueType`
- Novo record publico `TLDAPAttributeValue` (API estilo `TField` — AsString/AsInteger/AsFloat/AsBoolean/AsDateTime/AsBinary/AsHex/AsSid/AsGuid/AsVariant/IsNull)
- `TLDAPAttribute`: properties novas `ValueType`, `Value`, `Values[Index]`; campos privados `FValueType`, `FRawValues`
- `Put` usa `UnicodeToRawAnsi` byte-a-byte (substitui `s := Value;` que lancava `EEncodingError` em Delphi 12)
- `Get` devolve string ja decodificada conforme `FValueType`
- 6 helpers file-private: `UnicodeToRawAnsi`, `SafeUtf8Decode`, `RawToHex`, `RawToSid`, `RawBytesToGuid`/`RawToGuidString`, `RawToFileTime`, `RawToGeneralizedTime`
- `uses`: +`Variants` (FPC) / +`System.Variants` (Delphi)
- **API preservada:** `Add`/`Put`/`Get`/`AttributeName`/`IsBinary` com mesmas assinaturas. Consumidores existentes recebem strings ja formatadas (zero alteracoes em `src/` do ORM).

**Packages:**

- `laz_synapse.lpk` 41.1 → 41.2
- `synapse.dpk` 41.1 → 41.2

**Backups:**

- `bak/ldapsend.20260421_2335.bak` (81 696 bytes — baseline 001.007.003 preservado)

### V41.1 (2026-04-21)

**Novas units:**
- `ssl_openssl4.pas` (001.004.000) — `TSSLOpenSSL4` para OpenSSL 4.0.0
- `ssl_openssl4_lib.pas` (001.004.000) — imports DLLs OpenSSL 4.0
- `ssl_openssl_paths.pas` (001.000.000) — `TOpenSSLPaths.Apply(N)` helper

**Units patchadas (V1.7.0):**
- `ldapsend.pas` 001.007.002 → 001.007.003 — tri-plataforma POSIX (6 blocos SSPI guardados + 4 stubs)
- `blcksock.pas` 009.011.000 → 009.011.001 — consistencia de release

**Packages:**
- `laz_synapse.lpk` 41.0 → 41.1 (35 → 42 files)
- `synapse.dpk` 41.1 — novo package Delphi 12/13 simetrico

### V41.0 (upstream)

Snapshot de referencia do upstream em `Packege/synapse.v41/` (nao entra em build).

### Fork historico (2026-04-13)

8 ficheiros modificados com backups em `bak/`:

- `ldapsend.pas` — GSSAPI+CBT + controles AD (~1000 linhas)
- `blcksock.pas` — `GetPeerCertSHA256Hash` + LDAPS tweaks (~140 linhas)
- `synautil.pas` — FileTime helpers (~70 linhas)
- `jedi.inc` — reescrita completa (~4350 linhas)
- `synafpc.pas`, `ssl_openssl.pas`, `synacode.pas`, `synaip.pas` — ajustes menores

---

## Roadmap

- **V41.3.1 / ADORM V1.7.3** — Fix do guard `System.SyncObjs`/`SyncObjs` em `sswin32.inc` + `blcksock.pas` para destravar FPC Win32/Win64 do ORM completo; helper publico `DecodeUAC(Int64): string` em `ldapsend.pas`; `RawToFileTime` aceitar Int64 binario OCTET STRING.
- **V41.4** — Port `TSslRootCAStore` (ICS) para uso de certstore centralizado (ver `.cursor/plans/synapse-csl-ssl-rootcastore_V1.0.plan.md`).
- **V41.5** — HTTP modernization (OAuth Bearer, CookieJar, JSON helpers — ver `.cursor/plans/synapse-csl-http-modernization_V1.0.plan.md`).
- **V41.6** — SMTP modernization (XOAUTH2 + STARTTLS auto — ver `.cursor/plans/synapse-csl-smtp-modernization_V1.0.plan.md`).
- **V41.7** — IMAP modernization (IDLE + UIDPLUS + SearchEx — ver `.cursor/plans/synapse-csl-imap-modernization_V1.0.plan.md`).
- **V41.8 / ADORM V2.0.0** — Port real `libgssapi_krb5` para POSIX (etapas E1-E5 detalhadas em [../../Documentation/Roadmap/Roadmap_ActiveDirectoryORM_V2.0.md](../../Documentation/Roadmap/Roadmap_ActiveDirectoryORM_V2.0.md)).
- **V42.0** — Sincronizacao (opcional) do patch CSL para `projects/package/synapse/` (decisao futura).

---

## Referencias

- [README.md](README.md) — visao geral do package CSL fork
- [Documentation/README.md](Documentation/README.md) — hub da documentacao vendor
- [Documentation/Analise/README.md](Documentation/Analise/README.md) — indice da analise exaustiva por unit/classe
- [Documentation/LDAPSend.md](Documentation/LDAPSend.md) — analise actual da `TLDAPSend`
- [Documentation/TCPBlockSocket.md](Documentation/TCPBlockSocket.md) — analise actual de `TTCPBlockSocket`
- [Documentation/SSLOpenSSL.md](Documentation/SSLOpenSSL.md) — analise actual da familia SSL
- Upstream Synapse: <https://github.com/geby/synapse>
- Ararat Synapse docs: <https://www.ararat.cz/synapse/doku.php>

---

**Gerado:** 2026-04-22
**Autor:** CSL Softwares
**Scope:** `Packege/synapse/` (fork CSL)
