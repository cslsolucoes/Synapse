# TSSLOpenSSL (ssl_openssl11) / ssl_openssl11.pas

**Unit:** `ssl_openssl11.pas` | **Versao:** 002.000.001 | **Tipo:** Classe | **Origem:** Upstream Synapse (Lukas Gebauer)

> Nota: a classe chama-se `TSSLOpenSSL` (nome colidente com `ssl_openssl.pas`) — diferencia-se pela unit em que vive. Nunca importar ambas as units no mesmo `uses`.

---

## 1. O que e?

`TSSLOpenSSL` de `ssl_openssl11.pas` e o plugin SSL/TLS do Synapse dedicado exclusivamente a OpenSSL 1.1.x (1.1.0, 1.1.1). Foi introduzido quando a ABI da OpenSSL 1.1 passou a ser incompativel com 1.0.x (nomes de DLL distintos: `libssl-1_1.dll`/`libcrypto-1_1.dll`; simbolos refatorados em `SSL_CTX_new` variantes `_TLS_method`; removal de `SSLv23_method`). A classe esta marcada como `deprecated` com sugestao de migrar para `ssl_openssl3`.

A implementacao e um fork paralelo: assinaturas identicas a `TSSLOpenSSL` de `ssl_openssl.pas` (exceto `Init`/`Prepare` que aceitam `server: Boolean`), mas ligada a `ssl_openssl11_lib` que so importa os nomes OpenSSL 1.1.x. Nao expoe `GetPeerCertSHA256Hash` (extensao CSL exclusiva de `ssl_openssl.pas` e `ssl_openssl3.pas`/`ssl_openssl4.pas` nao publicadas).

---

## 2. Caracteristicas

- **Dedicado a OpenSSL 1.1.x:** nenhuma compatibilidade retroactiva para 1.0.x. DLLs fixas `libssl-1_1(-x64).dll` e `libcrypto-1_1(-x64).dll`.
- **Sem suporte .NET/CIL** (diferenca vs `ssl_openssl.pas`).
- **Ad-Hoc certs:** gera par RSA/cert auto-assinado para servidor TLS sem cert configurado.
- **SNI:** via `SSL_CTRL_SET_TLSEXT_HOSTNAME`.
- **Server flag:** `Init(server: Boolean)` distingue client/server no ctx (em vez do campo `FServer` de `ssl_openssl.pas`).
- **Deprecated:** marcacao `deprecated 'Use ssl_openssl3 with OpenSSL 3.0 instead'` em `SUPPORTS_DEPRECATED_DETAILS`.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$INCLUDE 'jedi.inc'}` | Defines JEDI (Delphi/FPC) |
| `{$IFDEF UNICODE}` | Suprime warnings de cast Unicode |
| `{$IFDEF SUPPORTS_DEPRECATED}` | Marca unit como deprecated |
| `ssl_openssl11_lib` | Import layer especifica OpenSSL 1.1.x (`libssl-1_1.dll`/`libcrypto-1_1.dll`) |
| OpenSSL 1.1.0 e 1.1.1 | Versoes testadas; nao funciona com 1.0.x nem 3.x |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida e conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); override` | Inicializa plugin; `FCiphers := 'DEFAULT'` |
| `Destroy` | `destructor Destroy; override` | Liberta contexto via `DeInit` |
| `Connect` | `function Connect: boolean; override` | Handshake client-side; propaga SNIHost |
| `Accept` | `function Accept: boolean; override` | Handshake server-side |
| `Shutdown` | `function Shutdown: boolean; override` | Encerra sessao uni-direccional |
| `BiShutdown` | `function BiShutdown: boolean; override` | Encerra bi-direccional |

### 4.2 Metodos protegidos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SSLCheck` | `function SSLCheck: Boolean` | Popula `FLastError`/`FLastErrorDesc` |
| `SetSslKeys` | `function SetSslKeys: boolean` | Carrega cert/chave/PFX |
| `Init` | `function Init(server: Boolean): Boolean` | Cria `SSL_CTX` com `TLS_server_method`/`TLS_client_method` |
| `DeInit` | `function DeInit: Boolean` | Liberta `SSL` e `SSL_CTX` |
| `Prepare` | `function Prepare(server: Boolean): Boolean` | Init + SetSslKeys + config |
| `LoadPFX` | `function LoadPFX(pfxdata: ansistring): Boolean` | Decodifica PFX binario |
| `CreateSelfSignedCert` | `function CreateSelfSignedCert(Host: string): Boolean; override` | Gera cert Ad-Hoc |

### 4.3 Transferencia de dados

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Envia dados TLS |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Recebe dados TLS |
| `WaitingData` | `function WaitingData: Integer; override` | Bytes pendentes (`SSL_pending`) |

### 4.4 Informacoes de certificado e sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string; override` | Versao do protocolo (ex.: `TLSv1.2`, `TLSv1.3`) |
| `GetPeerSubject` | `function GetPeerSubject: string; override` | Subject DN |
| `GetPeerSerialNo` | `function GetPeerSerialNo: integer; override` | Serial number |
| `GetPeerIssuer` | `function GetPeerIssuer: string; override` | Issuer DN |
| `GetPeerName` | `function GetPeerName: string; override` | CN do Subject |
| `GetPeerNameHash` | `function GetPeerNameHash: cardinal; override` | Hash do Subject |
| `GetPeerFingerprint` | `function GetPeerFingerprint: ansistring; override` | Fingerprint MD5 |
| `GetCertInfo` | `function GetCertInfo: string; override` | Dump textual completo |
| `GetCipherName` | `function GetCipherName: string; override` | Nome da cipher |
| `GetCipherBits` | `function GetCipherBits: integer; override` | Bits efectivos |
| `GetCipherAlgBits` | `function GetCipherAlgBits: integer; override` | Bits do algoritmo |
| `GetVerifyCert` | `function GetVerifyCert: integer; override` | `SSL_get_verify_result` |

### 4.5 Informacoes do plugin

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LibVersion` | `function LibVersion: String; override` | `OpenSSLversion(0)` — string da lib carregada |
| `LibName` | `function LibName: String; override` | Retorna `'ssl_openssl11'` |

---

## 5. Aplicabilidades

1. **Aplicacoes legacy OpenSSL 1.1.x** — sistemas em producao que nao podem migrar para OpenSSL 3.x (compat de pacote, dependencias, auditoria).
2. **HTTPS/FTPS/SMTPS** — qualquer socket SSL via Synapse em maquinas com OpenSSL 1.1 instalada.
3. **StartTLS** — em SMTP/LDAP/IMAP onde o upgrade e feito sobre conexao plaintext.
4. **Migracao gradual** — permite continuar compativel com 1.1.x enquanto se testa `ssl_openssl3`.

---

## 6. Exemplos de uso

### 6.1 Cliente HTTPS com cert verification

```pascal
uses
  SysUtils, blcksock, httpsend, ssl_openssl11;

var
  LHTTP: THTTPSend;
begin
  LHTTP := THTTPSend.Create;
  try
    LHTTP.Sock.CertCAFile := 'certs\ca-bundle.pem';
    LHTTP.Sock.VerifyCert := True;

    if LHTTP.HTTPMethod('GET', 'https://api.empresa.local/status') then
      WriteLn('HTTP ', LHTTP.ResultCode)
    else
      WriteLn('Falhou: ', LHTTP.Sock.LastError);
  finally
    LHTTP.Free;
  end;
end;
```

### 6.2 LDAPS usando OpenSSL 1.1

```pascal
uses
  ldapsend, ssl_openssl11;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL   := True;
    LLDAP.UserName  := 'CN=svc,DC=empresa,DC=local';
    LLDAP.Password  := 'secret';

    if LLDAP.Login then
      WriteLn('LDAPS OK (lib: ', (LLDAP.Sock.SSL as TSSLOpenSSL).LibVersion, ')')
    else
      WriteLn('Falhou: ', LLDAP.ResultString);
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.3 Forcar TLS 1.2 minimo

```pascal
uses
  blcksock, ssl_openssl11;

var
  LSock: TTCPBlockSocket;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.SSL.SSLType := LT_TLSv1_2;
    LSock.Connect('api.empresa.local', '443');
    LSock.SSLDoConnect;
    WriteLn('TLS: ', (LSock.SSL as TSSLOpenSSL).GetSSLVersion);
  finally
    LSock.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Herda de | `TCustomSSL` (blcksock.pas) | Contrato base |
| Vinculado a | `TTCPBlockSocket` | Acessivel via `TTCPBlockSocket.SSL` |
| Usa | `ssl_openssl11_lib` | Imports exclusivos OpenSSL 1.1.x |
| Registado em | `SSLImplementation` | Via `initialization` da unit |
| Alternativa moderna | `TSSLOpenSSL3` (ssl_openssl3.pas) | Recomendado (upstream marca 1.1 como deprecated) |
| Conflito de nome | `TSSLOpenSSL` (ssl_openssl.pas) | Nao importar ambas as units |
