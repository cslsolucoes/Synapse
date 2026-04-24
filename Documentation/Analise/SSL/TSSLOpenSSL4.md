# TSSLOpenSSL4 / ssl_openssl4.pas

**Unit:** `ssl_openssl4.pas` | **Versao:** 001.004.000 (CSL fork) | **Tipo:** Classe | **Origem:** CSL fork (100% novo, 2026-04-21)

---

## 1. O que e?

`TSSLOpenSSL4` e o plugin SSL/TLS do fork CSL do Synapse dedicado a OpenSSL 4.0.0 (FireDaemon builds). A classe e um **fork mecanico** de `TSSLOpenSSL3` — assinaturas e corpo identicos, com a unica diferenca ligada ao import layer (`ssl_openssl4_lib`) que carrega as DLLs com sufixo `-4` em vez de `-3`.

A decisao de fork surgiu porque a OpenSSL 4.0 manteve API binaria compativel com 3.x (confirmado por ICS V9.6) mas mudou os nomes das DLLs distribuidas (`libssl-4-x64.dll`/`libcrypto-4-x64.dll`). Em vez de estender `ssl_openssl3` com uma tabela de fallback ou IFDEF, o fork optou por dois artefactos distintos e dois defines condicionais (`USE_OPENSSL3` vs `USE_OPENSSL4`, mutuamente exclusivos em `ORM.Defines.inc`). Isso isola o risco de corromper o codigo 3.x estavel e permite o utilizador escolher explicitamente a ABI.

---

## 2. Caracteristicas

- **Fork mecanico de TSSLOpenSSL3:** mesmas assinaturas, mesmo corpo, so muda nome da classe e unit referenciada em `uses`.
- **OpenSSL 4.0 (FireDaemon Fusion):** build experimental que antecipa a API 4.x; binario compativel com 3.x.
- **DLLs 4.0:** `libssl-4(-x64).dll`, `libcrypto-4(-x64).dll`, `libssl.so.4`, `libssl.4.dylib`.
- **Sem suporte .NET.**
- **Mutuamente exclusivo com USE_OPENSSL3:** o fork CSL define que so uma implementacao OpenSSL moderna esta activa por build.
- **Ad-Hoc certs, SNI, cross-platform:** identicos a TSSLOpenSSL3.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$INCLUDE 'jedi.inc'}` | Defines JEDI |
| `{$IFDEF UNICODE}` | Supressao de warnings |
| `ssl_openssl4_lib` | Import layer OpenSSL 4.0 (nomes DLL com `-4`) |
| `USE_OPENSSL4` (de `ORM.Defines.inc`) | Acciona registro do plugin em `SSLImplementation` |
| OpenSSL 4.0.x (FireDaemon) | Unica versao suportada; bumped de 3.x |

Nomes de DLL carregados:

| Plataforma / Arch | DLL SSL | DLL Crypto |
| --- | --- | --- |
| Windows 32 | `libssl-4.dll` | `libcrypto-4.dll` |
| Windows 64 | `libssl-4-x64.dll` | `libcrypto-4-x64.dll` |
| Linux | `libssl.so.4` | `libcrypto.so.4` |
| macOS | `libssl.4.dylib` | `libcrypto.4.dylib` |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida e conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); override` | Cipher default `'DEFAULT'`; `FSsl`/`Fctx` nil |
| `Destroy` | `destructor Destroy; override` | `DeInit` + herdado |
| `Connect` | `function Connect: boolean; override` | Handshake client-side |
| `Accept` | `function Accept: boolean; override` | Handshake server-side |
| `Shutdown` | `function Shutdown: boolean; override` | Encerramento uni-direccional |
| `BiShutdown` | `function BiShutdown: boolean; override` | Encerramento bi-direccional |

### 4.2 Metodos protegidos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SSLCheck` | `function SSLCheck: Boolean` | Popula erro |
| `SetSslKeys` | `function SetSslKeys: boolean` | Carrega material de chave |
| `Init` | `function Init(server: Boolean): Boolean` | Cria `SSL_CTX` e `SSL` |
| `DeInit` | `function DeInit: Boolean` | Liberta handles |
| `Prepare` | `function Prepare(server: Boolean): Boolean` | Init + SetSslKeys |
| `LoadPFX` | `function LoadPFX(pfxdata: ansistring): Boolean` | PFX binario |
| `CreateSelfSignedCert` | `function CreateSelfSignedCert(Host: string): Boolean; override` | Cert Ad-Hoc |

### 4.3 Transferencia

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Envio |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Recepcao |
| `WaitingData` | `function WaitingData: Integer; override` | Bytes pendentes |

### 4.4 Informacoes de cert e sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string; override` | Versao do protocolo |
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
| `LibName` | `function LibName: String; override` | `'ssl_openssl4'` |

---

## 5. Aplicabilidades

1. **Teste prospectivo da ABI 4.x** — validar compatibilidade antecipada com OpenSSL 4.0 (FireDaemon Fusion builds).
2. **Ambientes que ja distribuem OpenSSL 4:** permite que o GestorERP mantenha LDAPS/HTTPS sem ter de voltar as DLLs 3.x.
3. **Coexistencia com 3.x em distintos clones:** `{$DEFINE USE_OPENSSL3}` num projecto e `{$DEFINE USE_OPENSSL4}` noutro, sem tocar no plugin base.
4. **Benchmark de performance:** A/B testing OpenSSL 3.6.2 (estavel) vs 4.0.0 (novo).

---

## 6. Exemplos de uso

### 6.1 Cliente HTTPS com OpenSSL 4

```pascal
uses
  SysUtils, httpsend, ssl_openssl4;

var
  LHTTP: THTTPSend;
begin
  LHTTP := THTTPSend.Create;
  try
    LHTTP.Sock.CertCAFile := 'certs\root-ca.pem';
    LHTTP.Sock.VerifyCert := True;

    if LHTTP.HTTPMethod('GET', 'https://api.empresa.local/health') then
      WriteLn('OK via ', (LHTTP.Sock.SSL as TSSLOpenSSL4).LibVersion)
    else
      WriteLn('Falhou: ', LHTTP.Sock.LastError);
  finally
    LHTTP.Free;
  end;
end;
```

### 6.2 LDAPS

```pascal
uses
  ldapsend, ssl_openssl4;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL   := True;
    if LLDAP.Login then
      WriteLn('LDAPS OK (', (LLDAP.Sock.SSL as TSSLOpenSSL4).LibName, ')')
    else
      WriteLn('Falhou');
  finally
    LLDAP.Free;
  end;
end;
```

### 6.3 Selector entre OpenSSL 3 e 4 via defines

```pascal
{$I ..\..\ORM.Defines.inc}

uses
  blcksock
  {$IFDEF USE_OPENSSL4}, ssl_openssl4 {$ENDIF}
  {$IFDEF USE_OPENSSL3}, ssl_openssl3 {$ENDIF}
  ;

begin
  // plugin registrado na unit importada
  // nenhuma alteracao adicional requerida
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Herda de | `TCustomSSL` (blcksock.pas) | Contrato base |
| Vinculado a | `TTCPBlockSocket` | Via `TTCPBlockSocket.SSL` |
| Usa | `ssl_openssl4_lib` | Imports OpenSSL 4.0 (`libssl-4`/`libcrypto-4`) |
| Forked de | `TSSLOpenSSL3` (ssl_openssl3.pas) | Fork mecanico — API identica, so mudam DLLs |
| Registado em | `SSLImplementation` | Via `initialization` da unit |
| Mutuamente exclusivo | `TSSLOpenSSL3` via defines `USE_OPENSSL3`/`USE_OPENSSL4` | Uma so implementacao activa por build |
| Paths auxiliares | `TOpenSSLPaths` (ssl_openssl_paths.pas) | `TOpenSSLPaths.Apply(4)` aponta `SetDllDirectory` para `dll\v4\<arch>\` |
