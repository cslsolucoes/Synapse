---
name: synapse-csl-imap-modernization
version: 1.0.0
date: 2026-04-22
author: CSL Softwares
status: draft
scope: >
  Onda 4 — Modernizacao do imapsend.pas para cobrir IDLE (RFC 2177),
  UIDPLUS (RFC 4315), SEARCH estendido (RFC 3501 completo), XOAUTH2
  (Google/Microsoft) e CONDSTORE/QRESYNC (RFC 7162) opcional. Inspirado
  em ICS TImapCli (design pattern apenas — codigo 100% BSD 3-Clause
  proprio).
depends-on:
  - Synapse CSL fork 001.007.004 / V41.2
  - Onda 1 V41.3 (TSslRootCAStore) — RECOMENDADA
  - Master plan: synapse-csl-ics-modernization-master_V1.0.plan.md
target-file: Packege/synapse/imapsend.pas
target-version: upstream → 002.008.000 (CSL fork)
target-package-version: V41.5 → V41.6
protected-area: Packege/synapse/ — requer aprovacao antes de execucao
impact-on-adorm: NULO — ADORM nao usa IMAP
target-compilers:
  - Delphi 12.x (Win32 / Win64)
  - FPC 3.3.1+ (i386-win32 / x86_64-win64)
out-of-scope:
  - JMAP (RFC 8620) — protocolo diferente; agendar V41.8 se relevante
  - Full SEARCH BODY fulltext — exige indexer; fora do escopo de cliente
  - Push notifications via APNS/FCM — camada aplicacao
  - MIME decoding complexo (manter delegado a mimemess.pas existente)
licensing: >
  Reimplementacao conceitual do padrao ICS TImapCli. Zero linhas de codigo
  ICS copiadas. RFC 3501 (IMAP4rev1), RFC 2177 (IDLE), RFC 4315 (UIDPLUS),
  RFC 7628 (SASL OAUTH), RFC 7162 (CONDSTORE/QRESYNC) sao as referencias.
---

# V41.6 — IMAP modernization (Onda 4 de 4)

> **Status:** draft — area protegida `Packege/synapse/` requer aprovacao.
> Ler plano mestre primeiro: [synapse-csl-ics-modernization-master_V1.0.plan.md](synapse-csl-ics-modernization-master_V1.0.plan.md).

---

## 1. Contexto

`TIMAPSend` upstream cobre IMAP4rev1 basico:

- LOGIN / AUTHENTICATE LOGIN / PLAIN / CRAM-MD5.
- SELECT / EXAMINE / CREATE / DELETE / RENAME.
- LIST / LSUB.
- FETCH basico.
- STORE / EXPUNGE.
- SEARCH basico.
- LOGOUT.

Gaps para uso moderno:

| Gap | Impacto |
|---|---|
| Sem IDLE | Polling obrigatorio; latencia >= intervalo de polling |
| SEARCH incompleto | Nao suporta `SENTBEFORE/SENTON/SENTSINCE`, `HEADER <field>`, `TEXT`, `OR`, `NOT` RFC 3501 |
| Sem UIDPLUS | APPEND sem `APPENDUID`; COPY sem `COPYUID`; perda de identificacao em moves |
| Sem XOAUTH2 | Bloqueia Gmail/M365 modern auth |
| Sem CAPABILITY negotiation | Codigo duplica "o servidor suporta X?" checks |

---

## 2. API nova

### 2.1 IDLE (RFC 2177) — notificacoes push

```pascal
type
  TIMAPIdleEvent = (
    ieExists,     // caixa ganhou mensagem(s) — arg = novo total
    ieExpunge,    // mensagem expunged — arg = sequence number
    ieRecent,     // total RECENT mudou — arg = novo RECENT
    ieFetchFlags  // flags de mensagem mudaram — arg = seq number
  );

  TIMAPIdleCallback = procedure(Sender: TObject; AEvent: TIMAPIdleEvent;
                                AArg: Integer) of object;

  TIMAPSend = class(...)
    // ...
  private
    FIdleCallback: TIMAPIdleCallback;
  public
    {: V41.6 — Entra em modo IDLE (RFC 2177). Callback dispara por cada
       notificacao do servidor. Retorna quando:
       - consumidor chamar `IdleStop` (de outra thread);
       - timeout `AMaxMinutes` e atingido (RFC sugere re-entry a cada 29 min);
       - servidor fecha com BYE.
       Deve ser chamado em thread dedicada — bloqueia o consumidor. }
    function Idle(const ACallback: TIMAPIdleCallback;
                  AMaxMinutes: Integer = 29): Boolean;

    {: V41.6 — Envia DONE ao servidor para sair de IDLE. Thread-safe. }
    procedure IdleStop;
  end;
```

Implementacao:

```pascal
function TIMAPSend.Idle(const ACallback: TIMAPIdleCallback;
                         AMaxMinutes: Integer): Boolean;
var
  LDeadline: TDateTime;
  LLine: AnsiString;
begin
  if not SupportsCapability('IDLE') then
    raise EIMAPError.Create('Servidor nao suporta IDLE (RFC 2177)');

  SendCommand('IDLE');
  if not WaitContinuation then  // '+ idling'
    Exit(False);

  FIdleActive := True;
  FIdleCallback := ACallback;
  LDeadline := Now + EncodeTime(0, AMaxMinutes, 0, 0);

  while FIdleActive and (Now < LDeadline) do
  begin
    if FSock.CanRead(1000) then  // poll 1 segundo
    begin
      LLine := FSock.RecvString(5000);
      ProcessIdleNotification(LLine, ACallback);
    end;
  end;

  FSock.SendString('DONE' + CRLF);
  Result := ReadTaggedResponse = 'OK';
  FIdleActive := False;
end;
```

### 2.2 SEARCH estendido (RFC 3501 completo)

```pascal
type
  {: V41.6 — Builder fluente para SEARCH. Gera a sintaxe RFC 3501
     sem o consumidor ter que aprender o protocolo. }
  TIMAPSearchBuilder = record
  strict private
    FCriteria: TStringList;
  public
    class function Create: TIMAPSearchBuilder; static;

    function All: TIMAPSearchBuilder;
    function Seen: TIMAPSearchBuilder;
    function Unseen: TIMAPSearchBuilder;
    function Flagged: TIMAPSearchBuilder;
    function Deleted: TIMAPSearchBuilder;
    function From_(const AEmail: AnsiString): TIMAPSearchBuilder;
    function To_(const AEmail: AnsiString): TIMAPSearchBuilder;
    function Subject(const ASubstr: AnsiString): TIMAPSearchBuilder;
    function Body(const ASubstr: AnsiString): TIMAPSearchBuilder;
    function Text(const ASubstr: AnsiString): TIMAPSearchBuilder;
    function Header(const AField, AValue: AnsiString): TIMAPSearchBuilder;
    function Since(const ADate: TDateTime): TIMAPSearchBuilder;
    function Before(const ADate: TDateTime): TIMAPSearchBuilder;
    function SentSince(const ADate: TDateTime): TIMAPSearchBuilder;
    function Larger(ABytes: Int64): TIMAPSearchBuilder;
    function Smaller(ABytes: Int64): TIMAPSearchBuilder;
    function OR_(const ALeft, ARight: TIMAPSearchBuilder): TIMAPSearchBuilder;
    function NOT_(const AInner: TIMAPSearchBuilder): TIMAPSearchBuilder;

    function Build: AnsiString;   // gera a string SEARCH final
  end;

  TIMAPSend = class(...)
    function SearchEx(const ABuilder: TIMAPSearchBuilder): TArray<Integer>;
    function SearchUid(const ABuilder: TIMAPSearchBuilder): TArray<Int64>;
  end;
```

Uso:

```pascal
LUids := LIMAP.SearchUid(
  TIMAPSearchBuilder.Create
    .Unseen
    .From_('noreply@github.com')
    .Since(EncodeDate(2026, 4, 1))
    .Subject('[PR]')
);
// devolve TArray<Int64> com os UIDs
```

### 2.3 UIDPLUS (RFC 4315)

Quando servidor anuncia `CAPABILITY UIDPLUS`, novos metodos:

```pascal
{: V41.6 — APPEND que devolve o UID atribuido (RFC 4315). }
function AppendUid(const AMailbox: AnsiString; const AFlags: array of AnsiString;
                   const AInternalDate: TDateTime; const AMessage: AnsiString;
                   out AUid: Int64): Boolean;

{: V41.6 — COPY que devolve (old_uid_set, new_uid_set) no destino (RFC 4315). }
function CopyUid(const AUidSet, ADestMailbox: AnsiString;
                 out ASrcUids, ADestUids: AnsiString): Boolean;

{: V41.6 — MOVE = COPY + EXPUNGE atomico (RFC 6851). }
function MoveUid(const AUidSet, ADestMailbox: AnsiString): Boolean;
```

### 2.4 XOAUTH2

Identico ao SMTP XOAUTH2 (Onda 3) — mesmo mecanismo RFC 7628:

```pascal
property OAuthAccessToken: AnsiString read ... write ...;
property OAuthUser: AnsiString read ... write ...;

function AuthXOAUTH2: Boolean;
```

### 2.5 CAPABILITY helper

```pascal
FCapabilities: TStringList;  // populado apos LOGIN/EHLO

function SupportsCapability(const ACap: AnsiString): Boolean;
```

---

## 3. Alteracoes em `imapsend.pas`

| Bloco | Conteudo | LoC |
|---|---|---:|
| Interface — `TIMAPIdleEvent` + `TIMAPIdleCallback` | Enum + tipo de procedimento | ~15 |
| Interface — `TIMAPSearchBuilder` record | Record advanced com fluent API | ~80 |
| Interface — `TIMAPSend` extensoes | +10 metodos + 3 properties | ~50 |
| Implementation — `Idle` + `IdleStop` + `ProcessIdleNotification` | Poll loop + parse notificacoes | ~150 |
| Implementation — `TIMAPSearchBuilder` metodos | Constroi a string SEARCH | ~200 |
| Implementation — `SearchEx` + `SearchUid` | Envia SEARCH, parse response | ~60 |
| Implementation — `AppendUid` / `CopyUid` / `MoveUid` | UIDPLUS parsers | ~80 |
| Implementation — `AuthXOAUTH2` | Identico ao SMTP mas com tag IMAP | ~40 |
| Implementation — CAPABILITY parser | Parse + cache em `FCapabilities` | ~30 |
| Implementation — `EIMAPError` classe nova | Codigos de erro padronizados | ~30 |
| Header — bloco CSL V41.6 + bump 002.007.000 → 002.008.000 | Documentacao | ~20 |

**Total:** ~600 LoC novo, ~150 modificado.

---

## 4. Backup obrigatorio

```powershell
$backDir = 'Packege\synapse\bak'
$ts = (Get-Date).ToString('yyyyMMdd_HHmm')
Copy-Item 'Packege\synapse\imapsend.pas' -Destination "$backDir\imapsend.$ts.bak"
```

---

## 5. Compatibilidade

| Caso | Comportamento |
|---|---|
| Codigo actual sem IDLE/SearchEx/UIDPLUS | Identico — tudo funciona sem alteracao. |
| `Idle(...)` em servidor sem suporte | `EIMAPError` com mensagem clara. |
| `SearchEx` em servidor RFC 3501 standard | Funciona (todos os criterios sao RFC 3501 base). |
| `AppendUid` em servidor sem UIDPLUS | `EIMAPError`. Consumidor pode fallback para `Append` + `SearchEx(From_:=Me, Since:=Today).Build` como heuristica. |
| `OAuthAccessToken = ''` | Fallback para LOGIN/PLAIN/CRAM-MD5 existente. |

ADORM nao afectado.

---

## 6. Documentacao

- `Packege/synapse/VERSION.md` — bump V41.5 → V41.6.
- `Packege/synapse/Synapse.Version.inc` — +`SYNAPSE_V41_6_OR_HIGHER` + `SYNAPSE_IMAP_IDLE` + `SYNAPSE_IMAP_UIDPLUS` + `SYNAPSE_IMAP_SEARCH_EX` + `SYNAPSE_IMAP_XOAUTH2`.
- `Packege/synapse/README.md`.
- `Packege/synapse/Documentation/README.md`.
- **Revisao** `Packege/synapse/Documentation/Analise/Protocols/TIMAPSend.md` — seccoes V41.6 (IDLE, UIDPLUS, SearchEx, XOAUTH2).
- **NOVO** `Packege/synapse/Documentation/Analise/Protocols/TIMAPSearchBuilder.md` — analise do record fluente.

---

## 7. Verificacao

### 7.1 Compilacao

```powershell
dcc32 ActiveDirectoryORM.dpr
dcc64 ActiveDirectoryORM.dpr
```

Gate: 2/2 verde.

### 7.2 Smoke tests

`tests/ImapModern.Smoke.dpr` — contra GreenMail local (<https://greenmail-mail-test.github.io/greenmail/>) em porta 3143:

1. **LOGIN + SELECT** — login `test@greenmail.com/test123`; SELECT INBOX; esperar `EXISTS >= 0`.
2. **SearchEx basic** — `SearchEx(TIMAPSearchBuilder.Create.All)` — esperar array com todos os UIDs.
3. **SearchEx composto** — `.Unseen.From_('noreply@test.com').Since(Today - 7)` — esperar array filtrado.
4. **AppendUid** — APPEND raw RFC 822 message; esperar UID atribuido > 0.
5. **CopyUid** — COPY entre INBOX → Archive; esperar dois UID sets.
6. **Idle** — thread de consumo chama `Idle(callback, 1)`; thread de producao APPEND outra mensagem; callback recebe `ieExists`; `IdleStop`; assert `SMOKE_OK`.
7. **XOAUTH2** — **SKIP** em CI (requer Gmail sandbox real).

### 7.3 Backcompat

`tests/ImapBackCompat.Smoke.dpr`:

1. Codigo velho `Login` + `List` + `Select` + `Search('UNSEEN')` + `Fetch` + `Logout`.
2. `SMOKE_OK`.

---

## 8. Criterios de aceitacao

- [ ] Backup `Packege/synapse/bak/imapsend.<YYYYMMDD_HHMM>.bak` criado.
- [ ] `imapsend.pas` bump + bloco CSL V41.6 documentado.
- [ ] `TIMAPIdleEvent` + `TIMAPIdleCallback` + `TIMAPSearchBuilder` publicos.
- [ ] `Idle` + `IdleStop` + `ProcessIdleNotification` funcionam contra GreenMail.
- [ ] `SearchEx` + `SearchUid` devolvem arrays correctos.
- [ ] `AppendUid` + `CopyUid` + `MoveUid` parseiam UIDPLUS correctamente.
- [ ] `AuthXOAUTH2` valido contra RFC 7628.
- [ ] `SupportsCapability` helper funcional.
- [ ] `EIMAPError` com codigos.
- [ ] Matriz Delphi Win32+Win64 verde.
- [ ] Smoke `ImapModern.Smoke.dpr` contra GreenMail imprime `SMOKE_OK`.
- [ ] Backcompat smoke passa.
- [ ] Zero codigo ICS copiado.
- [ ] `VERSION.md` + `Synapse.Version.inc` + README + `Analise/Protocols/TIMAPSend.md` actualizados.
- [ ] `Analise/Protocols/TIMAPSearchBuilder.md` criado.

---

## 9. Roadmap pos-V41.6

- **V41.6.1** — CONDSTORE / QRESYNC (RFC 7162) — sincronizacao incremental.
- **V41.6.2** — METADATA (RFC 5464).
- **V41.7** — NNTP moderno (idem polling → NEWNEWS).
- **V41.8** — JMAP (RFC 8620) em unit separada `jmapsend.pas` (HTTP/JSON em vez de texto tokenizado).

---

**Changelog (este arquivo):**

- 1.0.0 (22/04/2026): Criacao. Onda 4 de 4 ICS-inspired modernization. Status draft — requer aprovacao.
