# SSL_OpenSSL4_Lib / ssl_openssl4_lib.pas

**Unit:** `ssl_openssl4_lib.pas` | **Versao:** 001.004.000 (CSL fork) | **Tipo:** Unit (imports dinamicos) | **Origem:** CSL fork (100% novo, 2026-04-21)

---

## 1. O que e?

`ssl_openssl4_lib.pas` e o **fork mecanico** de `ssl_openssl3_lib.pas`, criado pelo CSL fork do Synapse para carregar OpenSSL 4.0.0 (FireDaemon Fusion build). A decisao de fork em vez de extensao com IFDEF deveu-se a dois factores: (1) a OpenSSL 4.0 mudou o sufixo dos nomes de DLL de `-3` para `-4` (por exemplo `libssl-4-x64.dll`); (2) manter fluxos de teste totalmente independentes — um build com `USE_OPENSSL3` nunca toca em `ssl_openssl4_lib`, e vice-versa.

**8 nomes de DLL bumped `-3` -> `-4`:**

| Plataforma / Arch | V3 (original) | V4 (fork CSL) |
| --- | --- | --- |
| Windows 32 SSL | `libssl-3.dll` | `libssl-4.dll` |
| Windows 32 Crypto | `libcrypto-3.dll` | `libcrypto-4.dll` |
| Windows 64 SSL | `libssl-3-x64.dll` | `libssl-4-x64.dll` |
| Windows 64 Crypto | `libcrypto-3-x64.dll` | `libcrypto-4-x64.dll` |
| Linux SSL | `libssl.so.3` | `libssl.so.4` |
| Linux Crypto | `libcrypto.so.3` | `libcrypto.so.4` |
| macOS SSL | `libssl.3.dylib` | `libssl.4.dylib` |
| macOS Crypto | `libcrypto.3.dylib` | `libcrypto.4.dylib` |

**Assinaturas Pascal identicas:** a API binaria OpenSSL 3.x+4.0 e unificada (confirmado por ICS V9.6), entao todos os ponteiros de funcao, tipos opacos, constantes e assinaturas Pascal sao iguais. O fork e literalmente um copy-paste com 8 strings editadas.

---

## 2. Caracteristicas

- **OpenSSL 4.0 exclusivo:** FireDaemon Fusion builds; API identica a 3.x.
- **Sem IFDEF para 3.x:** separacao completa para isolamento de risco.
- **8 DLLs bumped:** mudanca mecanica e documentada no header.
- **ICS V9.6 confirma compat API:** garantia de que 4.0 nao quebra codigo Pascal.
- **Mutuamente exclusivo com USE_OPENSSL3:** defines condicionais em `ORM.Defines.inc` obrigam escolha.
- **Fail-safe default:** se DLLs nao presentes, aplicacao arranca sem SSL disponivel.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` | FPC em modo Delphi |
| `synafpc` | RTL cross-compiler |
| `Windows.pas` / BaseUnix / Libc | Imports de loader |
| `DLLSSLName` / `DLLUtilName` | Variaveis publicas sobrescritas com sufixo `-4` |

Valores default das variaveis (Windows):

```pascal
{$IFDEF WIN64}
DLLSSLName:  string = 'libssl-4-x64.dll';
DLLUtilName: string = 'libcrypto-4-x64.dll';
{$ELSE}
DLLSSLName:  string = 'libssl-4.dll';
DLLUtilName: string = 'libcrypto-4.dll';
{$ENDIF}
```

---

## 4. Funcionalidades

### 4.1 Tipos opacos

**Identicos a `ssl_openssl3_lib`.** Lista completa: `SslPtr = Pointer`, `PSslPtr`, `PSSL_CTX`, `PSSL`, `PSSL_METHOD`, `PX509`, `PX509_NAME`, `PX509_STORE`, `PEVP_MD`, `PBIO`, `PBIO_METHOD`, `EVP_PKEY`, `PRSA`, `PASN1_UTCTIME`, `PASN1_INTEGER`, `PPasswdCb`, `PSTACK`, `PInteger`, `DES_cblock`, `PDES_cblock`, `des_ks_struct`, `des_key_schedule`. Callbacks: `TSkPopFreeFunc`, `TX509Free`, `PFunction`.

### 4.2 Constantes

**Identicas a `ssl_openssl3_lib`:** `EVP_MAX_MD_SIZE = 36`, `SSL_ERROR_*` (8 codes), `SSL_OP_*`, `SSL_VERIFY_*`, `OPENSSL_DES_DECRYPT/ENCRYPT`, `X509_V_*` (~50 codes), `SSL_FILETYPE_*`, `EVP_PKEY_RSA = 6`, `SSL_CTRL_SET_TLSEXT_HOSTNAME = 55`, `SSL_CTRL_SET_MIN/MAX_PROTO_VERSION`, `TLSEXT_NAMETYPE_host_name = 0`, `TLS1_VERSION..TLS1_3_VERSION`.

### 4.3 Imports

**Identicos a `ssl_openssl3_lib`.** Categorias:

| Categoria | Exemplos |
| --- | --- |
| Loader | `InitSSLInterface`, `DestroySSLInterface`, `IsSSLloaded` |
| Context lifecycle | `SslCtxNew`, `SslCtxFree`, `TLS_method`, `TLS_server_method`, `TLS_client_method` |
| Context config | `SslCtxSetVerify`, `SslCtxSetCipherList`, `SslCtxLoadVerifyLocations`, `SslCtxSetMinProtoVersion`, `SslCtxSetMaxProtoVersion` |
| Load material | `SslCtxUseCertificate`, `SslCtxUsePrivateKey`, `SslCtxUseCertificateFile`, `SslCtxUsePrivateKeyFile` |
| Session | `SslNew`, `SslFree`, `SslSetFd`, `SslConnect`, `SslAccept`, `SslShutdown` |
| I/O | `SslWrite`, `SslRead`, `SslPending`, `SslGetError` |
| Info | `SslGetVersion`, `SslGetCurrentCipher`, `SslCipherGetName`, `SslCipherGetBits` |
| Peer cert | `SslGetPeerCertificate`, `SslGetVerifyResult` |
| Ctrl wrappers | `SslCtrl`, `SslSet1Host` |
| X509 | `X509Digest`, `X509NameOneline`, `X509NameHash`, `X509GetSubjectName`, `X509GetIssuerName`, `X509GetSerialNumber`, `X509Free`, `X509Print` |
| Digest | `EvpGetDigestByName`, `EVP_DigestInit`, `EVP_DigestUpdate`, `EVP_DigestFinal` |
| Error stack | `ErrGetError`, `ErrErrorString` |
| Version | `OpenSSLversion` |
| PRNG | `RandBytes`, `RandSeed` |
| PKCS12 | `d2i_PKCS12_bio`, `PKCS12_parse` |

### 4.4 Diferencas vs ssl_openssl3_lib

1. **Nome do ficheiro:** `ssl_openssl4_lib.pas` em vez de `ssl_openssl3_lib.pas`.
2. **Nome da unit:** `unit ssl_openssl4_lib;`.
3. **Defaults DLLSSLName/DLLUtilName:** sufixo `-4` em vez de `-3` (8 strings).
4. **Header CSL:** documenta fork com racional e data (2026-04-21).

**Nenhuma outra diferenca.** Se a API OpenSSL 4.0 vier a divergir, este ficheiro sera actualizado; ate la e copia directa.

---

## 5. Aplicabilidades

1. **Teste prospectivo da ABI 4.x:** validar apps com FireDaemon Fusion builds antes do release oficial.
2. **Producao com libs 4.0:** assim que OpenSSL 4.0 for GA, troca-se `USE_OPENSSL3` por `USE_OPENSSL4` sem tocar em mais nada.
3. **A/B testing de performance:** 3.6.2 vs 4.0.0 no mesmo codigo Pascal.
4. **Suporte a vendors que bumparam nomes de DLL:** algumas distros experimentais preferem `-4` para distinguir.

---

## 6. Exemplos de uso

### 6.1 Verificar versao 4.0 em runtime

```pascal
uses
  ssl_openssl4_lib;

begin
  if InitSSLInterface then
    WriteLn('OpenSSL 4: ', OpenSSLversion(0))
  else
    WriteLn('libssl-4 nao encontrada');
end;
```

### 6.2 Custom path para FireDaemon

```pascal
uses
  ssl_openssl4_lib;

begin
  DLLSSLName  := 'C:\FireDaemon-4\openssl\libssl-4-x64.dll';
  DLLUtilName := 'C:\FireDaemon-4\openssl\libcrypto-4-x64.dll';
  InitSSLInterface;
end;
```

### 6.3 Runtime path via TOpenSSLPaths

```pascal
uses
  ssl_openssl_paths, ssl_openssl4_lib, ssl_openssl4;

begin
  TOpenSSLPaths.Apply(4);   // aponta dll\v4\<arch>\
  // ssl_openssl4 registra TSSLOpenSSL4 em SSLImplementation automaticamente
end.
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Consumida por | `ssl_openssl4.pas` (TSSLOpenSSL4) | Unica unit que faz binding |
| Fork mecanico de | `ssl_openssl3_lib.pas` | 8 strings alteradas, resto identico |
| Cobre | OpenSSL 4.0.0 FireDaemon Fusion | Unica versao |
| API | Unificada com 3.x (ICS V9.6 confirma) | Migracao 3 -> 4 sem ajustes de codigo |
| Runtime | `libssl-4(-x64).dll` / `libcrypto-4(-x64).dll` | DLLs bumped |
| Mutuamente exclusivo | `ssl_openssl3_lib.pas` via `USE_OPENSSL3`/`USE_OPENSSL4` | Escolha por build |
| Integracao | `TOpenSSLPaths.Apply(4)` | Aponta para `dll\v4\<arch>\` |
