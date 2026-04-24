# Synapse Ararat — Arquitetura e Diagramas de Fluxo

## Diagrama 1: Arquitetura Geral do Pacote

```mermaid
graph TD
    App["Aplicação<br/>(M01LdapAuthenticator)"]
    
    subgraph Synapse["Synapse Ararat"]
        LDAP["TLDAPSend<br/>(ldapsend.pas)<br/>LDAP v2/v3 Client"]
        Sock["TTCPBlockSocket<br/>(blcksock.pas)<br/>TCP Socket Blocking"]
        SSL["TSSLOpenSSL<br/>(ssl_openssl.pas)<br/>OpenSSL Plugin"]
    end
    
    subgraph ExtDeps["Dependências Externas (DLL dinâmicas)"]
        Sec32["secur32.dll<br/>(SSPI/Kerberos)"]
        LibSSL["libssl.dll<br/>(OpenSSL)"]
        LibCrypto["libcrypto.dll<br/>(OpenSSL)"]
    end
    
    subgraph AD["Active Directory"]
        DC["Controlador de Domínio<br/>(LDAPS :636)"]
    end
    
    subgraph AppLayers["Aplicação GestorERP"]
        OBACService["OBACService<br/>(Application.Seguranca)<br/>Autorização (OBAC)"]
    end
    
    App -->|consome TLDAPSend| LDAP
    LDAP -->|usa transporte| Sock
    Sock -->|plugin TLS| SSL
    LDAP -->|carrega dinamicamente| Sec32
    Sock -->|SNI + mTLS| DC
    SSL -->|usa| LibSSL
    SSL -->|usa| LibCrypto
    OBACService -->|pós-autenticação| App
    
    style App fill:#4A90E2,stroke:#2E5C8A,color:#fff
    style LDAP fill:#7FBA00,stroke:#4CAF50,color:#fff
    style Sock fill:#7FBA00,stroke:#4CAF50,color:#fff
    style SSL fill:#7FBA00,stroke:#4CAF50,color:#fff
    style OBACService fill:#FF6B35,stroke:#C85A1A,color:#fff
    style DC fill:#00A4EF,stroke:#0078D4,color:#fff
    style Sec32 fill:#FFA500,stroke:#CC8800,color:#fff
    style LibSSL fill:#FFA500,stroke:#CC8800,color:#fff
    style LibCrypto fill:#FFA500,stroke:#CC8800,color:#fff
```

**Legenda:**
- **Azul**: Aplicação consumidora
- **Verde**: Componentes Synapse (fork GestorERP)
- **Laranja**: Dependências externas (carregadas dinamicamente em runtime)
- **Vermelho-laranja**: Serviço de autorização pós-autenticação
- **Azul-escuro**: Servidor de destino (Active Directory)

---

## Diagrama 2: Fluxo de Autenticação Kerberos com CBT

```mermaid
graph LR
    A["M01LdapAuthenticator<br/>Authenticate()"]
    
    B["TLDAPSend<br/>Login()"]
    
    C["TTCPBlockSocket<br/>Connect:636"]
    
    D["TSSLOpenSSL<br/>TLS Handshake"]
    
    E["TSSLOpenSSL<br/>GetPeerCertSHA256Hash"]
    
    F["SASL GSSAPI<br/>BindGSSAPIWithCBT"]
    
    G["secur32.dll<br/>InitializeSecurityContext<br/>+ CBT"]
    
    H["AD Controlador<br/>Kerberos Verify"]
    
    I["Sessão LDAP<br/>Ativa"]
    
    J["M01LdapAuthenticator<br/>GetUser()"]
    
    A --> B
    B --> C
    C --> D
    D --> E
    E -->|SHA256 peer cert<br/>32 bytes| F
    F --> G
    G -->|SASL Token<br/>+ CBT| H
    H -->|mTLS + Kerberos<br/>OK| I
    I --> J
    
    style A fill:#4A90E2,color:#fff
    style B fill:#7FBA00,color:#fff
    style C fill:#7FBA00,color:#fff
    style D fill:#7FBA00,color:#fff
    style E fill:#7FBA00,color:#fff
    style F fill:#7FBA00,color:#fff
    style G fill:#FFA500,color:#fff
    style H fill:#00A4EF,color:#fff
    style I fill:#4CAF50,color:#fff
    style J fill:#FF6B35,color:#fff
```

**Fluxo de autenticação:**
1. Aplicação chama `M01LdapAuthenticator.Authenticate(username, password)`
2. `TLDAPSend.Login()` conecta ao servidor LDAPS (porta 636)
3. `TTCPBlockSocket` estabelece conexão TCP e inicia `TLS Handshake`
4. `TSSLOpenSSL` executa handshake TLS e obtém certificado do servidor
5. `GetPeerCertSHA256Hash()` extrai hash SHA-256 do certificado (32 bytes) → Channel Binding Token
6. `BindGSSAPIWithCBT()` envia token SASL GSSAPI com CBT
7. `secur32.dll` valida CBT e token Kerberos com `InitializeSecurityContext`
8. Controlador de domínio verifica credenciais Kerberos + CBT (prova de identidade do servidor)
9. Autenticação bem-sucedida → sessão LDAP ativa
10. `GetUser()` consulta atributos do usuário (memberOf, samAccountName, etc.)

---

## Diagrama 3: Hierarquia de Tipos (Herança)

```mermaid
graph LR
    TSynaClient["TSynaClient<br/>(base Synapse)"]
    
    TLDAPSend["TLDAPSend<br/>(ldapsend.pas)<br/>LDAP v2/v3"]
    
    TBlockSocket["TBlockSocket<br/>(base Synapse)"]
    
    TSocksBlockSocket["TSocksBlockSocket<br/>(SOCKS support)"]
    
    TTCPBlockSocket["TTCPBlockSocket<br/>(blcksock.pas)<br/>TCP + SSL/TLS"]
    
    TCustomSSL["TCustomSSL<br/>(interface plugin)"]
    
    TSSLOpenSSL["TSSLOpenSSL<br/>(ssl_openssl.pas)<br/>OpenSSL impl"]
    
    TSSLOpenSSL3["TSSLOpenSSL3<br/>(ssl_openssl3.pas)<br/>OpenSSL 3.x"]
    
    TSynaClient --> TLDAPSend
    TBlockSocket --> TSocksBlockSocket
    TSocksBlockSocket --> TTCPBlockSocket
    TCustomSSL --> TSSLOpenSSL
    TCustomSSL --> TSSLOpenSSL3
    
    TTCPBlockSocket -.->|instancia| TCustomSSL
    TLDAPSend -.->|acessa via| TTCPBlockSocket
    
    style TLDAPSend fill:#7FBA00,color:#fff
    style TTCPBlockSocket fill:#7FBA00,color:#fff
    style TSSLOpenSSL fill:#7FBA00,color:#fff
    style TSSLOpenSSL3 fill:#FFD700,color:#333
    style TSynaClient fill:#CCCCCC,color:#333
    style TBlockSocket fill:#CCCCCC,color:#333
    style TSocksBlockSocket fill:#CCCCCC,color:#333
    style TCustomSSL fill:#CCCCCC,color:#333
```

**Notas:**
- **Verde**: Classes fork GestorERP (estendidas/novas)
- **Ouro**: Alternativas compatíveis (ssl_openssl3 para OpenSSL 3.x)
- **Cinza**: Classes base Synapse (upstream, não modificadas)
- **Linhas tracejadas**: Composição/instanciação (não herança direta)

---

## Diagrama 4: Dependências Entre Módulos

```mermaid
graph TB
    subgraph App["Aplicação"]
        M01LDAP["M01LdapAuthenticator<br/>(Infrastructure.Integrations.AD)"]
        OBAC["OBACService<br/>(Application.Seguranca)"]
    end
    
    subgraph Synapse["Synapse Ararat (fork GestorERP v001.007.002)"]
        LDAP["TLDAPSend<br/>(ldapsend.pas)"]
        SOCK["TTCPBlockSocket<br/>(blcksock.pas)"]
        SSL["TSSLOpenSSL<br/>(ssl_openssl.pas)"]
        SSLLIB["ssl_openssl_lib.pas<br/>(FFI OpenSSL)"]
    end
    
    subgraph OS["Sistema Operacional"]
        SSPI["secur32.dll<br/>(SSPI/Kerberos)"]
        OPENSSL["libssl.dll +<br/>libcrypto.dll<br/>(OpenSSL)"]
    end
    
    subgraph AD["Serviço de Rede"]
        DC["Active Directory<br/>Controlador de Domínio<br/>LDAPS :636"]
    end
    
    M01LDAP -->|consome| LDAP
    LDAP -->|transporte| SOCK
    SOCK -->|plugin TLS| SSL
    SSL -->|FFI| SSLLIB
    SSLLIB -->|carrega dinamicamente| OPENSSL
    LDAP -->|carrega dinamicamente| SSPI
    SOCK -->|TCP/mTLS| DC
    OBAC -->|pós-auth| M01LDAP
    
    style M01LDAP fill:#4A90E2,color:#fff
    style OBAC fill:#FF6B35,color:#fff
    style LDAP fill:#7FBA00,color:#fff
    style SOCK fill:#7FBA00,color:#fff
    style SSL fill:#7FBA00,color:#fff
    style SSLLIB fill:#7FBA00,color:#fff
    style SSPI fill:#FFA500,color:#fff
    style OPENSSL fill:#FFA500,color:#fff
    style DC fill:#00A4EF,color:#fff
```

**Legenda:**
- **Setas sólidas** (→): dependência direta (importação, chamada de método)
- **Linhas pontilhadas** (-.->): dependência indireta (composição, plugin)
- **Azul**: Aplicação
- **Verde**: Synapse (componentes fork)
- **Laranja**: Dependências externas (SO — DLL dinâmicas)
- **Azul-escuro**: Recurso de rede (servidor AD)

---

## Diagrama 5: Ciclo de Vida de Conexão LDAPS com CBT

```mermaid
sequenceDiagram
    actor User
    participant App as Aplicação<br/>(M01LdapAuthenticator)
    participant LDAP as TLDAPSend
    participant Sock as TTCPBlockSocket
    participant SSL as TSSLOpenSSL
    participant DC as Controlador<br/>de Domínio
    participant SSPI as secur32.dll<br/>(SSPI)

    User->>App: Authenticate(username, password)
    App->>LDAP: Login(server, user, pwd, SNIHost, CertCAFile)
    
    LDAP->>Sock: Create + Configure
    Sock->>Sock: SNIHost := 'dc.example.com'
    Sock->>Sock: VerifyCert := True
    Sock->>Sock: SSLImplementation := TSSLOpenSSL
    
    Sock->>Sock: Connect(server, 636)
    Sock->>DC: TCP SYN
    DC->>Sock: TCP SYN-ACK
    
    Sock->>SSL: SSLDoConnect()
    SSL->>SSL: TLS ClientHello (SNI = dc.example.com)
    SSL->>DC: TLS ClientHello
    DC->>SSL: TLS ServerHello + ServerCert
    
    SSL->>SSL: Verify peer cert (CA file)
    SSL->>SSL: GetPeerCertSHA256Hash() → CBT (32 bytes)
    
    SSL->>SSL: TLS Finished
    SSL->>DC: TLS Finished
    note over Sock,SSL: TLS 1.2+ channel established (mTLS ready)
    
    LDAP->>LDAP: BindGSSAPIWithCBT(username, CBT)
    LDAP->>SSPI: InitializeSecurityContext(realm, CBT, token)
    SSPI->>SSPI: Kerberos ticket + CBT validation
    
    LDAP->>DC: LDAP BindRequest (SASL GSSAPI + CBT)
    DC->>DC: Verify: Kerberos ticket + CBT match server cert
    DC->>LDAP: LDAP BindResponse (success)
    
    LDAP->>App: SessionActive := True
    App->>LDAP: Search(filter, basedn)
    LDAP->>DC: LDAP SearchRequest
    DC->>LDAP: LDAP SearchResponse (user attributes)
    
    App->>App: User authenticated + authorized
    note over App: M01LdapAuthenticator.GetUser() ready
    
    User->>User: Access granted
```

---

## Diagrama 6: Controles LDAP AD (Suporte no Fork)

```mermaid
graph TB
    LDAP["TLDAPSend<br/>(ldapsend.pas)"]
    
    subgraph Controls["Controles AD Suportados"]
        DIRSYNC["DirSync Control<br/>(1.2.840.113556.1.4.417)<br/>Sincronização incremental"]
        SDFLAGS["SDFlags Control<br/>(1.2.840.113556.1.4.801)<br/>Security descriptors"]
        EXTDN["ExtendedDN Control<br/>(1.2.840.113556.1.4.529)<br/>GUID + SID"]
        SHOWDEL["ShowDeleted Control<br/>(1.2.840.113556.1.4.417)<br/>Objetos deletados (AD recycle bin)"]
        SHOWREC["ShowRecycled Control<br/>(1.2.840.113556.1.4.2064)<br/>Lixeira AD"]
        SORT["ServerSort Control<br/>(1.2.840.113556.1.4.474)<br/>Ordenação servidor"]
        PERMMOD["Permissive Modify<br/>(1.2.840.113556.1.4.1781)<br/>Modificações sem erro de entrada duplicada"]
        TREEDEL["TreeDelete Control<br/>(1.2.840.113556.1.4.1867)<br/>Delete recursivo de subtree"]
    end
    
    subgraph Ops["Operações de Senha AD"]
        PWDCHANGE["ChangePassword<br/>(Bind + old pwd)"]
        PWDRESET["ResetPassword<br/>(Admin only, sem verificação old)"]
        PWDEXPIRE["SetExpirePassword<br/>(pwdLastSet := 0)"]
        PWDUNLOCK["UnlockAccount<br/>(lockoutTime := 0)"]
        PWDPROMPT["SetPromptOnLogon<br/>(forceChangePassword := True)"]
    end
    
    subgraph Sec["Segurança e Assinatura"]
        LDAPSIGN["LDAP Signing (RFC 4757)<br/>HMAC-MD5 de cada PDU"]
        CBT["Channel Binding Token (RFC 5929)<br/>tls-server-end-point:<br/>SHA256(peer cert DER)"]
    end
    
    LDAP --> Controls
    LDAP --> Ops
    LDAP --> Sec
    
    style LDAP fill:#7FBA00,color:#fff
    style DIRSYNC fill:#FF9999,color:#fff
    style SDFLAGS fill:#FF9999,color:#fff
    style EXTDN fill:#FF9999,color:#fff
    style SHOWDEL fill:#FF9999,color:#fff
    style SHOWREC fill:#FF9999,color:#fff
    style SORT fill:#FF9999,color:#fff
    style PERMMOD fill:#FF9999,color:#fff
    style TREEDEL fill:#FF9999,color:#fff
    style PWDCHANGE fill:#99CCFF,color:#333
    style PWDRESET fill:#99CCFF,color:#333
    style PWDEXPIRE fill:#99CCFF,color:#333
    style PWDUNLOCK fill:#99CCFF,color:#333
    style PWDPROMPT fill:#99CCFF,color:#333
    style LDAPSIGN fill:#FFD700,color:#333
    style CBT fill:#FFD700,color:#333
```

---

## Diagrama 7: Stack de Camadas TLS/LDAPS

```mermaid
graph TB
    App["Aplicação<br/>(M01LdapAuthenticator)"]
    
    LDAP["Camada LDAP<br/>TLDAPSend<br/>(RFC 4511)"]
    
    SASL["Camada SASL<br/>GSSAPI / Kerberos<br/>(RFC 2478)"]
    
    CRYPTO["Camada Criptografia<br/>HMAC-MD5 (LDAP Signing)<br/>AES-128-CBC (Kerberos sealing)"]
    
    TLS["Camada TLS<br/>TSSLOpenSSL<br/>(TLS 1.2, RFC 5246)"]
    
    CBT["Channel Binding Token<br/>SHA-256(peer cert DER)<br/>(RFC 5929)"]
    
    TCP["Camada TCP<br/>TTCPBlockSocket<br/>LDAPS :636"]
    
    DC["Active Directory<br/>Controlador de Domínio"]
    
    App --> LDAP
    LDAP --> SASL
    SASL --> CRYPTO
    CRYPTO --> TLS
    TLS --> CBT
    CBT --> TCP
    TCP --> DC
    
    style App fill:#4A90E2,color:#fff
    style LDAP fill:#7FBA00,color:#fff
    style SASL fill:#FF9999,color:#fff
    style CRYPTO fill:#FFD700,color:#333
    style TLS fill:#7FBA00,color:#fff
    style CBT fill:#FF9999,color:#fff
    style TCP fill:#7FBA00,color:#fff
    style DC fill:#00A4EF,color:#fff
```

---

## Tabela de Métodos Principais

### TLDAPSend

| Método | Descrição | Retorno |
| --- | --- | --- |
| `Login(Host, Port, User, Pass, UseSSL)` | Conecta e autentica ao servidor LDAP/LDAPS | Boolean |
| `BindGSSAPI(User)` | Bind SASL GSSAPI com Kerberos (sem CBT) | Boolean |
| `BindGSSAPIWithCBT(User, CBT)` | Bind SASL GSSAPI + Channel Binding Token | Boolean |
| `Search(Filter, BaseDN, Attributes)` | Busca LDAP com filtro e atributos | TStringList |
| `AddUser(DN, Attributes)` | Cria novo usuário (objectClass=user) | Boolean |
| `DeleteObject(DN)` | Remove objeto LDAP | Boolean |
| `Modify(DN, Attributes)` | Modifica atributos de objeto | Boolean |
| `ModifyPassword(DN, OldPwd, NewPwd)` | Muda senha (com verificação old) | Boolean |
| `ResetPassword(DN, NewPwd)` | Reseta senha (admin, sem verificação) | Boolean |
| `FileTimeToDateTime(FileTime)` | Converte FileTime AD → TDateTime | TDateTime |
| `DateTimeToFileTime(DT)` | Converte TDateTime → FileTime AD | Int64 |

### TTCPBlockSocket

| Propriedade | Descrição | Tipo |
| --- | --- | --- |
| `SNIHost` | Server Name Indication para TLS (obrigatório para mTLS) | String |
| `CertCAFile` | Caminho do arquivo .crt/pem com CA root | String |
| `VerifyCert` | Se True, valida certificado do servidor | Boolean |
| `NonBlockMode` | Se True, socket opera em modo não-bloqueante | Boolean |
| `Timeout` | Tempo máximo de espera (ms) para operações I/O | Integer |

### TSSLOpenSSL

| Método | Descrição | Retorno |
| --- | --- | --- |
| `GetPeerCertSHA256Hash()` | Retorna hash SHA-256 do certificado do servidor (32 bytes raw) | TBytes |
| `GetPeerCertSubject()` | Retorna DN do subject do certificado | String |
| `GetPeerCertIssuer()` | Retorna DN do issuer do certificado | String |
| `GetPeerCertExpireDate()` | Retorna data de expiração | TDateTime |

---

## Fluxo de Inicialização (Bootstrap)

```
1. Aplicação chama M01LdapAuthenticator.Create()
   └─ Inicializa TLDAPSend com parâmetros (server, port, basedn)
   
2. Authenticate() é chamado
   └─ TLDAPSend.Login(server, port, user, pass, useSSL=True)
      ├─ TTCPBlockSocket.Create()
      ├─ TTCPBlockSocket.Connect(server, 636)
      └─ TTCPBlockSocket.SSLImplementation := TSSLOpenSSL
         └─ Carrega TSSLOpenSSL
            ├─ Carrega libssl.dll (LoadLibrary)
            ├─ Carrega libcrypto.dll (LoadLibrary)
            └─ TLS Handshake (ClientHello, ServerHello, Certificate, Finished)
      
      Após TLS bem-sucedido:
      ├─ TSSLOpenSSL.GetPeerCertSHA256Hash() → CBT (32 bytes)
      └─ TLDAPSend.BindGSSAPIWithCBT(user, CBT)
         ├─ Carrega secur32.dll (LoadLibrary)
         ├─ Chama InitializeSecurityContext (SSPI)
         ├─ Envia LDAP BindRequest (SASL GSSAPI + CBT)
         └─ Recebe LDAP BindResponse (sucesso ou erro)

3. Se Login retorna True
   └─ M01LdapAuthenticator.GetUser(username) executa busca LDAP
      └─ Retorna IActiveDirectoryUser com atributos

4. OBACService.Check(User, Object, Operation) aplica OBAC
   └─ Autorização finalizada
```

---

## Relatório de Validação

- **Total de documentos indexados:** 3 classes (TLDAPSend, TTCPBlockSocket, TSSLOpenSSL)
- **Módulos cobertos:** LDAP, Socket, SSL/TLS
- **Links validados:** 100% (3/3 arquivos .md existentes)
- **Diagramas Mermaid:** 7 (Arquitetura, Autenticação, Hierarquia, Dependências, Ciclo de vida, Controles, Stack de camadas)
- **Broken links:** 0
- **Syntax errors Mermaid:** 0

---

**Gerado:** 2026-04-13
**Por:** Documentation Agent — Class Indexer v1.0.1
