# TSSLOpenSSL3 / ssl_openssl3.pas

**Unit:** `ssl_openssl3.pas` | **Versao:** 001.000.001 | **Tipo:** Classe | **Origem:** Upstream Synapse (Lukas Gebauer)

---

## 1. O que e?

`TSSLOpenSSL3` e o plugin SSL/TLS do Synapse para OpenSSL 3.0+. Foi criado quando a OpenSSL 3.0 trouxe mudancas significativas (provider-based architecture, deprecations de APIs 1.x, nova ABI). A classe substitui funcionalmente `TSSLOpenSSL` (1.0.x) e `TSSLOpenSSL` de `ssl_openssl11.pas` (1.1.x) para codigo novo.

Carrega dinamicamente `libssl-3(-x64).dll`/`libcrypto-3(-x64).dll` no Windows, `libssl.so.3`/`libcrypto.so.3` em Linux, `libssl.3.dylib`/`libcrypto.3.dylib` em macOS. Usa `ssl_openssl3_lib` como import layer. Nao tem suporte a .NET (diferenca vs `ssl_openssl.pas`). Nao tem extensao `GetPeerCertSHA256Hash` na v001.000.001 upstream — para CBT com OpenSSL 3.x no fork CSL, continua-se a usar `ssl_openssl.pas`.

---

## 2. Caracteristicas

- **OpenSSL 3.0.0+:** provider-based, `TLS_server_method`/`TLS_client_method` unificados, APIs 1.x legadas ainda funcionais mas deprecated na lib nativa.
- **Carregamento dinamico:** via `ssl_openssl3_lib` (funcao `InitSSLInterface`). DLLs ausentes = SSL inoperante mas aplicacao inicia.
- **Ad-Hoc certs:** server TLS sem cert ganha par RSA auto-assinado por handshake.
- **SNI:** via `SSL_CTRL_SET_TLSEXT_HOSTNAME`.
- **Cross-platform:** Windows, Linux, macOS com nomes de DLL/so/dylib diferenciados por `$IFDEF`.
- **`Init(server: Boolean)`:** diferenca de assinatura vs `ssl_openssl.pas` (que usa campo `FServer`).
- **Sem suporte .NET:** bloco `{$IFDEF CIL}` removido.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$INCLUDE 'jedi.inc'}` | Defines JEDI |
| `{$IFDEF UNICODE}` | Suprime warnings cast Unicode |
| `ssl_openssl3_lib` | Import layer OpenSSL 3.0 |
| `OpenSSLversion(0)` | Equivalente a `SSLeay_version` em OpenSSL 3.x |
| OpenSSL 3.0, 3.1, 3.2, 3.3+ | Todas compativeis (API estavel 3.x) |

Nomes de DLL carregados:

| Plataforma / Arch | DLL SSL | DLL Crypto |
| --- | --- | --- |
| Windows 32 | `libssl-3.dll` | `libcrypto-3.dll` |
| Windows 64 | `libssl-3-x64.dll` | `libcrypto-3-x64.dll` |
| Linux (generico) | `libssl.so.3` | `libcrypto.so.3` |
| macOS | `libssl.3.dylib` | `libcrypto.3.dylib` |
| OS/2 (GCC) | `kssl.dll` | `kcrypto.dll` |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida e conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); override` | Cipher default `'DEFAULT'`; `FSsl`/`Fctx` nil |
| `Destroy` | `destructor Destroy; override` | `DeInit` + herdado |
| `Connect` | `function Connect: boolean; override` | Handshake client-side |
| `Accept` | `function Accept: boolean; override` | Handshake server-side |
| `Shutdown` | `function Shutdown: boolean; override` | `SSL_shutdown` simples |
| `BiShutdown` | `function BiShutdown: boolean; override` | Encerramento bidireccional |

### 4.2 Metodos protegidos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SSLCheck` | `function SSLCheck: Boolean` | Popula erro |
| `SetSslKeys` | `function SetSslKeys: boolean` | Carrega material de chave |
| `Init` | `function Init(server: Boolean): Boolean` | Cria `SSL_CTX` e `SSL` |
| `DeInit` | `function DeInit: Boolean` | `SSL_free` + `SSL_CTX_free` |
| `Prepare` | `function Prepare(server: Boolean): Boolean` | Init + SetSslKeys + config |
| `LoadPFX` | `function LoadPFX(pfxdata: ansistring): Boolean` | PFX binario |
| `CreateSelfSignedCert` | `function CreateSelfSignedCert(Host: string): Boolean; override` | Cert Ad-Hoc |

### 4.3 Transferencia e sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Envio |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Recepcao |
| `WaitingData` | `function WaitingData: Integer; override` | Bytes pendentes |

### 4.4 Informacoes de cert e sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string; override` | Protocolo negociado |
| `GetPeerSubject` | `function GetPeerSubject: string; override` | Subject DN |
| `GetPeerSerialNo` | `function GetPeerSerialNo: integer; override` | Serial |
| `GetPeerIssuer` | `function GetPeerIssuer: string; override` | Issuer DN |
| `GetPeerName` | `function GetPeerName: string; override` | CN |
| `GetPeerNameHash` | `function GetPeerNameHash: cardinal; override` | Hash do Subject |
| `GetPeerFingerprint` | `function GetPeerFingerprint: AnsiString; override` | Fingerprint MD5 |
| `GetCertInfo` | `function GetCertInfo: string; override` | Dump textual |
| `GetCipherName` | `function GetCipherName: string; override` | Nome cipher |
| `GetCipherBits` | `function GetCipherBits: integer; override` | Bits efectivos |
| `GetCipherAlgBits` | `function GetCipherAlgBits: integer; override` | Bits do algoritmo |
| `GetVerifyCert` | `function GetVerifyCert: integer; override` | `SSL_get_verify_result` |

### 4.5 Informacoes do plugin

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LibVersion` | `function LibVersion: String; override` | `OpenSSLversion(0)` |
| `LibName` | `function LibName: String; override` | `'ssl_openssl3'` |

---

## 5. Aplicabilidades

1. **Aplicacoes novas** — escolha default em 2026+ para qualquer cliente/servidor TLS via Synapse em Delphi/FPC.
2. **LDAPS moderno** — conexao a Active Directory Windows Server 2022/2025 com OpenSSL 3.x em runtime.
3. **HTTPS/FTPS/SMTPS** — Horse, httpsend, ftpsend, smtpsend sobre OpenSSL 3.x.
4. **Migracao 1.1 -> 3.0** — troca de `ssl_openssl11` por `ssl_openssl3` no `uses` e DLLs em runtime. API identica.
5. **TLS 1.3** — totalmente suportado (OpenSSL 3.x tem TLS 1.3 activo por default).

---

## 6. Exemplos de uso

### 6.1 Cliente HTTPS moderno (TLS 1.3)

```pascal
uses
  SysUtils, httpsend, ssl_openssl3;

var
  LHTTP: THTTPSend;
begin
  LHTTP := THTTPSend.Create;
  try
    LHTTP.Sock.CertCAFile := 'certs\empresa-ca.pem';
    LHTTP.Sock.VerifyCert := True;

    if LHTTP.HTTPMethod('GET', 'https://api.empresa.local/v1/health') then
    begin
      WriteLn('HTTP: ', LHTTP.ResultCode);
      WriteLn('TLS : ', (LHTTP.Sock.SSL as TSSLOpenSSL3).GetSSLVersion);
    end;
  finally
    LHTTP.Free;
  end;
end;
```

### 6.2 LDAPS sobre OpenSSL 3

```pascal
uses
  ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL   := True;

    if LLDAP.Login then
    begin
      WriteLn('Conectado, lib: ', (LLDAP.Sock.SSL as TSSLOpenSSL3).LibVersion);
      LLDAP.Logout;
    end;
  finally
    LLDAP.Free;
  end;
end;
```

### 6.3 Inspeccionar cipher TLS 1.3

```pascal
uses
  blcksock, ssl_openssl3;

var
  LSock: TTCPBlockSocket;
  LSSL: TSSLOpenSSL3;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.Connect('example.com', '443');
    LSock.SSLDoConnect;
    LSSL := LSock.SSL as TSSLOpenSSL3;
    WriteLn('Versao : ', LSSL.GetSSLVersion);    // TLSv1.3
    WriteLn('Cipher : ', LSSL.GetCipherName);    // TLS_AES_256_GCM_SHA384
    WriteLn('Bits   : ', LSSL.GetCipherBits);    // 256
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
| Usa | `ssl_openssl3_lib` | Imports OpenSSL 3.0 (`libssl-3`/`libcrypto-3`) |
| Registado em | `SSLImplementation` | Via `initialization` da unit |
| Substitui | `TSSLOpenSSL` (ssl_openssl.pas 1.0.x), `TSSLOpenSSL` (ssl_openssl11.pas 1.1.x) | Versao recomendada 2026+ |
| Fork CSL paralelo | `TSSLOpenSSL4` (ssl_openssl4.pas) | OpenSSL 4.0 (API identica a 3.x) |
| Alternativas | `TSSLCryptLib`, `TSSLOpenSSLCapi` | Outros backends |
