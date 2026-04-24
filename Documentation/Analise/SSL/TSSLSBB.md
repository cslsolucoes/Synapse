# TSSLSBB / ssl_sbb.pas + ssl_sbb16.pas

**Unit:** `ssl_sbb.pas` + `ssl_sbb16.pas` | **Versao:** 001.000.006 | **Tipo:** Classe | **Origem:** Upstream Synapse (Lukas Gebauer, Allen Drennan)

> Nota: `ssl_sbb.pas` visa SecureBlackBox 10+; `ssl_sbb16.pas` visa SecureBlackBox 16+. Ambas declaram a classe `TSSLSBB` (nomes identicos, units diferentes). Nunca importar as duas units no mesmo projecto.

---

## 1. O que e?

`TSSLSBB` e o plugin SSL/TLS do Synapse baseado em **EldoS SecureBlackBox** (hoje parte da `/n software`), um toolkit criptografico comercial para Delphi/C++. SecureBlackBox distingue-se de OpenSSL/cryptlib por ser **nativo Pascal** (sem DLLs externas — static link com os `.dcu`s do produto), por suportar uma ampla gama de formatos de cert (X.509, PKCS#12, PFX, PEM, ASN.1 DER), e por integrar com Windows Certificate Store via `TElWinCertStorage`.

O plugin usa componentes `TElSSLClient` e `TElSSLServer` atraves de eventos (`OnCertificateValidate`, `OnData`, `OnError`, `OnReceive`, `OnSend`) — e necessariamente um wrapper baseado em eventos Delphi. Cada conexao mantem um buffer de recepcao explicito (`FRecvBuffer`, `FRecvBuffers`, `FRecvDecodedBuffers`) para alinhar com a interface sincrona de `TCustomSSL`.

A diferenca entre `ssl_sbb.pas` e `ssl_sbb16.pas` e na API de callbacks da propria SecureBlackBox — a v16 renomeou tipos (`TSBBoolean` -> `TSBCertificateValidity/Reason`) e re-estruturou `OnReceive` com `var Written: Int32` em vez de `out`. Escolha a unit que corresponde a versao da SecureBlackBox instalada.

---

## 2. Caracteristicas

- **Comercial (EldoS/n software):** licenca paga; nao e open source.
- **Native Pascal:** sem DLLs externas — static link.
- **Windows-focus (mas multi-plataforma):** `ssl_sbb.pas` importa `Windows.pas`; `ssl_sbb16.pas` isola em `$IFDEF MSWINDOWS`.
- **Event-driven interno:** usa `TElSSLClient`/`TElSSLServer` com 5 eventos, traduzindo para API sincrona de `TCustomSSL`.
- **Certificados multi-formato:** X.509, PKCS#12, PFX, PEM, ASN.1 DER — todos suportados nativamente.
- **Windows Cert Store integration:** via `TElWinCertStorage` (ssl_sbb.pas).
- **Cipher Suite selection:** exposto via `TBits` (`CipherSuites`).
- **Diferenca v10 vs v16:** assinaturas de callbacks (`Int32` vs `LongInt`), tipos de validity.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` | FPC em modo Delphi |
| SBSSLClient, SBSSLServer | Componentes principais (cliente/servidor TLS) |
| SBSSLConstants, SBX509, SBUtils | Constantes e utilitarios SecureBlackBox |
| SBWinCertStorage (ssl_sbb.pas) | Integracao Windows Cert Store |
| SBSessionPool (ssl_sbb.pas) | Reuso de sessoes TLS |
| SBCustomCertStorage | Base para storage de certs em memoria |

`ssl_sbb16.pas` desacopla `Windows` (so usado em `$IFDEF MSWINDOWS` na implementation).

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); override` | Inicializa `TElSSLClient`/`TElSSLServer`, `TElMemoryCertStorage`, buffers |
| `Destroy` | `destructor Destroy; override` | Liberta componentes, cert storage, cipher suites |
| `Reset` | `procedure Reset` (private) | Reset de estado interno entre conexoes |

### 4.2 Metodos protegidos / privados

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Prepare` | `function Prepare(Server: Boolean): Boolean` | Configura cipher, certs, event handlers |
| `FileToString` | `function FileToString(const lFile: string): AnsiString` | Le ficheiro para AnsiString |
| `GetCipherSuite` | `function GetCipherSuite: Integer` | Mapeia `TBits` para indice SBB |
| `OnCertificateValidate` | `procedure OnCertificateValidate(...; var Validate: TSBBoolean)` ou `TSBCertificateValidity` (sbb16) | Callback de validacao cert remoto |
| `OnData` | `procedure OnData(Sender; Buffer; Size)` | Dados decifrados prontos para `RecvBuffer` |
| `OnError` | `procedure OnError(Sender; ErrorCode; Fatal; Remote)` | Propaga erro para `FLastError` |
| `OnReceive` | `procedure OnReceive(Sender; Buffer; MaxSize; out/var Written)` | Transport recv — le do `TTCPBlockSocket` |
| `OnSend` | `procedure OnSend(Sender; Buffer; Size)` | Transport send — envia via socket |

### 4.3 Conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Connect` | `function Connect: Boolean; override` | Handshake client-side (TElSSLClient.Open) |
| `Accept` | `function Accept: Boolean; override` | Handshake server-side (TElSSLServer.Open) |
| `Shutdown` | `function Shutdown: Boolean; override` | Encerramento uni-direccional |
| `BiShutdown` | `function BiShutdown: Boolean; override` | Encerramento bi-direccional |

### 4.4 Transferencia

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Passa bytes a camada TLS (TElSSL*.SendData) |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Le do buffer interno preenchido por `OnData` |
| `WaitingData` | `function WaitingData: Integer; override` | `Length(FRecvDecodedBuffers)` |

### 4.5 Informacoes de cert

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string; override` | Mapeia indice SBB para string (`TLSv1.2`, etc) |
| `GetPeerSubject` | `function GetPeerSubject: string; override` | Subject DN via `TElX509Certificate` |
| `GetPeerIssuer` | `function GetPeerIssuer: string; override` | Issuer DN |
| `GetPeerName` | `function GetPeerName: string; override` | CN |
| `GetPeerFingerprint` | `function GetPeerFingerprint: ansistring; override` | Fingerprint |
| `GetCertInfo` | `function GetCertInfo: string; override` | Dump completo |

### 4.6 Publicadas

| Propriedade | Tipo | Descricao |
| --- | --- | --- |
| `ElSecureClient` | `TElSSLClient` | Expoe componente cliente para tuning directo |
| `ElSecureServer` | `TElSSLServer` | Expoe componente servidor |
| `CipherSuites` | `TBits` | Conjunto de cipher suites habilitadas |
| `CipherSuite` | `Integer` (somente leitura) | Indice da cipher negociada |

### 4.7 Plugin info

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LibVersion` | `function LibVersion: string; override` | Versao SBB |
| `LibName` | `function LibName: string; override` | `'ssl_sbb'` ou `'ssl_sbb16'` |

---

## 5. Aplicabilidades

1. **Projectos comerciais licenciados SecureBlackBox:** quando ja se paga pela suite, usar este plugin e natural.
2. **Certificados em multiplos formatos exoticos:** SBB tem parser robusto para PKCS#12 com quirks de diferentes emissores.
3. **Windows Cert Store (v10):** via `TElWinCertStorage` — alternativa a `TSSLOpenSSLCapi`.
4. **Seleccao granular de cipher suites:** `CipherSuites: TBits` permite bit-mask fino.
5. **Deploy sem DLLs:** static link com `.dcu`s resulta em `.exe` self-contained.

---

## 6. Exemplos de uso

### 6.1 Cliente HTTPS SBB v10

```pascal
uses
  SysUtils, httpsend, ssl_sbb;

var
  LHTTP: THTTPSend;
  LSSL: TSSLSBB;
begin
  LHTTP := THTTPSend.Create;
  try
    LHTTP.Sock.SSL := TSSLSBB.Create(LHTTP.Sock);
    LSSL := LHTTP.Sock.SSL as TSSLSBB;
    LSSL.CertCAFile := 'ca-bundle.pem';
    LSSL.VerifyCert := True;

    if LHTTP.HTTPMethod('GET', 'https://api.empresa.local/ping') then
      WriteLn('HTTP ', LHTTP.ResultCode, ' (cipher ', LSSL.CipherSuite, ')');
  finally
    LHTTP.Free;
  end;
end;
```

### 6.2 Servidor TLS com SBB v16

```pascal
uses
  blcksock, ssl_sbb16;

var
  LServer, LClient: TTCPBlockSocket;
  LClientSock: TSocket;
  LSSL: TSSLSBB;
begin
  LServer := TTCPBlockSocket.Create;
  try
    LServer.Bind('0.0.0.0', '8443');
    LServer.Listen;
    LClientSock := LServer.Accept;

    LClient := TTCPBlockSocket.CreateWithSSL(TSSLSBB);
    try
      LClient.Socket := LClientSock;
      LSSL := LClient.SSL as TSSLSBB;
      LSSL.PFXFile := 'server.pfx';
      LSSL.KeyPassword := 'pfxpass';
      LClient.SSLAcceptConnection;
    finally
      LClient.Free;
    end;
  finally
    LServer.Free;
  end;
end;
```

### 6.3 Seleccao de cipher suites

```pascal
uses
  blcksock, ssl_sbb, SBSSLConstants;

var
  LSock: TTCPBlockSocket;
  LSSL: TSSLSBB;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.SSL := TSSLSBB.Create(LSock);
    LSSL := LSock.SSL as TSSLSBB;
    // Apenas AES-GCM
    LSSL.CipherSuites.Clear;
    LSSL.CipherSuites[SB_SUITE_ECDHE_RSA_AES256_GCM_SHA384] := True;
    LSock.Connect('api.empresa.local', '443');
    LSock.SSLDoConnect;
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
| Vinculado a | `TTCPBlockSocket` | Via `TTCPBlockSocket.SSL` |
| Depende de | SecureBlackBox 10+ (`ssl_sbb.pas`) ou 16+ (`ssl_sbb16.pas`) | Licenciamento comercial |
| Componentes | `TElSSLClient`, `TElSSLServer`, `TElX509Certificate` | Wraps sobre componentes SBB |
| Windows Cert Store | `TElWinCertStorage` (ssl_sbb.pas) | Integracao nativa |
| Alternativa comercial | `TSSLStreamSec` (ssl_streamsec.pas) | Outro toolkit pago |
| Alternativa open | `TSSLOpenSSL3`, `TSSLCryptLib` | Sem licenciamento |
| Conflito de nome | Ambas units declaram `TSSLSBB` | Importar apenas uma das duas |
