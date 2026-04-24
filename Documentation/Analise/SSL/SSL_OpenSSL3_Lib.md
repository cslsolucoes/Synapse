# SSL_OpenSSL3_Lib / ssl_openssl3_lib.pas

**Unit:** `ssl_openssl3_lib.pas` | **Versao:** upstream Synapse | **Tipo:** Unit (imports dinamicos) | **Origem:** Upstream Synapse (Lukas Gebauer)

---

## 1. O que e?

`ssl_openssl3_lib.pas` e o binding Pascal dedicado a OpenSSL 3.0+ (3.0, 3.1, 3.2, 3.3, 3.6.2 FireDaemon). A unit e uma evolucao directa de `ssl_openssl11_lib.pas` — a maior parte das assinaturas Pascal e identica, porque a OpenSSL 3.x manteve compat binaria com 1.1.x para a maioria dos simbolos (decisao estrategica do projecto OpenSSL para facilitar migracao). As diferencas estao nos nomes de DLL (`-3` em vez de `-1_1`) e em algumas novidades arquitecturais da 3.x (providers) que o Synapse ignora por enquanto.

Essa compatibilidade binaria e o motivo pelo qual `ssl_openssl4_lib.pas` (fork CSL) e um fork mecanico desta unit: o upstream OpenSSL planeia manter API compat em 4.0, apenas mudando nome da DLL. ICS V9.6 confirma o cenario.

Consumida exclusivamente por `ssl_openssl3.pas` (class `TSSLOpenSSL3`).

---

## 2. Caracteristicas

- **OpenSSL 3.0+ exclusivo:** todas versoes 3.x cobertas pela mesma unit.
- **DLL names fixos:** `libssl-3(-x64).dll` / `libcrypto-3(-x64).dll` (Windows); `libssl.so.3` / `libcrypto.so.3` (Linux); `libssl.3.dylib` / `libcrypto.3.dylib` (macOS).
- **API quase identica a 1.1.x:** facilita migracao.
- **Sem locking callbacks:** herdado de 1.1.x.
- **TLS 1.3 activo:** OpenSSL 3.x tem 1.3 como default.
- **1537 linhas:** ligeiramente menor que 1.1_lib devido a remocao de alguns simbolos deprecated.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` | FPC em modo Delphi |
| `synafpc` | RTL cross-compiler |
| `Windows.pas` / BaseUnix / Libc | Imports de loader dinamico |
| `DLLSSLName` / `DLLUtilName` | Variaveis sobrescritaveis com path customizado |

Nomes de DLL por plataforma:

| Plataforma / Arch | DLL SSL | DLL Crypto |
| --- | --- | --- |
| Windows 32 | `libssl-3.dll` | `libcrypto-3.dll` |
| Windows 64 | `libssl-3-x64.dll` | `libcrypto-3-x64.dll` |
| Linux | `libssl.so.3` | `libcrypto.so.3` |
| macOS (Darwin) | `libssl.3.dylib` | `libcrypto.3.dylib` |
| OS/2 (GCC) | `kssl.dll` | `kcrypto.dll` |

---

## 4. Funcionalidades

### 4.1 Tipos opacos

Identicos a `ssl_openssl11_lib`: `SslPtr`, `PSSL_CTX`, `PSSL`, `PSSL_METHOD`, `PX509`, `PX509_NAME`, `PX509_STORE`, `PEVP_MD`, `PBIO`, `EVP_PKEY`, `PRSA`, `PASN1_*`, `PSTACK`, `PPasswdCb`. Funcoes de callback: `TSkPopFreeFunc`, `TX509Free`.

### 4.2 Constantes

Herdadas de 1.1.x sem alteracao: `SSL_ERROR_*`, `SSL_OP_*`, `SSL_VERIFY_*`, `X509_V_*` (~50 codes), `SSL_CTRL_SET_TLSEXT_HOSTNAME = 55`, `SSL_CTRL_SET_MIN_PROTO_VERSION = 123`, `SSL_CTRL_SET_MAX_PROTO_VERSION = 124`, `TLS1_VERSION = $0301`, `TLS1_1_VERSION = $0302`, `TLS1_2_VERSION = $0303`, `TLS1_3_VERSION = $0304`, `TLSEXT_NAMETYPE_host_name = 0`.

### 4.3 Imports principais

Praticamente identicos a `ssl_openssl11_lib`. Inclui:

| Funcao | Descricao |
| --- | --- |
| `InitSSLInterface` | Loader |
| `DestroySSLInterface` | Shutdown |
| `SslCtxNew` / `SslCtxFree` | Lifecycle context |
| `TLS_method` / `TLS_server_method` / `TLS_client_method` | Method factories |
| `SslCtxSetMinProtoVersion` / `SslCtxSetMaxProtoVersion` | Version range |
| `SslCtxSetCipherList` | Cipher list |
| `SslCtxLoadVerifyLocations` | CA bundle |
| `SslCtxUseCertificateFile` / `SslCtxUsePrivateKeyFile` | Load material |
| `SslCtxSetVerify` | Verify mode |
| `SslNew` / `SslFree` | Session lifecycle |
| `SslConnect` / `SslAccept` / `SslShutdown` | Handshake |
| `SslWrite` / `SslRead` / `SslPending` / `SslGetError` | I/O |
| `SslGetPeerCertificate`, `SslGetVerifyResult` | Peer cert |
| `SslGetVersion` / `SslGetCurrentCipher` / `SslCipherGetName` / `SslCipherGetBits` | Session info |
| `SslCtrl` / `SslSet1Host` | SNI + host check |
| `X509Digest`, `X509NameOneline`, `X509NameHash`, `X509GetSubjectName`, `X509GetIssuerName`, `X509GetSerialNumber`, `X509Free`, `X509Print` | X509 utils |
| `EvpGetDigestByName` | Hash algorithm lookup |
| `ErrGetError`, `ErrErrorString` | Error stack |
| `OpenSSLversion` | Lib version string |
| `RandBytes`, `RandSeed` | PRNG |

### 4.4 Diferencas vs ssl_openssl11_lib

1. **Nomes de DLL:** `-3(-x64)` em vez de `-1_1(-x64)`.
2. **Remocoes silenciosas:** algumas funcoes deprecated em 3.x que ja nao sao resolvidas (evita warnings).
3. **Mesmos prototipos Pascal:** aplicacao e codigo cliente sao portaveis 1:1.

---

## 5. Aplicabilidades

1. **Recomendado para codigo novo 2026+:** OpenSSL 3.x e LTS activo (3.0 ate 2026-09, 3.2 ate 2026-11, 3.3 em suporte).
2. **Consumida por `ssl_openssl3.pas`:** unica interface publica.
3. **TLS 1.3 acessivel:** sem config adicional.
4. **Migracao 1.1 -> 3.x:** troca da unit sem ajustes na API.
5. **Base do fork CSL `ssl_openssl4_lib.pas`:** fork mecanico desta unit.

---

## 6. Exemplos de uso

### 6.1 Verificar versao da lib carregada

```pascal
uses
  ssl_openssl3_lib;

begin
  if InitSSLInterface then
    WriteLn('OpenSSL 3.x: ', OpenSSLversion(0))
  else
    WriteLn('OpenSSL 3 nao encontrada');
end;
```

### 6.2 Forcar caminho custom (desenvolvimento)

```pascal
uses
  ssl_openssl3_lib;

begin
  DLLSSLName  := 'C:\OpenSSL-3.2\bin\libssl-3-x64.dll';
  DLLUtilName := 'C:\OpenSSL-3.2\bin\libcrypto-3-x64.dll';
  if InitSSLInterface then
    WriteLn('Loaded version: ', OpenSSLversion(0));
end;
```

### 6.3 Forcar TLS 1.3 only

```pascal
uses
  ssl_openssl3_lib, ssl_openssl3;

var
  LCtx: PSSL_CTX;
begin
  if not InitSSLInterface then Exit;
  LCtx := SslCtxNew(SslMethodTls);
  try
    SslCtxSetMinProtoVersion(LCtx, TLS1_3_VERSION);
    SslCtxSetMaxProtoVersion(LCtx, TLS1_3_VERSION);
    // ctx aceita apenas TLS 1.3
  finally
    SslCtxFree(LCtx);
  end;
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Consumida por | `ssl_openssl3.pas` (TSSLOpenSSL3) | Unica unit que faz binding |
| Cobre | OpenSSL 3.0, 3.1, 3.2, 3.3+ | Toda a linha 3.x |
| Base para fork | `ssl_openssl4_lib.pas` (CSL) | Fork mecanico, so muda DLLs |
| Evolucao de | `ssl_openssl11_lib.pas` | API quase identica |
| Substitui | `ssl_openssl_lib.pas` (para 3.x) | Em codigo novo |
| Runtime | `libssl-3(-x64).dll` / `libcrypto-3(-x64).dll` | DLLs dedicadas |
| Integracao | `TOpenSSLPaths` (ssl_openssl_paths.pas) | `Apply(3)` aponta `SetDllDirectory` para `dll\v3\<arch>\` |
