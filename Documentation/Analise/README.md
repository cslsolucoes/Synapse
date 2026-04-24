# Analise/ — Documentacao reversa exaustiva (Synapse CSL fork V41.3)

**Data:** 2026-04-22 · **Package version:** 41.3 · **Status:** em geracao (V1.7.2 acrescentada)

Analise arquivo-a-arquivo, classe-a-classe, metodo-a-metodo do **Ararat Synapse CSL fork** (`Packege/synapse/`). Cada documento segue o padrao de **7 seccoes**: _O que e_, _Caracteristicas_, _Engine_, _Funcionalidades_, _Aplicabilidades_, _Exemplos de uso_, _Relacionamentos_.

---

## Estrutura

```text
Documentation/Analise/
|-- README.md                        (este ficheiro — indice navegavel)
|-- FLOWCHART.md                     (diagramas Mermaid: arquitetura, heranca, fluxos)
|-- Core/                            (LDAP + Socket + ASN.1 + SynsockLayer)
|   |-- TLDAPSend.md                 (*ldapsend* — cliente LDAP v2/v3 principal; V1.7.1 integracao com tipagem automatica)
|   |-- TLDAPAttribute.md            (*ldapsend* — atributo LDAP; V1.7.1 properties ValueType/Value/Values[Index])
|   |-- TLDAPValueType.md            (*ldapsend* — **NOVO V1.7.1** enum publico + mapa LDAP_KNOWN_ATTRIBUTE_TYPES + ResolveLDAPValueType)
|   |-- TLDAPAttributeValue.md       (*ldapsend* — **NOVO V1.7.1** record estilo TField — AsString/AsInteger/AsFloat/AsBoolean/AsDateTime/AsBinary/AsHex/AsSid/AsGuid/AsVariant/IsNull)
|   |-- TLDAPAttributeList.md        (*ldapsend* — lista de atributos)
|   |-- TLDAPResult.md               (*ldapsend* — resultado de busca)
|   |-- TLDAPResultList.md           (*ldapsend* — lista de resultados)
|   |-- TTCPBlockSocket.md           (*blcksock* — socket TCP bloqueante)
|   |-- TBlockSocket.md              (*blcksock* — base abstract socket)
|   |-- TSocksBlockSocket.md         (*blcksock* — SOCKS4/5)
|   |-- TDgramBlockSocket.md         (*blcksock* — base UDP/ICMP)
|   |-- TUDPBlockSocket.md           (*blcksock* — socket UDP)
|   |-- TICMPBlockSocket.md          (*blcksock* — socket ICMP)
|   |-- TRAWBlockSocket.md           (*blcksock* — socket RAW)
|   |-- TPGMMessageBlockSocket.md    (*blcksock* — PGM message mode)
|   |-- TPGMStreamBlockSocket.md     (*blcksock* — PGM stream mode)
|   |-- TCustomSSL.md                (*blcksock* — interface plugin SSL)
|   |-- TSSLNone.md                  (*blcksock* — plugin NOP)
|   |-- TSynaOption.md               (*blcksock* — socket options)
|   |-- Asn1Util.md                  (*asn1util* — encoder/decoder ASN.1 BER)
|   |-- Synsock.md                   (*synsock* — layer plataforma-agnostica)
|-- SSL/                             (Plugins TLS/SSL)
|   |-- TSSLOpenSSL.md               (*ssl_openssl* — legacy 0.9.7-1.1.x)
|   |-- TSSLOpenSSL11.md             (*ssl_openssl11* — OpenSSL 1.1.x)
|   |-- TSSLOpenSSL3.md              (*ssl_openssl3* — OpenSSL 3.x)
|   |-- TSSLOpenSSL4.md              (*ssl_openssl4* — OpenSSL 4.0, fork CSL)
|   |-- TSSLOpenSSLCapi.md           (*ssl_openssl_capi* — Windows CAPI bridge)
|   |-- TOpenSSLPaths.md             (*ssl_openssl_paths* — DLL path helper, fork CSL)
|   |-- TEnginePool.md               (*ssl_openssl_capi* — pool de engines OpenSSL)
|   |-- TSSLCryptLib.md              (*ssl_cryptlib* — plugin CryptLib)
|   |-- TSSLLibSSH2.md               (*ssl_libssh2* — plugin libssh2)
|   |-- TSSLSBB.md                   (*ssl_sbb*/*ssl_sbb16* — plugin SecureBlackbox)
|   |-- TSSLStreamSec.md             (*ssl_streamsec* — plugin StreamSec)
|   |-- SSL_OpenSSL_Lib.md           (*ssl_openssl_lib* — imports OpenSSL legacy)
|   |-- SSL_OpenSSL11_Lib.md         (*ssl_openssl11_lib* — imports OpenSSL 1.1.x)
|   |-- SSL_OpenSSL3_Lib.md          (*ssl_openssl3_lib* — imports OpenSSL 3.x)
|   |-- SSL_OpenSSL4_Lib.md          (*ssl_openssl4_lib* — imports OpenSSL 4.0, fork CSL)
|   |-- Crypt32.md                   (*Crypt32* — Windows crypt32.dll imports)
|-- Utils/                           (Utilitarios e suporte)
|   |-- SynaUtil.md                  (*synautil* — UTF-8, DateTime, FileTime, base64)
|   |-- SynaCode.md                  (*synacode* — Base64, QP, URL, MD5, HMAC)
|   |-- SynaChar.md                  (*synachar* — character sets e encoding)
|   |-- SynaIp.md                    (*synaip* — parsers IPv4/IPv6)
|   |-- SynaCrypt.md                 (*synacrypt* — DES, 3DES, AES)
|   |-- SynaDbg.md                   (*synadbg* — TSynaDebug trace log)
|   |-- SynaFpc.md                   (*synafpc* — FPC compat shim)
|   |-- SynaIcnv.md                  (*synaicnv* — iconv POSIX)
|   |-- SynaMisc.md                  (*synamisc* — WaitForData, GetIEProxy, ARP)
|   |-- TZUtil.md                    (*tzutil* — timezones Windows)
|-- Protocols/                       (Clientes de protocolo)
|   |-- THTTPSend.md                 (*httpsend* — HTTP client)
|   |-- TSMTPSend.md                 (*smtpsend* — SMTP client)
|   |-- TPOP3Send.md                 (*pop3send* — POP3 client)
|   |-- TIMAPSend.md                 (*imapsend* — IMAP4 client)
|   |-- TFTPSend.md                  (*ftpsend* — FTP client + TFTPList)
|   |-- TTFTPSend.md                 (*ftptsend* — Trivial FTP)
|   |-- TTelnetSend.md               (*tlntsend* — Telnet)
|   |-- TNNTPSend.md                 (*nntpsend* — NNTP/Usenet)
|   |-- TDNSSend.md                  (*dnssend* — DNS queries)
|   |-- TPINGSend.md                 (*pingsend* — ICMP ping)
|   |-- TClamSend.md                 (*clamsend* — ClamAV daemon)
|   |-- TSNMPSend.md                 (*snmpsend* — SNMP v1/v2c/v3)
|   |-- TSNTPSend.md                 (*sntpsend* — SNTP time sync)
|   |-- TSyslogSend.md               (*slogsend* — Syslog RFC 3164)
|-- Mime/                            (MIME e email)
|   |-- TMimeMess.md                 (*mimemess* — email MIME)
|   |-- TMimePart.md                 (*mimepart* — partes MIME)
|   |-- TMessHeader.md               (*mimemess* — headers MIME)
|   |-- MimeInln.md                  (*mimeinln* — inline encoding RFC 2047)
|-- Serial/                          (Porta serie)
|   |-- TBlockSerial.md              (*synaser* — porta serie bloqueante)
|-- Includes/                        (Include files e directivas)
    |-- Jedi-Inc.md                  (*jedi.inc* — defines compilador)
    |-- Synsock-Inc.md               (*sswin32/ssfpc/ssposix/sslinux.inc*)
    |-- LazSynapse.md                (*laz_synapse* — companion Lazarus)
```

---

## Resumo quantitativo

| Categoria | Pastas | Units | Classes/Types | Docs |
|---|---|---|---|---|
| **Core** | `Core/` | 5 (`ldapsend`, `blcksock`, `synsock`, `asn1util`) | 17 classes + 1 enum + 1 record (V1.7.1) | 21 |
| **SSL/TLS** | `SSL/` | 14 (plugins + libs) | 14 | 16 |
| **Utils** | `Utils/` | 10 | ~2 | 10 |
| **Protocols** | `Protocols/` | 14 | ~20 | 14 |
| **Mime** | `Mime/` | 3 | 3 | 4 |
| **Serial** | `Serial/` | 1 | 1 | 1 |
| **Includes** | `Includes/` | 2 (pas) + 8 (.inc) | 0 | 3 |
| **Total** | **7 pastas** | **49 units** | **~60 classes/types** | **~69 docs** |

**V1.7.1 (2026-04-22):** +2 documentos em `Core/` — [TLDAPValueType.md](Core/TLDAPValueType.md) (enum publico + mapa `LDAP_KNOWN_ATTRIBUTE_TYPES` + funcao `ResolveLDAPValueType`) e [TLDAPAttributeValue.md](Core/TLDAPAttributeValue.md) (record publico acessor estilo `TField`). [TLDAPAttribute.md](Core/TLDAPAttribute.md) revisado com as novas properties `ValueType` / `Value` / `Values[Index]` e os campos novos `FValueType` / `FRawValues`. [TLDAPSend.md](Core/TLDAPSend.md) revisado com integracao implicita da tipagem automatica.

---

## Criterios de cobertura

Cada documento `{ClassName}.md` ou `{UnitName}.md` inclui as 7 seccoes padrao:

1. **O que e?** — definicao, papel no package, origem (upstream vs CSL fork).
2. **Caracteristicas** — lista de tracos distintos (cross-compiler, cross-platform, licenca, etc.).
3. **Engine** — directivas `{$IFDEF ...}`, DLLs carregadas em runtime, deps externas.
4. **Funcionalidades** — tabela `Metodo | Assinatura | Descricao` para **todos** os metodos publicos (e privados criticos).
5. **Aplicabilidades** — cenarios reais de uso (ex.: LDAPS com AD WS 2025, FTP Active, HTTPS com mTLS).
6. **Exemplos de uso** — blocos `pascal` com 2-3 exemplos reais e completos (uses, try/except, free).
7. **Relacionamentos** — tabela `Classe/Unit | Tipo de relacao | Descricao` (heranca, composicao, dependencia).

---

## Priorizacao

### 1. Criticas — consumidas por `ActiveDirectoryORM`

- `TLDAPSend` (`ldapsend.pas`)
- `TLDAPAttribute` + `TLDAPValueType` + `TLDAPAttributeValue` (`ldapsend.pas` — V1.7.1 tipagem automatica)
- `TTCPBlockSocket`, `TBlockSocket`, `TCustomSSL` (`blcksock.pas`)
- `TSSLOpenSSL`, `TSSLOpenSSL3`, `TSSLOpenSSL4` (`ssl_openssl*.pas`)
- `TOpenSSLPaths` (`ssl_openssl_paths.pas` — fork CSL)
- `SynaUtil` (`synautil.pas`)
- `Asn1Util` (`asn1util.pas`)

### 2. Importantes — SSL stack completa + utils

- Restantes plugins SSL (11, 4_lib, Capi, CryptLib, LibSSH2, SBB, StreamSec)
- `SynaCode`, `SynaChar`, `SynaIp`, `SynaCrypt`

### 3. Secundarias — Protocolos nao-AD

- HTTP, FTP, SMTP, POP3, IMAP, NNTP, DNS, PING, CLAM, SNMP, SNTP, SLOG, TLNT, TFTP
- MIME (mess, part, inln)
- Serial (synaser)
- Utils auxiliares (SynaDbg, SynaFpc, SynaIcnv, SynaMisc, TZUtil)

### 4. Meta — Includes e packages

- `jedi.inc` (directivas compilador)
- `sswin32.inc`, `ssfpc.inc`, `ssposix.inc`, `sslinux.inc` (sockets por plataforma)
- `laz_synapse.pas` (companion Lazarus)

---

## Cross-referencias

- [../README.md](../README.md) — hub principal da documentacao vendor (visao geral + 3 docs de primeira geracao)
- [../LDAPSend.md](../LDAPSend.md) — analise historica V1 da `TLDAPSend` (pre-sessao V1.5.0+)
- [../TCPBlockSocket.md](../TCPBlockSocket.md) — analise historica V1 de `TTCPBlockSocket`
- [../SSLOpenSSL.md](../SSLOpenSSL.md) — analise historica V1 de `TSSLOpenSSL`
- [../FLOWCHART.md](../FLOWCHART.md) — diagrama Mermaid actual de autenticacao LDAPS+CBT
- [../../VERSION.md](../../VERSION.md) — politica de versionamento do package
- [../../README.md](../../README.md) — README vendor com tabela de divergencias upstream
- [../../bak/](../../bak/) — backups pre-fork CSL historico (13/04/2026)

---

## Relacao com ActiveDirectoryORM

Este package e consumido pelo projecto `ActiveDirectoryORM` V1.5.0+. Mapa de consumo:

```text
ActiveDirectoryORM/
|-- src/ActiveDirectory.Service.pas
|   `-- uses ldapsend, blcksock, ssl_openssl (ou ssl_openssl3/4 via USE_OPENSSL3/4)
|-- src/Commons/ActiveDirectory.Helpers.pas
|   `-- uses synautil (FileTimeToDateTime)
`-- src/Main/ActiveDirectory.Main.pas
    `-- uses (nenhum Synapse directo)
```

A documentacao do ORM consumidor esta em [../../../../Documentation/](../../../../Documentation/).

---

## Changelog (este README)

- **2026-04-21** — Reescrita completa. Placeholder inicial substituido por indice real de 67 docs organizados em 7 categorias (Core, SSL, Utils, Protocols, Mime, Serial, Includes). Vinculo ao novo [VERSION.md](../../VERSION.md) do package.

---

**Status de geracao:** em andamento. Docs serao criados conforme plano V1.5.1+ e requisicao do utilizador (2026-04-21).
