---
name: synapse-csl-http-modernization
version: 1.0.0
date: 2026-04-22
author: CSL Softwares
status: draft
scope: >
  Onda 2 — Modernizacao do httpsend.pas para cobrir OAuth 2.0 Bearer
  (RFC 6750), cookies persistentes, keepalive real, chunked transfer
  encoding robusto e HTTP/2 parcial (mode upgrade). Inspirado em ICS
  THttpCli (design pattern apenas — codigo 100% BSD 3-Clause proprio).
depends-on:
  - Synapse CSL fork 001.007.004 / V41.2
  - Onda 1 V41.3 (TSslRootCAStore) — RECOMENDADA mas nao bloqueante
  - Master plan: synapse-csl-ics-modernization-master_V1.0.plan.md
target-file: Packege/synapse/httpsend.pas
target-version: 003.013.000 → 003.014.000
target-package-version: V41.3 → V41.4
protected-area: Packege/synapse/ — requer aprovacao antes de execucao
impact-on-adorm: NULO — ADORM nao usa HTTP
target-compilers:
  - Delphi 12.x (Win32 / Win64)
  - FPC 3.3.1+ (i386-win32 / x86_64-win64)
out-of-scope:
  - HTTP/2 completo (HPACK + streams multiplexing) — agendar V41.5.1
  - WebSocket upgrade (RFC 6455) — agendar V41.7
  - Proxy PAC script auto-detect — agendar futuro
  - Streaming download com callback de progresso — evaluar V41.4.1
licensing: >
  Reimplementacao conceitual do padrao ICS THttpCli. Zero linhas de codigo
  ICS copiadas. RFC 7230 (HTTP/1.1), RFC 6265 (Cookies), RFC 6750 (Bearer),
  RFC 7540 (HTTP/2 upgrade) sao as unicas referencias.
---

# V41.4 — HTTP modernization (Onda 2 de 4)

> **Status:** draft — area protegida `Packege/synapse/` requer aprovacao.
> Ler plano mestre primeiro: [synapse-csl-ics-modernization-master_V1.0.plan.md](synapse-csl-ics-modernization-master_V1.0.plan.md).

---

## 1. Contexto

`THTTPSend` actual (003.013.000) cobre HTTP/1.1 basico:

- Verbos GET/POST/PUT/DELETE/HEAD/OPTIONS.
- Basic/Digest/NTLM authentication.
- Proxy HTTP/HTTPS.
- Redirects manuais.
- Cookies volateis (`Cookies: TStringList` sem persistencia entre requests).
- Chunked transfer encoding read (mas sem robustez em trailers).

Gaps:

| Gap | Impacto em consumidor moderno |
|---|---|
| Sem OAuth 2.0 Bearer | Nao consome APIs Azure/AWS/GCP/GitHub/M365 sem hack manual |
| Cookies nao persistem | Sessao web quebra em cada request |
| Keepalive parcial | Overhead TCP/TLS handshake a cada request |
| Sem HTTP/2 upgrade | Servidores H2-only rejeitam; mesmo H2/HTTP1.1 negociacao falha em HTTP-only |
| Sem JSON helpers | Consumer duplica `ContentType := 'application/json'` + serializacao |

---

## 2. API nova

### 2.1 OAuth 2.0 Bearer Token

```pascal
TLHTTPSend = class(...)
  // ... membros existentes ...
private
  FBearerToken: AnsiString;
published
  {: V41.4 — RFC 6750 Authorization: Bearer <token>.
     Se definido, tem prioridade sobre UserName/Password (Basic). }
  property BearerToken: AnsiString read FBearerToken write FBearerToken;
end;
```

Implementacao: no metodo `InternalDoRequest`, antes de enviar headers:

```pascal
if FBearerToken <> '' then
  FHeaders.Insert(0, 'Authorization: Bearer ' + string(FBearerToken))
else if FUserName <> '' then
  // Basic — comportamento actual, sem alteracao
```

### 2.2 Cookie Jar (`TCookieJar`)

```pascal
type
  TCookieEntry = record
    Name, Value, Domain, Path: AnsiString;
    Expires: TDateTime;
    Secure, HttpOnly: Boolean;
  end;

  {:@abstract(V41.4 — Jar de cookies com persistencia entre requests.
     RFC 6265 compliant (attributes Max-Age, Expires, Domain, Path,
     Secure, HttpOnly).)}
  TCookieJar = class
  private
    FEntries: array of TCookieEntry;
    FLock: TRTLCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;

    {: Chamado por THTTPSend apos cada resposta — parse de Set-Cookie. }
    procedure AbsorbFromResponse(const AHost: AnsiString; AHeaders: TStrings);

    {: Chamado por THTTPSend antes de cada request — constrói header Cookie:. }
    function BuildCookieHeader(const AHost, APath: AnsiString): AnsiString;

    {: Serializacao / Deserializacao em formato Netscape cookies.txt. }
    procedure SaveToFile(const APath: string);
    procedure LoadFromFile(const APath: string);

    {: Limpa cookies expirados; chamado periodicamente. }
    procedure PurgeExpired;

    {: Remove todos. }
    procedure Clear;
  end;
```

Integracao em `THTTPSend`:

```pascal
THTTPSend = class(...)
  // ...
private
  FCookieJar: TCookieJar;
published
  property CookieJar: TCookieJar read FCookieJar write FCookieJar;
end;
```

Uso:

```pascal
LHTTP := THTTPSend.Create;
LHTTP.CookieJar := TCookieJar.Create;
try
  LHTTP.CookieJar.LoadFromFile('cookies.txt');
  // fazer varios requests — cookies persistem automaticamente
  LHTTP.CookieJar.SaveToFile('cookies.txt');
finally
  LHTTP.CookieJar.Free;
  LHTTP.Free;
end;
```

### 2.3 Keepalive real

Actual: `THTTPSend.KeepAlive` existe mas a conexao e reaberta entre requests
em muitos cenarios por `Sock.CloseSocket` implicito.

Nova: property `SessionActive` + metodo `ResetBetweenRequests`:

```pascal
property SessionActive: Boolean read FSessionActive;

{: Reset de estado logico entre requests mantendo a conexao TCP/TLS.
   Chamado automaticamente se KeepAlive=True e servidor anuncia
   Connection: keep-alive. Fecha conexao se servidor anunciar
   Connection: close. }
procedure ResetBetweenRequests;
```

### 2.4 Helpers JSON

```pascal
{: V41.4 — POST com body JSON + Content-Type: application/json + Accept: application/json. }
function THTTPSend.PostJSON(const AURL, ABodyJSON: AnsiString): Boolean;

{: V41.4 — GET com Accept: application/json. }
function THTTPSend.GetJSON(const AURL: AnsiString): AnsiString;
```

### 2.5 HTTP/2 upgrade (parcial)

Suporta apenas a negociacao `Upgrade: h2c` (cleartext) e handshake inicial.
Streams multiplexing e HPACK ficam para V41.5.1.

```pascal
property AllowH2Upgrade: Boolean read FAllowH2Upgrade write FAllowH2Upgrade default False;
```

Se activa, envia header `Connection: Upgrade, HTTP2-Settings` + `Upgrade: h2c` + `HTTP2-Settings: <base64>`. Se servidor responde `101 Switching Protocols`, a conexao passa a HTTP/2 — mas `THTTPSend` falha proximo request com `E501 HTTP/2 streams nao implementado — agendado V41.5.1`. Servidores que devolvem HTTP/1.1 continuam a funcionar.

---

## 3. Alteracoes em `httpsend.pas`

| Bloco | Conteudo | LoC |
|---|---|---:|
| Interface — `TCookieJar` declaracao | Classe completa + record `TCookieEntry` | ~100 |
| Interface — `THTTPSend` extensoes | +5 properties + 2 metodos | ~30 |
| Implementation — parser `Set-Cookie` RFC 6265 | Tokenize + attributes + expires | ~120 |
| Implementation — builder `Cookie:` com matching domain/path | Domain matching + path prefix | ~80 |
| Implementation — Bearer injection em headers | ~10 |
| Implementation — `PostJSON` / `GetJSON` helpers | Atalhos existentes + JSON MIME | ~60 |
| Implementation — keepalive tracking + reset | Tracking de `Connection:` header | ~50 |
| Implementation — H2 upgrade stub | Apenas handshake; stream reject | ~30 |
| Header — bloco CSL V41.4 + bump 003.013.000 → 003.014.000 | Documentacao | ~20 |

**Total:** ~500 LoC novo, ~120 modificado.

---

## 4. Backup obrigatorio

```powershell
$backDir = 'Packege\synapse\bak'
$ts = (Get-Date).ToString('yyyyMMdd_HHmm')
Copy-Item 'Packege\synapse\httpsend.pas' -Destination "$backDir\httpsend.$ts.bak"
```

---

## 5. Compatibilidade

| Caso | Comportamento |
|---|---|
| Codigo actual sem tocar `BearerToken`/`CookieJar`/`AllowH2Upgrade` | Identico a V41.3. |
| `BearerToken := 'xxx'` + `UserName := 'abc'` | Bearer ganha prioridade (RFC 6750). |
| `CookieJar = nil` | Comportamento actual — cookies volateis em `Cookies` TStringList. |
| `AllowH2Upgrade := True` + servidor HTTP/1.1 | Servidor ignora o upgrade header, resposta HTTP/1.1 normal. |
| `AllowH2Upgrade := True` + servidor aceita H2 | Proximo request falha com `E501` documentado. |

ADORM nao afectado (nao usa HTTP).

---

## 6. Documentacao

- `Packege/synapse/VERSION.md` — bump V41.3 → V41.4.
- `Packege/synapse/Synapse.Version.inc` — +`SYNAPSE_V41_4_OR_HIGHER` + `SYNAPSE_HTTP_OAUTH2_BEARER` + `SYNAPSE_HTTP_COOKIE_JAR` + `SYNAPSE_HTTP_H2_UPGRADE_STUB`.
- `Packege/synapse/README.md`.
- `Packege/synapse/Documentation/README.md`.
- **Revisao** `Packege/synapse/Documentation/Analise/Protocols/THTTPSend.md` — 5 secoes novas (Bearer, Cookie Jar, Keepalive, JSON helpers, H2 upgrade).
- **NOVO** `Packege/synapse/Documentation/Analise/Protocols/TCookieJar.md` — analise completa.

---

## 7. Verificacao

### 7.1 Compilacao

```powershell
dcc32 ActiveDirectoryORM.dpr    # so para confirmar que httpsend compila limpo no dpr
dcc64 ActiveDirectoryORM.dpr
```

Gate: 2/2 Delphi verde.

### 7.2 Smoke tests

`tests/HttpModern.Smoke.dpr` — sequencia contra servicos publicos:

1. **Bearer** — GET `https://httpbin.org/bearer` com `BearerToken := 'test123'`; esperar `200 {"authenticated":true,"token":"test123"}`.
2. **Cookies persistentes** — `POST https://httpbin.org/cookies/set?foo=bar`, salvar em ficheiro, recriar HTTPSend, carregar ficheiro, `GET https://httpbin.org/cookies`; esperar `{"cookies":{"foo":"bar"}}`.
3. **JSON helpers** — `PostJSON('https://httpbin.org/post', '{"k":"v"}')`; esperar response com `{"json":{"k":"v"}}`.
4. **Keepalive** — 5 requests seguidos contra `https://httpbin.org/get`; verificar `Sock.SessionAge` aumenta; `SessionActive = True` entre requests.
5. **H2 upgrade** — `AllowH2Upgrade := True`; `GET https://httpbin.org/get` (HTTP/1.1 only); verificar resposta OK (servidor ignora).

Se qualquer falhar, imprimir `FAIL: <n>` e `Halt(n)`.
Se todas passarem, `SMOKE_OK`.

### 7.3 Backcompat

`tests/HttpBackCompat.Smoke.dpr`:

1. Codigo velho com `UserName`/`Password` Basic — `200`.
2. `Cookies.Add('session=abc')` direct sem CookieJar — `200`.
3. Sem `BearerToken` — comportamento actual.
4. `SMOKE_OK`.

---

## 8. Criterios de aceitacao

- [ ] Backup `Packege/synapse/bak/httpsend.<YYYYMMDD_HHMM>.bak` criado.
- [ ] `httpsend.pas` bump 003.013.000 → 003.014.000 com bloco CSL V41.4.
- [ ] `TCookieJar` + `TCookieEntry` publicas com parse/build RFC 6265.
- [ ] `THTTPSend.BearerToken` + `CookieJar` + `AllowH2Upgrade` + `PostJSON`/`GetJSON` + `ResetBetweenRequests`.
- [ ] `BearerToken` tem prioridade sobre `UserName/Password`.
- [ ] Matriz Delphi Win32+Win64 verde.
- [ ] Smoke `HttpModern.Smoke.dpr` imprime `SMOKE_OK`.
- [ ] Backcompat smoke passa.
- [ ] Zero codigo ICS copiado.
- [ ] `VERSION.md` + `Synapse.Version.inc` + README + Analise/Protocols/THTTPSend.md actualizados.
- [ ] `Analise/Protocols/TCookieJar.md` criado.

---

## 9. Roadmap pos-V41.4

- **V41.4.1** — Streaming download com callback (`OnProgress`).
- **V41.5.1** — HTTP/2 completo (HPACK + streams multiplexing).
- **V41.7** — WebSocket RFC 6455.

---

**Changelog (este arquivo):**

- 1.0.0 (22/04/2026): Criacao. Onda 2 de 4 ICS-inspired modernization. Status draft — requer aprovacao.
