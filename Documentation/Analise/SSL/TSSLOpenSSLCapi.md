# TSSLOpenSSLCapi / ssl_openssl_capi.pas

**Unit:** `ssl_openssl_capi.pas` | **Versao:** 001.003.000 | **Tipo:** Classe | **Origem:** Upstream Synapse (Pepak, 2018)

---

## 1. O que e?

`TSSLOpenSSLCapi` estende `TSSLOpenSSL` (do `ssl_openssl.pas`) acrescentando integracao com o Windows Certificate Store via CAPI engine da OpenSSL (`capi.dll`). Permite usar certificados/chaves privadas armazenadas no Certificate Store do Windows (CurrentUser, LocalMachine, Services, etc.) sem os ter de exportar para PFX/PEM — tipico para smartcards, HSM via CNG, ou politicas corporativas que proibem export de chave privada.

Quando o engine CAPI nao esta disponivel (OpenSSL nao compilou com engine, `capi.dll` ausente), a classe degrada silenciosamente para o comportamento base `TSSLOpenSSL` — a presenca do engine e opcional. A escolha do certificado e feita pelas propriedades `SigningCertificateLocation` / `SigningCertificateStore` / `SigningCertificateID`. O engine e global por processo OpenSSL (limitacao da biblioteca), portanto uma vez habilitado nao pode ser trocado em runtime.

---

## 2. Caracteristicas

- **Herda de TSSLOpenSSL:** reaproveita 100% do pipeline TLS base (handshake, SNI, cert info).
- **Windows-only:** depende de `Crypt32.pas` (import da `crypt32.dll`) — unit nao compila em Linux/macOS.
- **Engine CAPI opcional:** plugin detecta `capi.dll` em runtime; se ausente comporta-se como `TSSLOpenSSL` puro.
- **8 Certificate Store locations:** enum `TWindowsCertStoreLocation` cobre `CurrentUser`, `LocalMachine`, `Services`, `Users`, variantes com Group Policy e Enterprise.
- **Engine pool:** sob `{$DEFINE USE_ENGINE_POOL}` reutiliza engines entre conexoes para reduzir overhead de init.
- **Engine global:** apos primeiro `ENGINE_init` nao e possivel desligar — reflete limitacao da OpenSSL.
- **OpenSSL 1.0.2 testada:** 1.1.x precisa build custom com `enable-static-engine`.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$INCLUDE 'jedi.inc'}` | Defines JEDI |
| `{$DEFINE USE_ENGINE_POOL}` | Activa `TEnginePool` para reutilizar engines entre handshakes |
| `Crypt32` (unit) | Imports de `crypt32.dll` (CertOpenStore, CertFindCertificateInStore, etc.) |
| `ssl_openssl` + `ssl_openssl_lib` | Base do plugin SSL |
| `capi.dll` | DLL opcional do engine CAPI OpenSSL (distribuido com Stunnel, build custom) |
| `ENGINE_by_id('capi')` | Resolucao runtime do engine |

---

## 4. Funcionalidades

### 4.1 Tipos

| Tipo | Definicao | Descricao |
| --- | --- | --- |
| `PENGINE` | `Pointer` | Handle opaco para engine OpenSSL |
| `TWindowsCertStoreLocation` | enum `(wcslCurrentUser, wcslCurrentUserGroupPolicy, wcslUsers, wcslCurrentService, wcslServices, wcslLocalMachine, wcslLocalMachineGroupPolicy, wcslLocalMachineEnterprise)` | Locations do Windows Certificate Store |

### 4.2 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); override` | Inicializa engine-related fields; store default = `'MY'`, location default = `wcslCurrentUser` |
| `Destroy` | `destructor Destroy; override` | Liberta engine (retorna ao pool ou `ENGINE_finish`+`ENGINE_free`) |
| `Assign` | `procedure Assign(const Value: TCustomSSL); override` | Copia SigningCertificate properties de outro TSSLOpenSSLCapi |
| `InitEngine` | `class function InitEngine: boolean` | Carrega/valida engine CAPI globalmente; opcional (plugin carrega on-demand) |

### 4.3 Metodos protegidos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LoadSigningCertificate` | `function LoadSigningCertificate: boolean` | Busca cert no Windows Store via `CertOpenStore` + `CertFindCertificateInStore`, carrega no engine |
| `SetSslKeys` | `function SetSslKeys: boolean; override` | Override — integra engine ao ctx SSL |
| `NeedSigningCertificate` | `function NeedSigningCertificate: boolean; override` | True se CAPI estiver configurado |
| `SigningCertificateSpecified` | `function SigningCertificateSpecified: boolean` | True se `FSigningCertificateID <> ''` |
| `GetEngine` | `function GetEngine: PENGINE` | Lazy-load: pega do pool ou inicializa novo via `InitCapiEngine` |

### 4.4 Propriedades publicas

| Propriedade | Tipo | Descricao |
| --- | --- | --- |
| `SigningCertificateLocation` | `TWindowsCertStoreLocation` | Location do store (default `wcslCurrentUser`) |
| `SigningCertificateStore` | `string` | Nome do store (default `'MY'` = Personal) |
| `SigningCertificateID` | `string` | CAPI: friendly name; server-side: substring do SubjectName |
| `Engine` | `PENGINE` (somente leitura) | Engine OpenSSL corrente |

### 4.5 Metodos herdados (publicos de TSSLOpenSSL)

Todos os ~20 metodos de `TSSLOpenSSL` sao herdados inalterados: `Connect`, `Accept`, `SendBuffer`, `RecvBuffer`, `GetPeerSubject`, `GetPeerIssuer`, `GetSSLVersion`, `GetCipherName`, `GetCertInfo`, `GetVerifyCert`, `LibVersion`, `LibName`, etc.

---

## 5. Aplicabilidades

1. **Autenticacao cliente TLS com cert no Windows Store:** ideal para smartcards, HSM via CNG, ou enterprise PKI que proibe export de chave.
2. **Servidor TLS usando cert do `LocalMachine\MY`:** IIS-style — certificado instalado via MMC, sem ficheiros PFX expostos.
3. **Integracao com Group Policy:** `wcslCurrentUserGroupPolicy` / `wcslLocalMachineGroupPolicy` le certs distribuidos por politica AD.
4. **Servicos Windows:** `wcslServices` / `wcslCurrentService` para certs proprios de um service account.
5. **Fallback transparente:** se `capi.dll` ausente comporta-se como `TSSLOpenSSL` base.

---

## 6. Exemplos de uso

### 6.1 Cliente HTTPS com cert do Current User

```pascal
uses
  SysUtils, httpsend, blcksock, ssl_openssl_capi;

var
  LHTTP: THTTPSend;
  LSSL: TSSLOpenSSLCapi;
begin
  LHTTP := THTTPSend.Create;
  try
    LHTTP.Sock.SSL := TSSLOpenSSLCapi.Create(LHTTP.Sock);
    LSSL := LHTTP.Sock.SSL as TSSLOpenSSLCapi;
    LSSL.SigningCertificateLocation := wcslCurrentUser;
    LSSL.SigningCertificateStore    := 'MY';
    LSSL.SigningCertificateID       := 'Joao Silva';   // friendly name

    if LHTTP.HTTPMethod('GET', 'https://api.empresa.local/mtls') then
      WriteLn('HTTP ', LHTTP.ResultCode);
  finally
    LHTTP.Free;
  end;
end;
```

### 6.2 Init explicito do engine no startup

```pascal
uses
  ssl_openssl_capi;

begin
  if TSSLOpenSSLCapi.InitEngine then
    WriteLn('CAPI engine disponivel')
  else
    WriteLn('CAPI indisponivel - fallback TSSLOpenSSL');
end;
```

### 6.3 Servidor TLS com cert do LocalMachine

```pascal
uses
  blcksock, ssl_openssl_capi;

var
  LServer, LClient: TTCPBlockSocket;
  LClientSock: TSocket;
  LSSL: TSSLOpenSSLCapi;
begin
  LServer := TTCPBlockSocket.Create;
  try
    LServer.Bind('0.0.0.0', '8443');
    LServer.Listen;
    LClientSock := LServer.Accept;

    LClient := TTCPBlockSocket.CreateWithSSL(TSSLOpenSSLCapi);
    try
      LClient.Socket := LClientSock;
      LSSL := LClient.SSL as TSSLOpenSSLCapi;
      LSSL.SigningCertificateLocation := wcslLocalMachine;
      LSSL.SigningCertificateStore    := 'MY';
      LSSL.SigningCertificateID       := 'api.empresa.local';
      LClient.SSLAcceptConnection;
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
| Herda de | `TSSLOpenSSL` (ssl_openssl.pas) | Reutiliza todo o pipeline TLS base |
| Vinculado a | `TTCPBlockSocket` | Acessivel via `TTCPBlockSocket.SSL` |
| Usa | `Crypt32` (Crypt32.pas) | Imports de `crypt32.dll` para Windows Cert Store |
| Usa | `ssl_openssl_lib` | Imports OpenSSL (ENGINE API) |
| Usa | `TEnginePool` (mesma unit) | Pool de engines CAPI para reduzir overhead |
| Depende de | `capi.dll` (opcional) | Sem ela degrada para `TSSLOpenSSL` |
| Windows-only | `Windows.pas` | Nao compila em Linux/macOS |
| Alternativa no Windows | `TSSLSBB` (SecureBlackbox) | Outro backend com suporte a Windows Cert Store |
