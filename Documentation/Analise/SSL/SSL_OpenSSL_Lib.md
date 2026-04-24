# SSL_OpenSSL_Lib / ssl_openssl_lib.pas

**Unit:** `ssl_openssl_lib.pas` | **Versao:** 003.009.001 | **Tipo:** Unit (imports dinamicos) | **Origem:** Upstream Synapse (Lukas Gebauer, Petr Fejfar, Pepak)

---

## 1. O que e?

`ssl_openssl_lib.pas` e a unit que declara o **binding Pascal para OpenSSL** historico do Synapse, cobrindo as versoes 0.9.6 a 1.1.x num unico ficheiro. Todos os simbolos OpenSSL (funcoes, estruturas, constantes, pointers opacos) estao declarados aqui como `var` (nao como `external` directos) porque a unit faz **late binding** — as DLLs sao carregadas em runtime via `LoadLibrary`/`GetProcAddress` pela funcao `InitSSLInterface`, que resolve cada funcao para o seu ponteiro.

Essa estrategia permite que uma aplicacao compile e execute mesmo sem OpenSSL instalada; se as DLLs nao forem encontradas, `InitSSLInterface` retorna `False` e o resto do codigo simplesmente nao terá SSL disponivel (Synapse nao registra `TSSLOpenSSL` em `SSLImplementation`). Lista de DLLs tentadas (Windows, ordem de busca em `LibCount = 5`): `libssl-3*.dll`, `libssl-1_1*.dll`, `ssleay32-x64/x86.dll`, `ssleay32.dll`, `libssl32.dll`. Em Linux: `libssl.so`/`libcrypto.so` ou `libssl.dylib`/`libcrypto.dylib` em macOS.

Esta e a unit consumida exclusivamente por `ssl_openssl.pas` (OpenSSL 0.9.x-1.1.x legacy). Para versoes modernas, usar `ssl_openssl11_lib`, `ssl_openssl3_lib`, `ssl_openssl4_lib`.

---

## 2. Caracteristicas

- **Late binding:** DLLs carregadas em runtime, nao em compile-time.
- **Tolerancia a ausencia:** aplicacao compila e arranca mesmo sem libssl/libcrypto.
- **Multi-DLL fallback:** `SSLLibNames[]` e `CryptoLibNames[]` (5 entradas) tentam varios nomes historicos.
- **Platform-aware:** Windows, Linux/BSD, OS/2, macOS, .NET (CIL parcial com `DLLSSLName` constante).
- **Lock multithread:** `locking_callback` para OpenSSL <1.0.2 (pre-native locks) — implementado em Delphi/FPC via critical sections.
- **2300 linhas:** incluindo ~200 imports de funcoes OpenSSL + constantes + estruturas.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` | FPC em modo Delphi |
| `{$IFDEF BCB}` | C++ Builder compat |
| `{$IFDEF CIL}` | .NET — usa `DllImport` em vez de `LoadLibrary` |
| `synafpc` | RTL cross-compiler do Synapse |
| `Windows.pas` / Libc / BaseUnix | Imports de `LoadLibrary`/`dlopen` |

Nomes de DLL testados (Windows):

| Ordem | Nome SSL | Nome Crypto | Versao OpenSSL |
| --- | --- | --- | --- |
| 0 | `libssl-3(-x64).dll` | `libcrypto-3(-x64).dll` | 3.0+ |
| 1 | `libssl-1_1(-x64).dll` | `libcrypto-1_1(-x64).dll` | 1.1.x |
| 2 | `ssleay32-x64/x86.dll` | `libeay32-x64/x86.dll` | 1.0.2 arch-suffixed |
| 3 | `ssleay32.dll` | `libeay32.dll` | 1.0.2 generic |
| 4 | `libssl32.dll` | `libeay32.dll` | ancient |

---

## 4. Funcionalidades

### 4.1 Tipos opacos (pointers)

| Tipo | Definicao | Descricao |
| --- | --- | --- |
| `SslPtr` | `Pointer` | Generic opaque ptr |
| `PSSL_CTX` | `SslPtr` | OpenSSL context |
| `PSSL` | `SslPtr` | SSL session |
| `PSSL_METHOD` | `SslPtr` | Method (TLSv1_method, etc) |
| `PX509` | `SslPtr` | Certificate |
| `PX509_NAME` | `SslPtr` | Subject/Issuer name |
| `PEVP_MD` | `SslPtr` | Hash algorithm |
| `PBIO`, `PBIO_METHOD` | `SslPtr` | Basic I/O |
| `EVP_PKEY` | `SslPtr` | Private/public key |
| `PRSA`, `PASN1_UTCTIME`, `PASN1_INTEGER`, `PSTACK` | `SslPtr` | Structs opacas |

### 4.2 Constantes principais

Erros SSL: `SSL_ERROR_NONE=0`, `SSL_ERROR_SSL=1`, `SSL_ERROR_WANT_READ=2`, `SSL_ERROR_WANT_WRITE=3`, `SSL_ERROR_ZERO_RETURN=6`. Options: `SSL_OP_NO_SSLv2`, `SSL_OP_NO_SSLv3`, `SSL_OP_NO_TLSv1`, `SSL_OP_ALL`. Verify: `SSL_VERIFY_NONE=0`, `SSL_VERIFY_PEER=1`. `EVP_MAX_MD_SIZE=36`. `X509_V_OK=0` + ~50 codes X509_V_ERR_*.

### 4.3 Imports de runtime (funcoes principais)

| Funcao | Categoria | Descricao |
| --- | --- | --- |
| `InitSSLInterface` | Loader | Carrega DLLs, resolve simbolos, retorna Boolean |
| `DestroySSLInterface` | Loader | Liberta DLLs e `SetLength(Symbols,0)` |
| `IsSSLloaded` | Loader | True se DLLs foram carregadas com sucesso |
| `SslLibraryInit` | Init | Inicializa lib (OpenSSL <1.1) |
| `SslLoadErrorStrings` | Init | Carrega mensagens de erro |
| `SslCtxNew` | Context | Cria `SSL_CTX` para method |
| `SslCtxFree` | Context | Liberta CTX |
| `SslCtxSetVerify` | Context | Configura modo de verificacao |
| `SslCtxUseCertificate` | Context | Carrega cert |
| `SslCtxUsePrivateKey` | Context | Carrega chave |
| `SslCtxLoadVerifyLocations` | Context | CA bundle |
| `SslCtxCtrl` | Context | Wrapper de `SSL_CTX_ctrl` (tuning) |
| `SslNew` | Session | Cria `SSL` sobre `SSL_CTX` |
| `SslFree` | Session | Liberta sessao |
| `SslSetFd` | Session | Associa socket descriptor |
| `SslConnect` | Handshake | Cliente |
| `SslAccept` | Handshake | Servidor |
| `SslShutdown` | Handshake | Encerramento |
| `SslWrite` | I/O | Escrita cifrada |
| `SslRead` | I/O | Leitura cifrada |
| `SslPending` | I/O | Bytes pendentes |
| `SslGetError` | I/O | Ultimo erro (tipo) |
| `SslGetVersion` | Info | Versao protocolo negociado |
| `SslGetCurrentCipher` | Info | Cipher suite |
| `SslCipherGetName` | Info | Nome cipher |
| `SslCipherGetBits` | Info | Bits cipher |
| `SslGetPeerCertificate` | Cert | Retorna `PX509` remoto |
| `SslGetVerifyResult` | Cert | Resultado validacao |
| `SslCtrl` | Ctrl | Wrapper de `SSL_ctrl` (SNI via `SSL_CTRL_SET_TLSEXT_HOSTNAME`) |
| `SslSet1Host` | Cert | Define host esperado (moderno) |
| `X509Free` | X509 | Liberta cert |
| `X509Digest` | X509 | Hash (MD5/SHA1/SHA256) do cert DER |
| `X509GetSubjectName` | X509 | Subject name |
| `X509GetIssuerName` | X509 | Issuer name |
| `X509GetSerialNumber` | X509 | Serial |
| `X509NameOneline` | X509 | Formata name em string |
| `X509NameHash` | X509 | Hash do name |
| `X509Print` | X509 | Dump textual |
| `EvpGetDigestByName` | Digest | Resolve MD por nome ('SHA256', etc) |
| `ErrGetError` | Error | Pop ultimo erro stack |
| `ErrErrorString` | Error | Formata codigo em string |
| `SSLeay_version` | Info | Versao da lib carregada |
| `RandBytes`, `RandSeed` | Random | PRNG |
| `EVP_DigestInit`, `EVP_DigestUpdate`, `EVP_DigestFinal` | Digest | Hash streaming |
| `EVP_EncryptInit`, `EVP_EncryptUpdate`, `EVP_EncryptFinal` | Cipher | Symmetric crypto |
| `RsaGenerateKey`, `EvpPkeyNew`, `EvpPkeyFree` | Keys | Manipulacao chaves |
| `d2i_PKCS12_bio`, `PKCS12_parse` | PKCS12 | Parse PFX |
| `ENGINE_by_id`, `ENGINE_init`, `ENGINE_finish`, `ENGINE_free` | Engine | API engine (usada por CAPI) |

### 4.4 Callbacks

| Callback | Assinatura | Descricao |
| --- | --- | --- |
| `PPasswdCb` | `function(buf:PAnsiChar; size,rwflag:Integer; userdata:Pointer):Integer; cdecl` | Callback para password de private key |
| `verify_callback` | `function(preverify_ok:Integer; x509_store_ctx:Pointer):Integer; cdecl` | Callback de verificacao de cert |
| `locking_callback` | Multithread | Lock para OpenSSL <1.0.2 |
| `thread_id_callback` | Multithread | Identifier de thread |

---

## 5. Aplicabilidades

1. **Base de `ssl_openssl.pas`:** unica forma de consumir esta unit.
2. **Compatibilidade historica OpenSSL 0.9.x-1.1.x:** suporta a janela completa.
3. **Indirecta para toda a familia HTTPS/LDAPS/SMTPS:** qualquer protocolo Synapse com SSL via `TSSLOpenSSL` acaba aqui.
4. **Engine API:** unico caminho para usar ENGINE_* em Delphi/FPC via Synapse (CAPI).
5. **Extensao para CBT SHA-256:** o fork CSL usa `X509Digest` + `EvpGetDigestByName('SHA256')` para implementar `GetPeerCertSHA256Hash`.

---

## 6. Exemplos de uso

### 6.1 Verificar carregamento OpenSSL no startup

```pascal
uses
  ssl_openssl_lib;

begin
  if InitSSLInterface then
    WriteLn('OpenSSL loaded: ', SSLeay_version(0))
  else
    WriteLn('OpenSSL nao encontrada - TLS indisponivel');
end;
```

### 6.2 Shutdown manual (raro, em tests)

```pascal
uses
  ssl_openssl_lib;

begin
  if IsSSLloaded then
  begin
    // Usar Synapse normalmente
    DestroySSLInterface;   // libera DLLs no final
  end;
end;
```

### 6.3 Hash SHA-256 de buffer via OpenSSL

```pascal
uses
  ssl_openssl_lib;

function SHA256Hex(const AData: AnsiString): AnsiString;
var
  Ctx: EVP_MD_CTX;
  MD: PEVP_MD;
  DigestLen: Cardinal;
  Digest: array [0..31] of Byte;
  i: Integer;
begin
  Result := '';
  if not InitSSLInterface then Exit;

  MD := EvpGetDigestByName('SHA256');
  EVP_DigestInit(@Ctx, MD);
  EVP_DigestUpdate(@Ctx, PAnsiChar(AData), Length(AData));
  DigestLen := 32;
  EVP_DigestFinal(@Ctx, @Digest[0], DigestLen);

  for i := 0 to 31 do
    Result := Result + AnsiString(IntToHex(Digest[i], 2));
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Consumida por | `ssl_openssl.pas` (TSSLOpenSSL) | Unica unit que faz binding a ela |
| Consumida por | `ssl_openssl_capi.pas` (TSSLOpenSSLCapi) | Via heranca (extende TSSLOpenSSL) — usa ENGINE_* desta unit |
| Cobre | OpenSSL 0.9.x, 1.0.x, 1.1.x | Faixa historica completa |
| Substituida por | `ssl_openssl11_lib` (1.1.x only), `ssl_openssl3_lib` (3.x), `ssl_openssl4_lib` (4.0) | Para versoes modernas recomenda-se as libs dedicadas |
| Runtime | `libssl`, `libcrypto` | DLL/so/dylib por plataforma |
| Dependencia transversal | `synafpc` | RTL cross-compiler |
