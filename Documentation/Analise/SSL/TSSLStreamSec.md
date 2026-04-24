# TSSLStreamSec / ssl_streamsec.pas

**Unit:** `ssl_streamsec.pas` | **Versao:** 001.000.006 | **Tipo:** Classe | **Origem:** Upstream Synapse (Lukas Gebauer, Henrick Hellstrom)

---

## 1. O que e?

`TSSLStreamSec` e o plugin SSL/TLS do Synapse baseado em **StreamSec TLS Pro** (hoje `StreamSecII` / `OpenStreamSecII`), um toolkit criptografico nativo Pascal desenvolvido por Henrick Hellstrom (StreamSec AB, Suecia). A grande caracteristica do StreamSecII e ser **100% Pascal sem DLLs externas** — tudo o codigo criptografico (AES, RSA, ECDSA, TLS handshake, X.509 parse) e nativo Delphi/FPC, com static link completo.

A classe usa `TMyTLSSynSockSlave` (um descendant de `TTLSSynSockSlave` da StreamSec) como ponte entre Synapse e o `TCustomTLSInternalServer` que faz o trabalho TLS real. A tipica divisao StreamSec e: um servidor TLS global (`GlobalServer`) que tem chave/cert uma vez, e slaves que servem conexoes individuais. O plugin suporta ambos os modos: usar o `GlobalServer` configurado externamente (recomendado) ou criar um `TSimpleTLSInternalServer` por conexao (limitado — `KeyPassword` nao funciona correctamente).

A manipulacao de certs usa nomenclatura StreamSec (`TASN1Struct`, `TX500String`, `TX501Name`) — radicalmente diferente de OpenSSL (PX509/X509_NAME), exposta via helpers internos `X500StrToStr` e `X501NameToStr`.

---

## 2. Caracteristicas

- **100% Pascal, zero DLLs:** produto principal.
- **Comercial:** licenca paga (StreamSec TLS Pro); OpenStreamSecII tem variantes open.
- **GlobalServer ou PerConnection:** duas formas de configurar certs.
- **Evento `NotTrust`:** callback para aceitar/rejeitar cert nao confiavel.
- **Tipos proprios ASN.1:** nao partilha API com OpenSSL — reescrita completa.
- **KeyPassword nao totalmente suportado:** limitacao documentada quando GlobalServer nao e usado.
- **TLSSynSockSlave:** integra StreamSec com socket Synapse — bridge customizada.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` | FPC em modo Delphi |
| `TlsInternalServer` | Servidor TLS interno StreamSec |
| `TlsSynaSock` | Base para slave synapse-compatible |
| `TlsConst` | Constantes de alertas e tipos TLS |
| `StreamSecII` | Nucleo da biblioteca |
| `Asn1`, `X509Base` | Parse ASN.1 e certificados |
| `SecUtils` | Utilitarios crypto genericos |

---

## 4. Funcionalidades

### 4.1 Classe auxiliar TMyTLSSynSockSlave

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SetMyTLSServer` | `procedure SetMyTLSServer(const Value: TCustomTLSInternalServer)` | Atribui servidor TLS ao slave |
| `GetMyTLSServer` | `function GetMyTLSServer: TCustomTLSInternalServer` | Le servidor TLS associado |
| `MyTLSServer` (published) | `TCustomTLSInternalServer` | Property que expoe `TLSServer` |

### 4.2 Ciclo de vida TSSLStreamSec

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); override` | `FSlave := nil; FIsServer := False; FTLSServer := nil` |
| `Destroy` | `destructor Destroy; override` | `DeInit` + herdado |

### 4.3 Metodos protegidos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SSLCheck` | `function SSLCheck: Boolean` | Converte `FSlave.ErrorCode` em `FLastError` via `TlsConst.AlertMsg` |
| `Init` | `function Init(server: Boolean): Boolean` | Cria slave, configura `MyTLSServer` (global ou local) |
| `DeInit` | `function DeInit: Boolean` | Liberta slave e servidor local (se criado por este plugin) |
| `Prepare` | `function Prepare(server: Boolean): Boolean` | Init + carregamento de cert/chave no TLSServer |
| `NotTrustEvent` | `procedure NotTrustEvent(Sender; Cert: TASN1Struct; var ExplicitTrust: Boolean)` | Callback de cert nao confiavel |
| `X500StrToStr` | `function X500StrToStr(const Prefix: string; const Value: TX500String): string` | Formata string X.500 |
| `X501NameToStr` | `function X501NameToStr(const Value: TX501Name): string` | Formata nome X.501 |
| `GetCert` | `function GetCert: PASN1Struct` | Retorna ponteiro ASN.1 do cert peer |

### 4.4 Conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Connect` | `function Connect: boolean; override` | Handshake client-side |
| `Accept` | `function Accept: boolean; override` | Handshake server-side |
| `Shutdown` | `function Shutdown: boolean; override` | Encerramento uni-direccional |
| `BiShutdown` | `function BiShutdown: boolean; override` | Encerramento bi-direccional |

### 4.5 Transferencia

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Envio cifrado |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Recepcao cifrada |
| `WaitingData` | `function WaitingData: Integer; override` | Bytes pendentes no slave |

### 4.6 Informacoes de cert e sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string; override` | Versao TLS negociada |
| `GetPeerSubject` | `function GetPeerSubject: string; override` | Subject via `X501NameToStr(GetCert.Subject)` |
| `GetPeerIssuer` | `function GetPeerIssuer: string; override` | Issuer |
| `GetPeerName` | `function GetPeerName: string; override` | CN |
| `GetPeerFingerprint` | `function GetPeerFingerprint: ansistring; override` | Fingerprint |
| `GetCertInfo` | `function GetCertInfo: string; override` | Dump ASN.1 formatado |

### 4.7 Publicadas

| Propriedade | Tipo | Descricao |
| --- | --- | --- |
| `TLSServer` | `TCustomTLSInternalServer` | Servidor TLS externo (tuning detalhado StreamSec) |

### 4.8 Plugin info

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LibVersion` | `function LibVersion: String; override` | `'StreamSecII'` |
| `LibName` | `function LibName: String; override` | `'ssl_streamsec'` |

---

## 5. Aplicabilidades

1. **Self-contained executables:** zero dependencia de DLLs externas — distribuir so o `.exe`.
2. **Ambientes proibidos de OpenSSL:** politicas corporativas que banem especificamente `libssl`/`libcrypto`.
3. **Tuning fino via GlobalServer:** aplicacoes com muitas conexoes que beneficiam de cache de sessao centralizado.
4. **Compliance com codigo auditado:** StreamSec oferece auditoria e relatorios — alternativa a FIPS-only.
5. **Solucao OEM / embedded Delphi:** build static deploy em aparelhos sem permissao para DLLs.

---

## 6. Exemplos de uso

### 6.1 Cliente HTTPS com tuning via GlobalServer

```pascal
uses
  TlsInternalServer, httpsend, ssl_streamsec;

var
  LHTTP: THTTPSend;
begin
  // GlobalServer assumido configurado previamente no startup
  LHTTP := THTTPSend.Create;
  try
    (LHTTP.Sock.SSL as TSSLStreamSec).TLSServer := GlobalServer;
    if LHTTP.HTTPMethod('GET', 'https://api.empresa.local/health') then
      WriteLn('HTTP ', LHTTP.ResultCode);
  finally
    LHTTP.Free;
  end;
end;
```

### 6.2 Servidor TLS com cert em arquivo

```pascal
uses
  blcksock, ssl_streamsec;

var
  LServer, LClient: TTCPBlockSocket;
  LClientSock: TSocket;
begin
  LServer := TTCPBlockSocket.Create;
  try
    LServer.Bind('0.0.0.0', '8443');
    LServer.Listen;
    LClientSock := LServer.Accept;

    LClient := TTCPBlockSocket.CreateWithSSL(TSSLStreamSec);
    try
      LClient.Socket := LClientSock;
      LClient.SSL.CertificateFile := 'server.crt';
      LClient.SSL.PrivateKeyFile  := 'server.key';
      LClient.SSLAcceptConnection;
    finally
      LClient.Free;
    end;
  finally
    LServer.Free;
  end;
end;
```

### 6.3 Cliente com callback para cert nao confiavel

```pascal
uses
  blcksock, ssl_streamsec;

var
  LSock: TTCPBlockSocket;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.SSL := TSSLStreamSec.Create(LSock);
    LSock.SSL.VerifyCert := True;
    // NotTrustEvent interno decide sobre certs - pode ser sobreposto
    LSock.Connect('self-signed.empresa.local', '443');
    LSock.SSLDoConnect;

    WriteLn('Subject: ', LSock.SSL.GetPeerSubject);
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
| Depende de | StreamSec TLS Pro (StreamSecII) | Licenciamento comercial (OpenStreamSecII e open) |
| Classe auxiliar | `TMyTLSSynSockSlave` | Bridge Slave <-> TTCPBlockSocket |
| Componentes | `TCustomTLSInternalServer`, `TSimpleTLSInternalServer` | Motor TLS StreamSec |
| Alternativa comercial | `TSSLSBB` (SecureBlackBox) | Outro toolkit pago |
| Alternativa open | `TSSLOpenSSL3/4`, `TSSLCryptLib` | Open source |
| Limitacao | `KeyPassword` sem GlobalServer | Use GlobalServer para pwd-protected keys |
