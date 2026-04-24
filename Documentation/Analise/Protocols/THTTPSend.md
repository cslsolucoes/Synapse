# THTTPSend

**Unit:** `httpsend.pas` | **Versao:** 003.013.000 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`THTTPSend` e a implementacao cliente HTTP do Ararat Synapse, suportando HTTP/1.0, HTTP/1.1 e HTTPS (via plugin SSL/TLS). A classe herda de `TSynaClient`, herdando toda a infraestrutura de parametrizacao de host/porta/timeout/credenciais, e encapsula um `TTCPBlockSocket` proprio para I/O.

A classe segue as RFC-1867 (form-data upload), RFC-1947 (chunked transfer), RFC-2388 (multipart form data) e RFC-2616 (HTTP/1.1). Oferece suporte nativo a tres mecanismos de transfer encoding (unknown/identity/chunked), gestao de cookies, negociacao de compressao e tunneling HTTPS atraves de proxy HTTP (CONNECT).

E a primitiva fundamental usada em todo o Synapse para operacoes de REST, download de ficheiros, automacao de web forms, webhooks, diagnostico de servicos HTTP e integracao com APIs externas. O Synapse oferece tambem funcoes de conveniencia (`HttpGetText`, `HttpGetBinary`, `HttpPostBinary`, `HttpPostURL`, `HttpPostFile`) que envolvem `THTTPSend` para os casos mais comuns.

## 2. Caracteristicas

- Cliente HTTP/1.0 e HTTP/1.1 com keep-alive configuravel
- Suporte HTTPS (LDAPS equivalente) via plugin SSL/TLS registado em `blcksock`
- Tunneling CONNECT atraves de proxy HTTP (`ProxyHost`/`ProxyPort`/`ProxyUser`/`ProxyPass`)
- Transfer-encoding: identity (Content-Length), chunked (streaming) e unknown (ate fechar conexao)
- Range requests para download parcial / resume (`RangeStart`, `RangeEnd`)
- Gestao automatica de cookies em `TStringList`
- Upload/download por `TMemoryStream` (default) ou `TStream` arbitrario (`InputStream`/`OutputStream`)
- Abort cooperativo (`Abort`) em meio a transferencias (via thread ou hook `OnStatus`)
- Indicadores de progresso: `DownloadSize` / `UploadSize`
- Status 100-continue opcional para upload de grandes payloads (`Status100`)
- User-Agent customizavel (default: `'Mozilla/4.0 (compatible; Synapse)'`)

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Protocolo default | HTTP/1.0 (configuravel para `'1.1'` via `Protocol`) |
| Porta HTTP | `cHttpProtocol = '80'` |
| Porta HTTPS | 443 (quando URL comeca por `https:`) |
| MIME default | `'text/html'` |
| KeepAlive default | `True` |
| KeepAliveTimeout default | 300 segundos |
| UserAgent default | `Mozilla/4.0 (compatible; Synapse)` |
| SSL backend | Plugin registado em `synsock` (ssl_openssl, ssl_openssl3, ssl_openssl4, ssl_cryptlib, ssl_sbb, ssl_streamsec) |
| Transfer encoding | `TTransferEncoding = (TE_UNKNOWN, TE_IDENTITY, TE_CHUNKED)` |
| Herda de | `TSynaClient` (blcksock) |

## 4. Funcionalidades

### 4.1 Construtores / ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Cria a instancia, aloca `TTCPBlockSocket` e inicializa defaults. |
| Destroy | `destructor Destroy; override;` | Fecha socket e liberta headers/cookies/document. |
| Clear | `procedure Clear;` | Reset de `Headers`, `Document` e `MimeType` antes de reutilizar. |
| Abort | `procedure Abort;` | Aborta transferencia corrente (chamavel de outra thread ou de `OnStatus`). |

### 4.2 Operacoes HTTP principais

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| HTTPMethod | `function HTTPMethod(const Method, URL: string): Boolean;` | Executa metodo HTTP arbitrario (GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS) sobre URL. Retorna `True` se handshake TCP + resposta HTTP chegaram ate `ResultCode`. |
| DecodeStatus | `procedure DecodeStatus(const Value: string);` | Parse manual da linha de status HTTP. Uso tipico interno. |

### 4.3 Properties - configuracao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Headers | `property Headers: TStringList read FHeaders;` | Headers de request (antes) e response (depois). |
| Cookies | `property Cookies: TStringList read FCookies;` | Pares `name=value`; persistem entre chamadas. |
| Document | `property Document: TMemoryStream read FDocument;` | Corpo do request (antes) e response (depois). |
| MimeType | `property MimeType: string;` | `Content-Type` do body de saida. |
| Protocol | `property Protocol: string;` | `'1.0'` / `'1.1'` / `'0.9'`. |
| UserAgent | `property UserAgent: string;` | Header `User-Agent`. |
| KeepAlive | `property KeepAlive: Boolean;` | Activa keep-alive HTTP/1.1. |
| KeepAliveTimeout | `property KeepAliveTimeout: integer;` | Em segundos. |
| Status100 | `property Status100: Boolean;` | Pede `Expect: 100-continue` antes de enviar body. |
| RangeStart / RangeEnd | `property RangeStart, RangeEnd: int64;` | Range bytes para download parcial. |
| AddPortNumberToHost | `property AddPortNumberToHost: Boolean;` | Inclui porta no header `Host:`. |

### 4.4 Proxy HTTP

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| ProxyHost | `property ProxyHost: string;` | IP ou hostname do proxy. |
| ProxyPort | `property ProxyPort: string;` | Porta do proxy (default `'8080'`). |
| ProxyUser | `property ProxyUser: string;` | Username Basic Auth no proxy. |
| ProxyPass | `property ProxyPass: string;` | Password Basic Auth no proxy. |

### 4.5 Resultado / status

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| ResultCode | `property ResultCode: Integer;` | Codigo HTTP (200, 404, etc.). |
| ResultString | `property ResultString: string;` | Linha de status completa. |
| DownloadSize | `property DownloadSize: int64;` | Bytes recebidos (uso em barra de progresso). |
| UploadSize | `property UploadSize: int64;` | Bytes enviados. |
| Sock | `property Sock: TTCPBlockSocket;` | Acesso ao socket para `OnStatus`, timeouts, SSL options. |
| InputStream | `property InputStream: TStream;` | Substitui `Document` como origem no upload. |
| OutputStream | `property OutputStream: TStream;` | Substitui `Document` como destino no download. |

### 4.6 Funcoes globais (wrappers)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| HttpGetText | `function HttpGetText(const URL: string; const Response: TStrings): Boolean;` | GET textual em stringlist. |
| HttpGetBinary | `function HttpGetBinary(const URL: string; const Response: TStream): Boolean;` | GET binario para stream. |
| HttpPostBinary | `function HttpPostBinary(const URL: string; const Data: TStream): Boolean;` | POST stream in/out. |
| HttpPostURL | `function HttpPostURL(const URL, URLData: string; const Data: TStream): Boolean;` | POST `application/x-www-form-urlencoded`. |
| HttpPostFile | `function HttpPostFile(const URL, FieldName, FileName: string; const Data: TStream; const ResultData: TStrings): Boolean;` | POST `multipart/form-data` (RFC-2388). |

## 5. Aplicabilidades

1. **Integracao REST** -- consumo de APIs JSON/XML, envio de payloads com `Content-Type: application/json` e leitura de `Document` como texto.
2. **Download com resume** -- uso de `RangeStart`/`RangeEnd` para retomar transferencias interrompidas.
3. **Upload multipart** -- submissao de ficheiros para formularios web com `HttpPostFile` ou preparacao manual do body multipart.
4. **Scraping / automacao web** -- manter sessao via `Cookies` entre chamadas consecutivas.
5. **Tunnel HTTPS via proxy corporativo** -- `ProxyHost` + HTTPS para atravessar gateways internos.
6. **Webhooks / callbacks** -- envio de notificacoes POST para sistemas externos.

## 6. Exemplos de uso

### 6.1 GET simples (funcao de conveniencia)

```pascal
uses
  SysUtils, Classes, httpsend;

var
  LResponse: TStringList;
begin
  LResponse := TStringList.Create;
  try
    if HttpGetText('http://example.com/api/status', LResponse) then
      Writeln(LResponse.Text);
  finally
    LResponse.Free;
  end;
end.
```

### 6.2 POST JSON com `THTTPSend` directo

```pascal
uses
  SysUtils, Classes, httpsend, synautil;

var
  LHttp: THTTPSend;
  LBody: AnsiString;
begin
  LHttp := THTTPSend.Create;
  try
    LBody := '{"name":"João","age":42}';
    WriteStrToStream(LHttp.Document, LBody);
    LHttp.MimeType := 'application/json';
    LHttp.Headers.Add('Accept: application/json');
    LHttp.Headers.Add('Authorization: Bearer eyJhbGc...');
    if LHttp.HTTPMethod('POST', 'https://api.example.com/v1/users') then
      Writeln('Status: ', LHttp.ResultCode, ' - ', LHttp.ResultString)
    else
      Writeln('Falha de ligacao');
  finally
    LHttp.Free;
  end;
end.
```

### 6.3 Download binario com barra de progresso via OnStatus

```pascal
uses
  SysUtils, Classes, httpsend, blcksock;

type
  TDownloadProgress = class
    procedure OnStatus(Sender: TObject; Reason: THookSocketReason; const Value: string);
  end;

procedure TDownloadProgress.OnStatus(Sender: TObject; Reason: THookSocketReason;
  const Value: string);
begin
  if Reason = HR_ReadCount then
    Write(Format(#13'Recebidos: %s bytes', [Value]));
end;

var
  LHttp: THTTPSend;
  LFile: TFileStream;
  LProgress: TDownloadProgress;
begin
  LHttp := THTTPSend.Create;
  LProgress := TDownloadProgress.Create;
  try
    LHttp.Sock.OnStatus := LProgress.OnStatus;
    if LHttp.HTTPMethod('GET', 'https://example.com/big-file.zip') then
    begin
      LFile := TFileStream.Create('/path/to/output.zip', fmCreate);
      try
        LHttp.Document.Position := 0;
        LFile.CopyFrom(LHttp.Document, LHttp.Document.Size);
      finally
        LFile.Free;
      end;
    end;
  finally
    LProgress.Free;
    LHttp.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` (blcksock) | Superclasse | Parametriza host/porta/timeout/user/pass. |
| `TTCPBlockSocket` (blcksock) | Composicao | Socket TCP usado para I/O HTTP. |
| `synsock` | Dependencia | Camada de sockets portavel. |
| `synautil` | Dependencia | Helpers de string/URL/stream. |
| `synaip` | Dependencia | Parse de IPv4/IPv6. |
| `synacode` | Dependencia | Base64, URL-encoding, quoted-printable. |
| `ssl_openssl` / `ssl_openssl3` / `ssl_openssl4` | Plugin | Adicionam suporte HTTPS quando o URL usa `https:`. |
| `TMimeMess` (mimemess) | Consumidor indirecto | Gera body multipart para POST. |
