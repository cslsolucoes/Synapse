# FLOWCHART — Synapse CSL fork V41.3

Diagramas Mermaid da arquitectura, heranca, dependencias e fluxos de execucao do package `Packege/synapse/`.

**V1.7.1 (2026-04-22):** adicionados `TLDAPValueType` (enum) e `TLDAPAttributeValue` (record acessor estilo TField) no diagrama de heranca — ver seccao "Heranca / Composicao" abaixo.

**V1.7.2 (2026-04-22):** `TLDAPSend.Search` e `TLDAPSend.DoSearchAD` passam a invocar `TLDAPAttribute.AddRaw` em vez de `Add` no parser ASN.1 interno (callsites ~2157 e ~2330). Os fluxos de Search mostrados a seguir assumem este caminho — bytes ASN.1 fluem do socket directamente para `FRawValues` sem passar por `UnquoteStr` nem conversao implicita `AnsiString -> UnicodeString`.

---

## 1. Arquitectura de alto nivel

```mermaid
graph TD
    App["Aplicacao Consumidora<br/>(ActiveDirectoryORM.Service)"]

    subgraph Protocols["Protocolos (14 units)"]
        LDAP["ldapsend<br/>TLDAPSend"]
        HTTP["httpsend<br/>THTTPSend"]
        SMTP["smtpsend<br/>TSMTPSend"]
        POP3["pop3send<br/>TPOP3Send"]
        IMAP["imapsend<br/>TIMAPSend"]
        FTP["ftpsend<br/>TFTPSend"]
        OUTROS["+9 outros<br/>TFTP/DNS/NNTP/PING/CLAM/SNMP/SNTP/SLOG/TLNT"]
    end

    subgraph Core["Core (TCP + SSL plugin)"]
        BLCK["blcksock<br/>TTCPBlockSocket + TCustomSSL"]
        SYNSOCK["synsock<br/>plataforma-agnostico"]
    end

    subgraph SSL["SSL/TLS Plugins (8)"]
        OSSL["ssl_openssl<br/>TSSLOpenSSL (legacy)"]
        OSSL3["ssl_openssl3<br/>TSSLOpenSSL3"]
        OSSL4["ssl_openssl4 (CSL)<br/>TSSLOpenSSL4"]
        OSSLPATH["ssl_openssl_paths (CSL)<br/>TOpenSSLPaths"]
    end

    subgraph Utils["Utilitarios (10)"]
        SYNAUTIL["synautil<br/>UTF-8+FileTime+DateTime"]
        SYNACODE["synacode<br/>Base64/MD5/HMAC"]
        SYNAIP["synaip<br/>IPv4/IPv6"]
        SYNACRYPT["synacrypt<br/>DES/3DES/AES"]
        ASN1["asn1util<br/>ASN.1 BER"]
    end

    subgraph OS["Sistema Operacional"]
        WSOCK["Winsock<br/>(ws2_32.dll)"]
        POSIX["POSIX sockets<br/>(libc)"]
        SEC32["secur32.dll<br/>SSPI/Kerberos"]
        LIBSSL["libssl*.dll/.so/.dylib<br/>OpenSSL"]
        LIBCR["libcrypto*.dll/.so/.dylib<br/>OpenSSL"]
    end

    App --> Protocols
    Protocols --> BLCK
    BLCK --> SYNSOCK
    SYNSOCK --> WSOCK
    SYNSOCK --> POSIX
    BLCK -.plugin.-> SSL
    LDAP -.uses.-> SYNAUTIL
    LDAP -.uses.-> ASN1
    LDAP -.MSWINDOWS.-> SEC32
    OSSL --> LIBSSL
    OSSL --> LIBCR
    OSSL3 --> LIBSSL
    OSSL3 --> LIBCR
    OSSL4 --> LIBSSL
    OSSL4 --> LIBCR
    OSSLPATH -.SetDllDirectory.-> LIBSSL

    style LDAP fill:#7FBA00,stroke:#4CAF50,color:#fff
    style BLCK fill:#7FBA00,stroke:#4CAF50,color:#fff
    style OSSL4 fill:#FFD700,color:#333
    style OSSLPATH fill:#FFD700,color:#333
    style SEC32 fill:#FFA500,color:#fff
    style LIBSSL fill:#FFA500,color:#fff
    style LIBCR fill:#FFA500,color:#fff
    style App fill:#4A90E2,color:#fff
```

**Legenda:** Verde = Core CSL fork · Amarelo-ouro = Units novas CSL 2026-04-21 · Laranja = DLLs externas dynload · Azul = Aplicacao consumidora.

---

## 2. Hierarquia de heranca (classes)

```mermaid
classDiagram
    TObject <|-- TSynaClient
    TSynaClient <|-- TLDAPSend
    TSynaClient <|-- THTTPSend
    TSynaClient <|-- TSMTPSend
    TSynaClient <|-- TPOP3Send
    TSynaClient <|-- TIMAPSend
    TSynaClient <|-- TFTPSend
    TSynaClient <|-- TDNSSend
    TSynaClient <|-- TPINGSend
    TSynaClient <|-- TSNMPSend
    TSynaClient <|-- TSNTPSend
    TSynaClient <|-- TSyslogSend
    TSynaClient <|-- TTelnetSend
    TSynaClient <|-- TNNTPSend
    TSynaClient <|-- TClamSend
    TSynaClient <|-- TTFTPSend

    TObject <|-- TBlockSocket
    TBlockSocket <|-- TSocksBlockSocket
    TSocksBlockSocket <|-- TTCPBlockSocket
    TSocksBlockSocket <|-- TDgramBlockSocket
    TDgramBlockSocket <|-- TUDPBlockSocket
    TDgramBlockSocket <|-- TICMPBlockSocket
    TBlockSocket <|-- TRAWBlockSocket
    TBlockSocket <|-- TPGMMessageBlockSocket
    TBlockSocket <|-- TPGMStreamBlockSocket

    TObject <|-- TCustomSSL
    TCustomSSL <|-- TSSLNone
    TCustomSSL <|-- TSSLOpenSSL
    TSSLOpenSSL <|-- TSSLOpenSSLCapi
    TCustomSSL <|-- TSSLOpenSSL3
    TCustomSSL <|-- TSSLOpenSSL4
    TCustomSSL <|-- TSSLOpenSSL11
    TCustomSSL <|-- TSSLCryptLib
    TCustomSSL <|-- TSSLLibSSH2
    TCustomSSL <|-- TSSLSBB
    TCustomSSL <|-- TSSLStreamSec

    TStringList <|-- TLDAPAttribute
    TObject <|-- TLDAPAttributeList
    TObject <|-- TLDAPResult
    TObject <|-- TLDAPResultList

    %% V1.7.1 — tipagem automatica de atributos (records/enums sem heranca)
    class TLDAPValueType {
      <<enum>>
      vtUnknown
      vtDirectoryString
      vtIA5String
      vtInteger
      vtBoolean
      vtOctetString
      vtGeneralizedTime
      vtUTCTime
      vtDN
      vtOID
      vtSID
      vtGUID
      vtBitString
      vtNumericString
      vtEnhancedGuide
      vtFileTime
    }
    class TLDAPAttributeValue {
      <<record>>
      +IsNull()
      +AsString()
      +AsInteger()
      +AsFloat()
      +AsBoolean()
      +AsDateTime()
      +AsBinary()
      +AsHex()
      +AsSid()
      +AsGuid()
      +AsVariant()
      +Raw
      +ValueType
    }
    TLDAPAttribute ..> TLDAPValueType : ValueType
    TLDAPAttribute ..> TLDAPAttributeValue : Value / Values[]

    TObject <|-- TMimePart
    TObject <|-- TMimeMess
    TObject <|-- TMessHeader

    TObject <|-- TSynaBlockCipher
    TSynaBlockCipher <|-- TSynaCustomDes
    TSynaCustomDes <|-- TSynaDes
    TSynaCustomDes <|-- TSyna3Des
    TSynaBlockCipher <|-- TSynaAes

    class TLDAPSend {
      +Login()
      +Bind()
      +BindGSSAPI()
      +BindGSSAPIWithCBT()
      +Search()
      +SearchDirSync()
      +Modify()
      +Add()
      +Delete()
    }

    class TTCPBlockSocket {
      +Connect()
      +SSLDoConnect()
      +GetPeerCertSHA256Hash()
    }

    class TSSLOpenSSL4 {
      +Connect()
      +GetPeerCertSHA256Hash()
    }

    class TOpenSSLPaths {
      +Apply(N)
      +Resolve()
      +SetCustomPath()
    }
```

---

## 3. Fluxo LDAPS com GSSAPI + Channel Binding Token (Windows)

```mermaid
sequenceDiagram
    actor User
    participant App as ActiveDirectoryORM
    participant LDAP as TLDAPSend
    participant Sock as TTCPBlockSocket
    participant SSL as TSSLOpenSSL4
    participant Paths as TOpenSSLPaths
    participant SSPI as secur32.dll
    participant DC as Controlador AD<br/>LDAPS:636

    User->>App: Authenticate(user, pwd)
    App->>Paths: Apply(4) [initialization]
    Paths-->>Paths: SetDllDirectory(<exe>/dll/v4/<arch>)

    App->>LDAP: TLDAPSend.Create
    LDAP->>Sock: Create (SSLImplementation = TSSLOpenSSL4)
    App->>LDAP: TargetHost = 'dc.corp.com'
    App->>LDAP: FullSSL = True
    App->>LDAP: Login

    LDAP->>Sock: Connect(dc.corp.com, 636)
    Sock->>Sock: SNIHost = 'dc.corp.com'
    Sock->>Sock: VerifyCert = True

    Sock->>SSL: SSLDoConnect
    SSL->>DC: TLS ClientHello (SNI)
    DC->>SSL: TLS ServerHello + ServerCert
    SSL->>SSL: Verify peer cert (CA trust)
    SSL->>SSL: GetPeerCertSHA256Hash() = 32 bytes CBT

    LDAP->>LDAP: BindGSSAPIWithCBT(SPN, CBT)
    LDAP->>SSPI: LoadLibrary('secur32.dll')
    LDAP->>SSPI: AcquireCredentialsHandle
    LDAP->>SSPI: InitializeSecurityContext(CBT)
    SSPI-->>LDAP: SASL token (Kerberos + CBT)

    LDAP->>DC: LDAP BindRequest (SASL GSSAPI + token+CBT)
    DC->>DC: Validate Kerberos ticket + CBT match peer cert
    DC->>LDAP: LDAP BindResponse (success)

    LDAP-->>App: Sessao LDAPS ativa
    App->>LDAP: Search(filter)
    LDAP->>DC: LDAP SearchRequest
    DC->>LDAP: SearchResultEntry (User attrs)
    LDAP-->>App: TLDAPResultList
    App-->>User: Autorizado
```

---

## 4. Fluxo LDAP simple bind (POSIX — sem GSSAPI real ate V2.0.0)

```mermaid
sequenceDiagram
    actor User
    participant App as ActiveDirectoryORM
    participant LDAP as TLDAPSend
    participant Sock as TTCPBlockSocket
    participant SSL as TSSLOpenSSL4
    participant DC as Controlador AD<br/>LDAPS:636

    User->>App: Authenticate(user, pwd)
    App->>LDAP: TLDAPSend.Create
    LDAP->>Sock: Create
    App->>LDAP: FullSSL = True
    App->>LDAP: Username = user
    App->>LDAP: Password = pwd
    App->>LDAP: Login

    LDAP->>Sock: Connect(dc.corp.com, 636)
    Sock->>SSL: SSLDoConnect
    SSL->>DC: TLS handshake
    DC-->>SSL: Handshake OK

    LDAP->>LDAP: Bind (simple)
    LDAP->>DC: LDAP BindRequest (simple, user+pwd)
    DC->>LDAP: BindResponse (success)

    note over LDAP,SSPI: Em POSIX, BindGSSAPI retorna False<br/>e emite mensagem:<br/>"GSSAPI via SSPI nao disponivel em POSIX<br/>-- use Kerberos via libgssapi_krb5<br/>(agendado V2.0.0)"

    LDAP-->>App: Sessao LDAPS ativa
    App->>LDAP: Search(filter)
    LDAP->>DC: SearchRequest
    DC->>LDAP: SearchResultEntry
    LDAP-->>App: TLDAPResultList
```

---

## 5. Fluxo de decisao SSL plugin (compile-time)

```mermaid
flowchart TD
    Start([Consumidor define em .cfg/.opts])
    DefUSE3{USE_OPENSSL3<br/>definido?}
    DefUSE4{USE_OPENSSL4<br/>definido?}
    Legacy[ssl_openssl.pas<br/>libeay32/ssleay32<br/>0.9.7 - 1.1.x]
    V3[ssl_openssl3.pas<br/>libcrypto-3/libssl-3<br/>OpenSSL 3.x]
    V4[ssl_openssl4.pas<br/>libcrypto-4/libssl-4<br/>OpenSSL 4.0]
    Fatal[MESSAGE FATAL<br/>USE_OPENSSL3 + USE_OPENSSL4<br/>mutuamente exclusivos]
    Paths[TOpenSSLPaths.Apply&lt;N&gt;<br/>no initialization]
    App[TLDAPSend usa SSLImplementation]

    Start --> DefUSE3
    DefUSE3 -- sim --> DefUSE4
    DefUSE4 -- sim --> Fatal
    DefUSE4 -- nao --> V3
    DefUSE3 -- nao --> DefUSE4
    DefUSE4 -- sim --> V4
    DefUSE4 -- nao --> Legacy
    V3 -.initialization.-> Paths
    V4 -.initialization.-> Paths
    Paths --> App
    V3 --> App
    V4 --> App
    Legacy --> App

    style Fatal fill:#FF6B6B,color:#fff
    style V4 fill:#FFD700,color:#333
    style Paths fill:#FFD700,color:#333
```

---

## 6. Fluxo de directivas de plataforma (synsock)

```mermaid
flowchart TD
    Start([synsock.pas])
    C1{MSWINDOWS?}
    C2{FPC?}
    C3{POSIX<br/>Delphi?}

    Win[sswin32.inc<br/>Winsock ws2_32.dll]
    FPC[ssfpc.inc<br/>POSIX sockets FPC<br/>Linux/macOS/BSD]
    Dposix[ssposix.inc<br/>POSIX Delphi<br/>LINUX64/macOS64]
    Linux[sslinux.inc<br/>Delphi Linux legacy]

    Start --> C1
    C1 -- sim --> Win
    C1 -- nao --> C2
    C2 -- sim --> FPC
    C2 -- nao --> C3
    C3 -- sim --> Dposix
    C3 -- nao --> Linux

    style Win fill:#4A90E2,color:#fff
    style FPC fill:#7FBA00,color:#fff
    style Dposix fill:#7FBA00,color:#fff
```

---

## 7. Fluxo de SSPI/GSSAPI em `ldapsend.pas` (V1.7.0 guardado)

```mermaid
flowchart TD
    Start([uses ldapsend])
    W{MSWINDOWS?}

    SSPI[Bloco SSPI real<br/>6 blocos envolvidos<br/>B1: consts ISC_REQ_*/SECBUFFER_*/SEC_E_*<br/>B2: types TLDAPSecHandle/TLDAPSecBuffer<br/>B3: private fields FSSPICred/FSSPICtx<br/>B4: private methods<br/>B5: global var FLDAPSecur32Lib + 7 funcs<br/>B6: implementacoes]

    Stubs[4 stubs POSIX<br/>BindGSSAPI: False<br/>BindGSSAPIWithCBT: False<br/>SignLDAPMessage: no-op<br/>VerifyLDAPMessage: True]

    MsgV20[FResultString:<br/>'GSSAPI via SSPI nao disponivel<br/>em POSIX -- use Kerberos via<br/>libgssapi_krb5 (agendado V2.0.0)']

    Start --> W
    W -- sim --> SSPI
    W -- nao --> Stubs
    Stubs --> MsgV20

    style SSPI fill:#4A90E2,color:#fff
    style Stubs fill:#FFA500,color:#fff
    style MsgV20 fill:#FFD700,color:#333
```

---

## 8. Dependencias entre units Synapse

```mermaid
graph BT
    SYNSOCK[synsock]
    SYNAUTIL[synautil]
    SYNACODE[synacode]
    SYNACHAR[synachar]
    SYNAIP[synaip]
    ASN1[asn1util]
    SYNAFPC[synafpc]

    BLCK[blcksock]
    LDAP[ldapsend]
    HTTP[httpsend]
    SMTP[smtpsend]
    POP3[pop3send]
    IMAP[imapsend]
    FTP[ftpsend]
    DNS[dnssend]
    OUTROS[...14 protocolos]

    OSSL[ssl_openssl]
    OSSL3[ssl_openssl3]
    OSSL4[ssl_openssl4]
    OSSLPATH[ssl_openssl_paths]
    OSSLLIB[ssl_openssl_lib]
    OSSL3LIB[ssl_openssl3_lib]
    OSSL4LIB[ssl_openssl4_lib]

    MIMEMSS[mimemess]
    MIMEPART[mimepart]
    MIMEINLN[mimeinln]

    SYNSOCK --> BLCK
    SYNAUTIL --> BLCK
    SYNAUTIL --> LDAP
    SYNAUTIL --> HTTP
    SYNACODE --> SYNAUTIL
    SYNACHAR --> MIMEINLN
    SYNAIP --> BLCK
    SYNAFPC --> SYNSOCK
    ASN1 --> LDAP
    ASN1 --> SMTP

    BLCK --> LDAP
    BLCK --> HTTP
    BLCK --> SMTP
    BLCK --> POP3
    BLCK --> IMAP
    BLCK --> FTP
    BLCK --> DNS
    BLCK --> OUTROS

    OSSLLIB --> OSSL
    OSSL3LIB --> OSSL3
    OSSL4LIB --> OSSL4
    OSSL -.plugin.-> BLCK
    OSSL3 -.plugin.-> BLCK
    OSSL4 -.plugin.-> BLCK
    OSSLPATH -.initialization.-> OSSL3
    OSSLPATH -.initialization.-> OSSL4

    MIMEPART --> MIMEMSS
    MIMEINLN --> MIMEMSS
    MIMEMSS --> SMTP
    MIMEMSS --> POP3

    style LDAP fill:#7FBA00,color:#fff
    style BLCK fill:#7FBA00,color:#fff
    style OSSL4 fill:#FFD700,color:#333
    style OSSLPATH fill:#FFD700,color:#333
    style SYNAUTIL fill:#4A90E2,color:#fff
```

---

## 9. Matriz plataforma x chain de includes

```mermaid
graph LR
    P1[Windows Win32 Delphi] --> I1[sswin32.inc]
    P2[Windows Win64 Delphi] --> I1
    P3[Windows Win32 FPC] --> I1
    P4[Windows Win64 FPC] --> I1
    P5[Linux x86_64 FPC] --> I2[ssfpc.inc]
    P6[Linux ARM64 FPC] --> I2
    P7[FreeBSD FPC] --> I2
    P8[macOS Intel FPC] --> I2
    P9[macOS Apple Silicon FPC] --> I2
    P10[Delphi LINUX64] --> I3[ssposix.inc]
    P11[Delphi macOS64 Intel] --> I3
    P12[Delphi macOS64 Apple Silicon] --> I3
    P13[Delphi Linux legacy] --> I4[sslinux.inc]

    I1 --> API1[Winsock<br/>ws2_32.dll]
    I2 --> API2[POSIX sockets<br/>libc]
    I3 --> API2
    I4 --> API2

    style I1 fill:#4A90E2,color:#fff
    style I2 fill:#7FBA00,color:#fff
    style I3 fill:#7FBA00,color:#fff
```

---

## 10. Estado do fork CSL (camadas cumulativas)

```mermaid
gantt
    title Fork CSL -- historico de modificacoes
    dateFormat YYYY-MM-DD
    axisFormat %Y-%m

    section Upstream
    Gebauer 1999-2023 (41.0) :done, up, 1999-01-01, 8030d

    section Fork CSL historico
    ldapsend SSPI+CBT+AD controls :done, hist1, 2026-04-13, 1d
    blcksock GetPeerCertSHA256Hash :done, hist2, 2026-04-13, 1d
    synautil FileTime helpers :done, hist3, 2026-04-13, 1d
    jedi.inc reescrita :done, hist4, 2026-04-13, 1d

    section Fork CSL 2026-04-21
    ssl_openssl4 (V41.1) :active, csl1, 2026-04-21, 1d
    ssl_openssl_paths (V41.1) :active, csl2, 2026-04-21, 1d
    ldapsend POSIX patch (V1.7.0) :active, csl3, 2026-04-21, 1d
    synapse.dpk novo :active, csl4, 2026-04-21, 1d

    section V2.0.0 agendado
    libgssapi_krb5 real :crit, v2, 2026-05-01, 14d
```

---

## 11. Mapa de acronimos

| Sigla | Significado |
|---|---|
| **CBT** | Channel Binding Token (RFC 5929 — ligacao LDAP a certificado TLS) |
| **SPN** | Service Principal Name (formato `ldap/dc.corp.com`) |
| **SSPI** | Security Support Provider Interface (API Microsoft em `secur32.dll`) |
| **GSSAPI** | Generic Security Services API (padrao RFC 2743 — Kerberos em POSIX) |
| **SASL** | Simple Authentication and Security Layer (RFC 4422) |
| **LDAP** | Lightweight Directory Access Protocol (RFC 4511) |
| **LDAPS** | LDAP over TLS (porta 636) |
| **SDFlags** | Security Descriptor Flags (controle AD OWNER/GROUP/DACL/SACL) |
| **DirSync** | Directory Synchronization (controle AD para replicacao incremental) |
| **mTLS** | mutual TLS (autenticacao cliente + servidor via certificados) |
| **SNI** | Server Name Indication (extensao TLS RFC 6066) |
| **PDU** | Protocol Data Unit (unidade de dados do protocolo LDAP) |
| **UAC** | User Account Control (atributo AD `userAccountControl`) |

---

**Gerado:** 2026-04-21 (DocAgent reverse-engineering V2)
**Revisao:** CSL fork V41.3 / ADORM V1.7.2
**Source files analisados:** 50 `.pas` + 8 `.inc` + 2 packages (.lpk + .dpk)
