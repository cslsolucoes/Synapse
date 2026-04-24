# SSL_OpenSSL11_Lib / ssl_openssl11_lib.pas

**Unit:** `ssl_openssl11_lib.pas` | **Versao:** upstream alinhada com Synapse core | **Tipo:** Unit (imports dinamicos) | **Origem:** Upstream Synapse

---

## 1. O que e?

`ssl_openssl11_lib.pas` e o binding Pascal dedicado a OpenSSL 1.1.x (1.1.0 e 1.1.1). Foi criado quando a OpenSSL 1.1 quebrou a ABI de 1.0.x: renomeou `SSLv23_method` para `TLS_method`, introduziu `SSL_CTX_set_min_proto_version`, retirou `SSL_library_init` em favor de inicializacao implicita, e mudou o layout binario de estruturas opacas (`SSL_CTX_*`, `X509_*`).

A unit importa apenas os simbolos que existem em 1.1.x — nao tem a lista de fallback DLLs de `ssl_openssl_lib`. Carrega directamente `libssl-1_1(-x64).dll` / `libcrypto-1_1(-x64).dll` no Windows, `libssl.so.1.1` / `libcrypto.so.1.1` em Linux, `libssl.dylib` / `libcrypto.dylib` em macOS. Se as DLLs nao estiverem presentes, a unit carrega mas as funcoes retornam erro (ponteiros nulos).

Consumida exclusivamente por `ssl_openssl11.pas` (class `TSSLOpenSSL`).

---

## 2. Caracteristicas

- **OpenSSL 1.1.x exclusivo:** nao faz fallback para 1.0.x.
- **DLL names fixos:** `libssl-1_1.dll` / `libcrypto-1_1.dll` (sem tentar outros nomes).
- **API moderna:** `TLS_method`, `SSL_CTX_set_min/max_proto_version`, `SSL_set1_host`.
- **Sem locking callbacks:** OpenSSL 1.1+ e thread-safe internamente (eliminou `CRYPTO_set_locking_callback`).
- **Sem SSL_library_init:** init implicito; `OPENSSL_init_ssl` tratado em background.
- **1558 linhas:** alinhadas com simbolos efectivamente disponiveis em 1.1.x.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` | FPC em modo Delphi |
| `synafpc` | RTL cross-compiler |
| `Windows.pas` / BaseUnix / Libc | Imports de `LoadLibrary`/`dlopen` |
| `DLLSSLName` / `DLLUtilName` | Variaveis com nomes de DLL (podem ser sobrescritas pre-init) |

Nomes de DLL por plataforma:

| Plataforma / Arch | DLL SSL | DLL Crypto |
| --- | --- | --- |
| Windows 32 | `libssl-1_1.dll` | `libcrypto-1_1.dll` |
| Windows 64 | `libssl-1_1-x64.dll` | `libcrypto-1_1-x64.dll` |
| Linux | `libssl.so.1.1` | `libcrypto.so.1.1` |
| macOS (Darwin) | `libssl.dylib` | `libcrypto.dylib` |
| OS/2 (GCC) | `kssl.dll` | `kcrypto.dll` |

---

## 4. Funcionalidades

### 4.1 Tipos opacos

Os mesmos de `ssl_openssl_lib` — `SslPtr`, `PSSL_CTX`, `PSSL`, `PSSL_METHOD`, `PX509`, `PX509_NAME`, `PX509_STORE` (nova em 1.1), `PEVP_MD`, `PBIO`, `EVP_PKEY`, `PRSA`, `PASN1_UTCTIME`, `PASN1_INTEGER`, `PPasswdCb`, `PSTACK`.

### 4.2 Constantes

Identicas a `ssl_openssl_lib` para codigos de erro, verify, X509_V_*, EVP_MAX_MD_SIZE, TLS1_VERSION/TLS1_1_VERSION/TLS1_2_VERSION. Adicoes 1.1.x: `SSL_CTRL_SET_MIN_PROTO_VERSION = 123`, `SSL_CTRL_SET_MAX_PROTO_VERSION = 124`.

### 4.3 Imports principais (funcoes unicas ou renomeadas em 1.1.x)

| Funcao | Descricao |
| --- | --- |
| `InitSSLInterface` | Loader (resolve todos os ponteiros) |
| `DestroySSLInterface` | Libera DLLs |
| `SslCtxNew` | `SSL_CTX_new(TLS_method())` |
| `TLS_method`, `TLS_server_method`, `TLS_client_method` | Unificam SSLv23_* de 1.0.x |
| `SslCtxSetMinProtoVersion` | **Novo em 1.1.x** — forca min TLS version |
| `SslCtxSetMaxProtoVersion` | **Novo em 1.1.x** — forca max TLS version |
| `SslCtxSetCipherList` | Set cipher list (string OpenSSL) |
| `SslSet1Host` | Set expected peer hostname |
| `X509Digest` | Hash de cert DER |
| `X509NameOneline`, `X509NameHash`, `X509GetSubjectName`, `X509GetIssuerName`, `X509GetSerialNumber`, `X509Free`, `X509Print` | X509 utilities |
| `OpenSSLversion` | **Renomeada** — substitui `SSLeay_version` |
| `EvpGetDigestByName` | Resolver digest |
| `ErrGetError`, `ErrErrorString` | Stack de erros |
| `RandBytes`, `RandSeed` | PRNG |

### 4.4 Diferencas vs ssl_openssl_lib

1. **Sem locking callbacks** (`CryptoSetLockingCallback`, `CryptoSetIdCallback` removidos — 1.1 e thread-safe).
2. **TLS_method** substitui `SSLv23_method`.
3. **OpenSSLversion** substitui `SSLeay_version`.
4. **SSL_CTX_set_min/max_proto_version** expostos.
5. **X509_STORE** tipo opaco declarado.
6. **Sem callback `SslCtxSetTmpRsaCallback`** (RSA ephemeral morto).

---

## 5. Aplicabilidades

1. **Sistemas com OpenSSL 1.1 em LTS:** Ubuntu 18.04/20.04, RHEL/CentOS 7/8, Debian 10.
2. **Consumida por `ssl_openssl11.pas`:** unica interface publica.
3. **Fine tuning TLS:** `SslCtxSetMinProtoVersion(ctx, TLS1_2_VERSION)` forca TLS 1.2+.
4. **Migracao 1.0 -> 1.1:** permite ao codigo Synapse usar symbols 1.1.x sem esperar pela 3.x.

---

## 6. Exemplos de uso

### 6.1 Forcar TLS 1.2 minimo

```pascal
uses
  ssl_openssl11_lib, ssl_openssl11;

var
  LCtx: PSSL_CTX;
begin
  if not InitSSLInterface then Exit;
  // Normalmente feito via TSSLOpenSSL internamente
  LCtx := SslCtxNew(SslMethodTls);
  try
    SslCtxSetMinProtoVersion(LCtx, TLS1_2_VERSION);
    // agora qualquer SSL_new a partir deste ctx recusa TLS 1.0/1.1
  finally
    SslCtxFree(LCtx);
  end;
end;
```

### 6.2 Sobrescrever DLL name antes de init (debug/custom path)

```pascal
uses
  ssl_openssl11_lib;

begin
  DLLSSLName   := 'C:\OpenSSL-1.1.1\bin\libssl-1_1-x64.dll';
  DLLUtilName  := 'C:\OpenSSL-1.1.1\bin\libcrypto-1_1-x64.dll';
  if InitSSLInterface then
    WriteLn('Loaded: ', OpenSSLversion(0));
end;
```

### 6.3 Hash SHA-256 de cert DER

```pascal
uses
  ssl_openssl11_lib;

function CertSHA256(ACert: PX509): AnsiString;
var
  LLen: Cardinal;
begin
  LLen := EVP_MAX_MD_SIZE;
  SetLength(Result, LLen);
  X509Digest(ACert, EvpGetDigestByName('SHA256'), @Result[1], LLen);
  SetLength(Result, LLen);
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Consumida por | `ssl_openssl11.pas` (TSSLOpenSSL) | Unica unit que faz binding |
| Cobre | OpenSSL 1.1.0, 1.1.1 | Unicas versoes suportadas |
| Substitui | `ssl_openssl_lib` | Para quem quer apenas 1.1 sem a complexidade multiversao |
| Substituida por | `ssl_openssl3_lib` (3.x), `ssl_openssl4_lib` (4.0) | Para versoes modernas |
| Runtime | `libssl-1_1.dll` / `libcrypto-1_1.dll` | DLLs dedicadas |
| Dependencia | `synafpc` | RTL cross-compiler |
