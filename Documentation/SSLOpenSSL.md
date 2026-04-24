# SSLOpenSSL

**Unit:** `ssl_openssl.pas` | **Versao Synapse:** 001.004.001 (fork GestorERP) | **Tipo:** Classe

> Nota: Esta unit e declarada como `deprecated` no Delphi com suporte a `SUPPORTS_DEPRECATED`, com mensagem sugerindo `ssl_openssl3` para OpenSSL 3.0+. No contexto GestorERP ela e referenciada pela extensao de Channel Binding Token; para producao com OpenSSL 3.x, prefira `ssl_openssl3.pas` (que deve receber a mesma extensao `GetPeerCertSHA256Hash`).

---

## 1. O que e?

`TSSLOpenSSL` e o plugin SSL/TLS da biblioteca Ararat Synapse que implementa a interface `TCustomSSL` usando a biblioteca OpenSSL carregada dinamicamente em runtime. Uma instancia e criada automaticamente para cada `TTCPBlockSocket` quando o plugin esta registrado via `SSLImplementation`.

O fork GestorERP v001.007.002 adiciona o metodo `GetPeerCertSHA256Hash`, que retorna os 32 bytes raw do hash SHA-256 do certificado DER do servidor. Esse valor e o insumo obrigatorio para construir o Channel Binding Token `tls-server-end-point` (RFC 5929) usado por `TLDAPSend.BindGSSAPIWithCBT`, tornando o bind Kerberos resistente a ataques man-in-the-middle mesmo sobre LDAPS.

---

## 2. Caracteristicas

- **Carregamento dinamico de OpenSSL**: as DLLs `libssl` e `libcrypto` sao carregadas via `LoadLibrary` em runtime — a aplicacao compila e inicializa sem as DLLs presentes; SSL simplesmente nao funciona se elas estiverem ausentes.
- **Multi-versao OpenSSL**: compativel com 0.9.7 a 1.0.0 (comprovado), 1.1.0 (testado) e 1.1.x; para OpenSSL 3.x usar `ssl_openssl3.pas`.
- **Auto-certificado Ad-Hoc**: servidores TLS sem certificado configurado tem um par chave/certificado autoassinado gerado automaticamente por conexao.
- **Suporte SNI**: `Connect` propaga `SNIHost` via `SSL_CTRL_SET_TLSEXT_HOSTNAME` e `SslSet1Host`.
- **Verificacao de certificado configuravel**: `VerifyCert` habilita `SSL_VERIFY_PEER`; `OnVerifyCert` permite logica adicional de validacao pelo caller.
- **Cross-compiler**: compila em Delphi (incluindo .NET com limitacoes de callback) e FPC via `{$INCLUDE 'jedi.inc'}`.
- **GetPeerCertSHA256Hash (extensao GestorERP)**: unico metodo adicionado pelo fork; retorna bytes raw SHA-256 do certificado servidor para uso como CBT RFC 5929.

---

## 3. Engine

| Diretiva / Condicional | Efeito |
| --- | --- |
| `{$INCLUDE 'jedi.inc'}` | Inclui definicoes de compatibilidade JEDI (Delphi/FPC) |
| `{$IFDEF UNICODE}` | Suprime `IMPLICIT_STRING_CAST` e `IMPLICIT_STRING_CAST_LOSS` |
| `{$IFDEF CIL}` | Blocos alternativos para .NET (StringBuilder no lugar de AnsiString); callbacks de senha nao suportados em .NET |
| `{$IFDEF DELPHI23_UP}` | Usa `AnsiStrings.StrLCopy` em Delphi XE+ para compatibilidade Unicode |
| `{$IFDEF SUPPORTS_DEPRECATED}` | Marca a unit como `deprecated` em compiladores que suportam a diretiva |
| `ssl_openssl_lib` (unit) | Declaracoes de funcoes OpenSSL importadas dinamicamente (`SslNew`, `SslConnect`, `X509Digest`, etc.) |
| `InitSSLInterface` | Funcao de `ssl_openssl_lib` que carrega as DLLs OpenSSL; se falhar, `SSLImplementation` nao e alterado |
| OpenSSL 0.9.7 — 1.1.x | Versoes compativeis (testadas); OpenSSL 3.x requer `ssl_openssl3.pas` |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida e conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket)` | Inicializa o plugin vinculado ao socket `Value`; configura cipher suite `DEFAULT` |
| `Destroy` | `destructor Destroy` | Libera contexto SSL/TLS e chama `DeInit` |
| `Connect` | `function Connect: boolean` | Realiza handshake SSL/TLS client-side; propaga SNIHost; suporta timeout nao-bloqueante |
| `Accept` | `function Accept: boolean` | Realiza handshake SSL/TLS server-side |
| `Shutdown` | `function Shutdown: boolean` | Encerra a sessao SSL com um unico `SSL_shutdown` |
| `BiShutdown` | `function BiShutdown: boolean` | Encerramento bidirecional (envia e aguarda `close_notify`) |

### 4.2 Transferencia de dados

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer` | Envia dados pela sessao SSL; trata `SSL_ERROR_WANT_READ` e `SSL_ERROR_WANT_WRITE` com retry |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer` | Recebe dados da sessao SSL com mesmo tratamento de retry |
| `WaitingData` | `function WaitingData: Integer` | Retorna quantidade de bytes pendentes no buffer SSL (`SSL_pending`) |

### 4.3 Informacoes do certificado e sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string` | Retorna string da versao do protocolo negociado (ex.: `TLSv1.2`) |
| `GetPeerSubject` | `function GetPeerSubject: string` | Retorna Subject DN do certificado servidor (formato `X509_NAME_oneline`) |
| `GetPeerIssuer` | `function GetPeerIssuer: string` | Retorna Issuer DN do certificado servidor |
| `GetPeerName` | `function GetPeerName: string` | Extrai apenas o CN do Subject DN |
| `GetPeerSerialNo` | `function GetPeerSerialNo: integer` | Retorna numero serial do certificado servidor |
| `GetPeerNameHash` | `function GetPeerNameHash: cardinal` | Retorna hash do Subject Name (usado para lookup de CAs) |
| `GetPeerFingerprint` | `function GetPeerFingerprint: ansistring` | Retorna fingerprint MD5 do certificado servidor (bytes raw) |
| `GetCertInfo` | `function GetCertInfo: string` | Retorna dump textual completo do certificado via `X509_print` |
| `GetCipherName` | `function GetCipherName: string` | Nome da cipher suite negociada (ex.: `ECDHE-RSA-AES256-GCM-SHA384`) |
| `GetCipherBits` | `function GetCipherBits: integer` | Bits efetivos da cipher atual |
| `GetCipherAlgBits` | `function GetCipherAlgBits: integer` | Bits do algoritmo da cipher atual |
| `GetVerifyCert` | `function GetVerifyCert: integer` | Resultado da verificacao do certificado (`SSL_get_verify_result`); 0 = OK |

### 4.4 Extensao GestorERP

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetPeerCertSHA256Hash` | `function GetPeerCertSHA256Hash: AnsiString` | Retorna 32 bytes raw (SHA-256) do certificado servidor em formato DER. Retorna string vazia se nao houver certificado de peer. Usado para construir o Channel Binding Token `tls-server-end-point` (RFC 5929) em `TLDAPSend.BindGSSAPIWithCBT` |

### 4.5 Informacoes do plugin

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LibVersion` | `function LibVersion: String` | Retorna versao da biblioteca OpenSSL carregada (`SSLeay_version(0)`) |
| `LibName` | `function LibName: String` | Retorna `'ssl_openssl'` (identificador do plugin) |

---

## 5. Aplicabilidades

1. **LDAPS com Channel Binding** — `TLDAPSend.BindGSSAPIWithCBT` chama `GetPeerCertSHA256Hash` para obter o hash do certificado do controlador de dominio e construir o CBT antes de enviar o token GSSAPI no bind SASL.

2. **LDAPS convencional** — quando `TLDAPSend.FullSSL = True`, o `TTCPBlockSocket` interno usa `TSSLOpenSSL` (ou `TSSLOpenSSL3`) para estabelecer o canal TLS na porta 636 antes de qualquer operacao LDAP.

3. **StartTLS** — quando `TLDAPSend.AutoTLS = True`, o socket realiza handshake TLS sobre conexao LDAP plaintext via `SSLDoConnect`, usando este plugin.

4. **Verificacao de identidade do servidor** — `GetPeerName` e `GetVerifyCert` permitem validar que o certificado do controlador de dominio corresponde ao hostname esperado, evitando conexoes a servidores nao autorizados.

5. **Inspecao forense / debugging** — `GetCertInfo` retorna o dump completo do certificado servidor, util para diagnostico de problemas de TLS em ambiente corporativo.

---

## 6. Exemplos de Uso

### 6.1 Obter hash SHA-256 do certificado para CBT (uso tipico com TLDAPSend)

```pascal
uses ldapsend, ssl_openssl;

var
  LLDAP: TLDAPSend;
  LHash: AnsiString;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.com.br';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL   := True;

    if not LLDAP.Login then
      raise Exception.Create('LDAPS falhou: ' + LLDAP.ResultString);

    // Obtem hash SHA-256 raw do certificado servidor
    LHash := (LLDAP.Sock.SSL as TSSLOpenSSL).GetPeerCertSHA256Hash;

    if Length(LHash) <> 32 then
      raise Exception.Create('Certificado servidor nao disponivel');

    // Passa para o bind Kerberos com Channel Binding Token
    if not LLDAP.BindGSSAPIWithCBT('ldap/dc01.empresa.com.br', LHash) then
      raise Exception.Create('Bind CBT falhou: ' + LLDAP.ResultString);
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 Verificar certificado e cipher suite apos handshake

```pascal
uses blcksock, ssl_openssl;

var
  LSock: TTCPBlockSocket;
  LSSL: TSSLOpenSSL;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.TargetHost  := 'dc01.empresa.com.br';  // via prop herdada
    LSock.CertCAFile  := 'C:\certs\empresa-ca.pem';
    LSock.VerifyCert  := True;
    LSock.SNIHost     := 'dc01.empresa.com.br';
    LSock.Connect('dc01.empresa.com.br', '636');
    LSock.SSLDoConnect;

    if LSock.LastError <> 0 then
      raise Exception.Create('TLS falhou: ' + LSock.GetErrorDescEx);

    LSSL := LSock.SSL as TSSLOpenSSL;

    ShowMessage('Versao TLS : ' + LSSL.GetSSLVersion);
    ShowMessage('Cipher     : ' + LSSL.GetCipherName +
                ' (' + IntToStr(LSSL.GetCipherBits) + ' bits)');
    ShowMessage('CN servidor: ' + LSSL.GetPeerName);
    ShowMessage('Verificacao: ' + IntToStr(LSSL.GetVerifyCert));
  finally
    LSock.Free;
  end;
end;
```

### 6.3 Uso como servidor TLS com certificado Ad-Hoc

```pascal
uses blcksock, ssl_openssl;

var
  LServer: TTCPBlockSocket;
  LClient: TTCPBlockSocket;
  LClientSocket: TSocket;
begin
  // Sem atribuir certificado — TSSLOpenSSL cria Ad-Hoc automaticamente
  LServer := TTCPBlockSocket.Create;
  try
    LServer.Bind('0.0.0.0', '8443');
    LServer.Listen;
    LClientSocket := LServer.Accept;

    LClient := TTCPBlockSocket.CreateWithSSL(TSSLOpenSSL);
    try
      LClient.Socket := LClientSocket;
      LClient.SSLAcceptConnection;
      // Conexao TLS estabelecida com certificado Ad-Hoc
    finally
      LClient.Free;
    end;
  finally
    LServer.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| **Herda de** | `TCustomSSL` (blcksock.pas) | Interface base para todos os plugins SSL do Synapse; define o contrato (`Connect`, `Accept`, `SendBuffer`, `RecvBuffer`, propriedades `VerifyCert`, `SNIHost`, `CertCAFile`, etc.) |
| **Vinculado a** | `TTCPBlockSocket` (blcksock.pas) | Uma instancia de `TSSLOpenSSL` e criada e gerenciada pelo `TTCPBlockSocket`; acessivel via `TTCPBlockSocket.SSL` |
| **Usa** | `ssl_openssl_lib` (ssl_openssl_lib.pas) | Declaracoes de todas as funcoes OpenSSL: `SslNew`, `SslConnect`, `X509Digest`, `EvpGetDigestByName`, `SSLGetPeerCertificate`, etc. |
| **Registrado em** | `SSLImplementation` (blcksock.pas) | `initialization` da unit registra `TSSLOpenSSL` em `SSLImplementation` se `InitSSLInterface` retornar `True` |
| **Consumido por** | `TLDAPSend` (ldapsend.pas) | Acessa `GetPeerCertSHA256Hash` via cast `LLDAP.Sock.SSL as TSSLOpenSSL` para CBT |
| **Alternativa** | `TSSLOpenSSL3` (ssl_openssl3.pas) | Versao para OpenSSL 3.x; deve receber a mesma extensao `GetPeerCertSHA256Hash` para uso com LDAPS em Delphi 12 |
| **Alternativas** | `TSSLOpenSSL11`, `TSSLSbb`, `TSSLCryptLib` | Outros plugins SSL do Synapse para diferentes backends |
