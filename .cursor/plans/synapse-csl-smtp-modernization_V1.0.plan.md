---
name: synapse-csl-smtp-modernization
version: 1.0.0
date: 2026-04-22
author: CSL Softwares
status: draft
scope: >
  Onda 3 — Modernizacao do smtpsend.pas para cobrir XOAUTH2 (Gmail /
  Microsoft 365), STARTTLS automatico, SMTPUTF8 (RFC 6531) e 8BITMIME.
  Inspirado em ICS TSmtpCli (design pattern apenas — codigo 100% BSD
  3-Clause proprio).
depends-on:
  - Synapse CSL fork 001.007.004 / V41.2
  - Onda 1 V41.3 (TSslRootCAStore) — RECOMENDADA mas nao bloqueante
  - Master plan: synapse-csl-ics-modernization-master_V1.0.plan.md
target-file: Packege/synapse/smtpsend.pas
target-version: upstream → 003.006.000 (CSL fork)
target-package-version: V41.4 → V41.5
protected-area: Packege/synapse/ — requer aprovacao antes de execucao
impact-on-adorm: NULO — ADORM nao envia email
target-compilers:
  - Delphi 12.x (Win32 / Win64)
  - FPC 3.3.1+ (i386-win32 / x86_64-win64)
out-of-scope:
  - DKIM signing (agendar V41.5.1 se necessario)
  - DMARC alignment checks (funcao do MTA, nao do cliente)
  - Priority queue / retry policy (funcao do consumidor)
  - Relay MTA completo — apenas cliente SMTP submission (port 587/465)
licensing: >
  Reimplementacao conceitual do padrao ICS TSmtpCli. Zero linhas de codigo
  ICS copiadas. RFC 5321 (SMTP), RFC 4954 (AUTH), RFC 6531 (SMTPUTF8),
  RFC 3207 (STARTTLS), RFC 6749/6750 (OAuth 2.0), Google XOAUTH2 spec e
  Microsoft OAuth 2.0 for IMAP/POP/SMTP docs sao as referencias.
---

# V41.5 — SMTP modernization (Onda 3 de 4)

> **Status:** draft — area protegida `Packege/synapse/` requer aprovacao.
> Ler plano mestre primeiro: [synapse-csl-ics-modernization-master_V1.0.plan.md](synapse-csl-ics-modernization-master_V1.0.plan.md).

---

## 1. Contexto

`TSMTPSend` upstream cobre:

- Conexao port 25/465/587.
- `AUTH LOGIN` / `AUTH PLAIN` / `AUTH CRAM-MD5`.
- STARTTLS manual (call explicito `StartTLS` antes de `Auth`).
- 7-bit ASCII content.
- Extensoes EHLO detectadas mas nem todas usadas.

Gaps criticos para uso moderno:

| Gap | Impacto |
|---|---|
| Sem XOAUTH2 | Bloqueia Gmail SMTP submission (port 587) — Google desactivou "less secure apps" em 2022 |
| Sem XOAUTH2 | Bloqueia M365 modern auth — Microsoft remove Basic Auth em datas anunciadas |
| STARTTLS manual | Risco de downgrade attack se consumidor esquecer |
| Sem SMTPUTF8 | Emails com caracteres nao-ASCII no header ficam corrompidos |
| Sem 8BITMIME | Body forcado a quoted-printable desnecessariamente |

---

## 2. API nova

### 2.1 XOAUTH2

```pascal
TSMTPSend = class(...)
  // ...
private
  FOAuthAccessToken: AnsiString;
  FOAuthUser: AnsiString;   // email completo (ex.: 'user@gmail.com')
published
  {: V41.5 — Access token OAuth 2.0 para XOAUTH2 (RFC 7628 + Google/MS).
     Se definido, substitui Username/Password.
     Obtido via fluxo OAuth 2.0 externo (nao incluido nesta unit). }
  property OAuthAccessToken: AnsiString read FOAuthAccessToken write FOAuthAccessToken;

  {: V41.5 — Email do user a autenticar — enviado no XOAUTH2 init-response. }
  property OAuthUser: AnsiString read FOAuthUser write FOAuthUser;
```

Implementacao em `Login`:

```pascal
function TSMTPSend.Login: Boolean;
begin
  // ... conexao + EHLO + STARTTLS ...
  if (FOAuthAccessToken <> '') and SupportsAuth('XOAUTH2') then
    Result := AuthXOAUTH2
  else if SupportsAuth('PLAIN') and (FUsername <> '') then
    Result := AuthPlain
  // ... fallbacks existentes ...
end;

function TSMTPSend.AuthXOAUTH2: Boolean;
var
  LInitResp, LB64: AnsiString;
begin
  // RFC 7628: user=<email>^Aauth=Bearer <token>^A^A
  // ^A = control-A = #$01
  LInitResp := 'user=' + FOAuthUser + #$01 +
               'auth=Bearer ' + FOAuthAccessToken + #$01 + #$01;
  LB64 := EncodeBase64(LInitResp);
  FSock.SendString('AUTH XOAUTH2 ' + LB64 + CRLF);
  Result := (ReadResult = 235);  // 235 = auth success
end;
```

### 2.2 STARTTLS automatico

```pascal
type
  TSmtpTlsMode = (
    stmNone,          // puro plaintext (SMTP antigo)
    stmImplicit,      // SMTPS port 465 — SSL desde o inicio
    stmOpportunistic, // STARTTLS se servidor suportar (tenta mas nao falha se nao)
    stmRequired       // STARTTLS obrigatorio (falha se servidor nao suportar)
  );

  TSMTPSend = class(...)
    // ...
  private
    FTlsMode: TSmtpTlsMode;
  published
    {: V41.5 — Modo TLS automatico.
       stmRequired e o recomendado para Gmail/M365 port 587. }
    property TlsMode: TSmtpTlsMode read FTlsMode write FTlsMode default stmOpportunistic;
  end;
```

Implementacao em `Login`:

```pascal
// apos conexao TCP e EHLO inicial:
case FTlsMode of
  stmImplicit:
    ; // SSL ja foi activado no Login antes do EHLO — nada a fazer
  stmOpportunistic:
    if FCapabilities.IndexOf('STARTTLS') >= 0 then
      if not DoSTARTTLS then  // se falhar, continua plaintext
        LogWarn('STARTTLS falhou — a continuar em plaintext');
  stmRequired:
    if FCapabilities.IndexOf('STARTTLS') < 0 then
      raise ESMTPError.Create('STARTTLS obrigatorio mas servidor nao suporta')
    else if not DoSTARTTLS then
      raise ESMTPError.Create('STARTTLS falhou');
  stmNone:
    ; // plaintext garantido
end;

// Re-emitir EHLO apos STARTTLS (obrigatorio por RFC 3207)
```

### 2.3 SMTPUTF8 + 8BITMIME

```pascal
{: V41.5 — Permite SMTPUTF8 (RFC 6531) em MAIL FROM / RCPT TO. }
property EnableSMTPUTF8: Boolean read FEnableSMTPUTF8 write FEnableSMTPUTF8 default True;

{: V41.5 — Permite 8BITMIME (RFC 6152) em body DATA. }
property Enable8BITMIME: Boolean read FEnable8BITMIME write FEnable8BITMIME default True;
```

Implementacao: no `MailFrom` envia `MAIL FROM:<x> SMTPUTF8 BODY=8BITMIME` se as
extensoes forem suportadas pelo servidor e as properties estiverem `True`.

### 2.4 Helper de envio simples

```pascal
{: V41.5 — Envio tudo-em-um com XOAUTH2 + STARTTLS.
   Retorna True em sucesso, com FLastError populado em falha. }
function SendMailOAuth2(const AServer, AUser, AAccessToken, AFrom, ATo,
                       ASubject, ABody: AnsiString): Boolean;
```

Atalho para quem nao quer configurar o objecto manualmente:

```pascal
if SendMailOAuth2('smtp.gmail.com', 'me@gmail.com', LToken,
                  'me@gmail.com', 'dest@example.com',
                  'Teste', 'Corpo do email') then
  WriteLn('Enviado');
```

---

## 3. Alteracoes em `smtpsend.pas`

| Bloco | Conteudo | LoC |
|---|---|---:|
| Interface — `TSmtpTlsMode` enum | Novo tipo publico | ~10 |
| Interface — `TSMTPSend` extensoes | +5 properties + 2 metodos + 1 helper global | ~40 |
| Implementation — `AuthXOAUTH2` | Build init-response RFC 7628 + base64 + AUTH | ~40 |
| Implementation — `DoSTARTTLS` robusto | STARTTLS + re-EHLO + switch SSL | ~60 |
| Implementation — `SupportsAuth` helper | Parse `AUTH LOGIN PLAIN XOAUTH2 ...` da EHLO response | ~30 |
| Implementation — SMTPUTF8/8BITMIME em `MailFrom` | Parametros condicionais na linha | ~30 |
| Implementation — `SendMailOAuth2` helper global | Atalho completo | ~80 |
| Implementation — error handling refactor | `ESMTPError` classe + codigos | ~40 |
| Header — bloco CSL V41.5 + bump 003.005.000 → 003.006.000 | Documentacao | ~20 |

**Total:** ~350 LoC novo, ~80 modificado.

---

## 4. Backup obrigatorio

```powershell
$backDir = 'Packege\synapse\bak'
$ts = (Get-Date).ToString('yyyyMMdd_HHmm')
Copy-Item 'Packege\synapse\smtpsend.pas' -Destination "$backDir\smtpsend.$ts.bak"
```

---

## 5. Compatibilidade

| Caso | Comportamento |
|---|---|
| Codigo actual `Auth=True` + `Username/Password` Basic | Igual — Basic / LOGIN / PLAIN funciona. |
| `OAuthAccessToken = ''` | Sem XOAUTH2 — fallback aos mecanismos actuais. |
| `TlsMode = stmOpportunistic` (default) | STARTTLS tentado mas nao exigido — semantica menos estrita que actual (nao regressao funcional). |
| `TlsMode = stmRequired` | **Novo comportamento** — falha se servidor nao suporta. Consumidor opta-in explicitamente. |
| `EnableSMTPUTF8 = True` + servidor sem suporte | Enviado sem flag — nenhum erro. |

ADORM nao afectado.

---

## 6. Documentacao

- `Packege/synapse/VERSION.md` — bump V41.4 → V41.5.
- `Packege/synapse/Synapse.Version.inc` — +`SYNAPSE_V41_5_OR_HIGHER` + `SYNAPSE_SMTP_XOAUTH2` + `SYNAPSE_SMTP_STARTTLS_AUTO` + `SYNAPSE_SMTP_UTF8`.
- `Packege/synapse/README.md`.
- `Packege/synapse/Documentation/README.md`.
- **Revisao** `Packege/synapse/Documentation/Analise/Protocols/TSMTPSend.md` — secoes V41.5 (XOAUTH2, STARTTLS auto, SMTPUTF8, 8BITMIME, SendMailOAuth2).

---

## 7. Verificacao

### 7.1 Compilacao

```powershell
dcc32 ActiveDirectoryORM.dpr
dcc64 ActiveDirectoryORM.dpr
```

Gate: 2/2 verde.

### 7.2 Smoke tests

`tests/SmtpModern.Smoke.dpr` — contra MailHog local (<https://github.com/mailhog/MailHog>) em porta 1025:

1. **STARTTLS opcional** — MailHog nao suporta STARTTLS; com `stmOpportunistic` envia em plaintext; esperar `250 OK`.
2. **STARTTLS obrigatorio** — com `stmRequired` contra MailHog; esperar `ESMTPError`.
3. **Envio simples** — 1 email plaintext, MailHog recebe; esperar corpo correcto.
4. **SMTPUTF8** — envio com header `Subject: Teste com acentos àáâã`; MailHog regista UTF-8 correcto.
5. **XOAUTH2** — este teste fica **skipado** em CI sem Gmail sandbox real; documentado como `SKIP: XOAUTH2 requires live Gmail/M365 OAuth2 credentials`.

Para validacao XOAUTH2 real:

- Criar app no Google Cloud Console com scope `https://mail.google.com/`.
- Obter refresh token + access token via OAuth 2.0 Playground.
- `LSMTP.OAuthAccessToken := '<token>'; LSMTP.OAuthUser := '<email>';`.
- Enviar email — Gmail aceita `235 Accepted`.

### 7.3 Backcompat

`tests/SmtpBackCompat.Smoke.dpr`:

1. Codigo velho `Username/Password` Basic contra MailHog — `250 OK`.
2. `StartTLS` manual antes de `Auth` — igual a antes.
3. `SMOKE_OK`.

---

## 8. Criterios de aceitacao

- [ ] Backup `Packege/synapse/bak/smtpsend.<YYYYMMDD_HHMM>.bak` criado.
- [ ] `smtpsend.pas` bump + bloco CSL V41.5 documentado.
- [ ] `TSmtpTlsMode` enum publico.
- [ ] `OAuthAccessToken` + `OAuthUser` + `TlsMode` + `EnableSMTPUTF8` + `Enable8BITMIME` properties.
- [ ] `AuthXOAUTH2` + `DoSTARTTLS` + `SendMailOAuth2` implementados.
- [ ] `ESMTPError` classe nova com codigos.
- [ ] `TlsMode = stmOpportunistic` (default) mantem semantica actual; `stmRequired` e opt-in.
- [ ] Matriz Delphi Win32+Win64 verde.
- [ ] Smoke `SmtpModern.Smoke.dpr` contra MailHog imprime `SMOKE_OK`.
- [ ] Backcompat smoke passa.
- [ ] Zero codigo ICS copiado.
- [ ] `VERSION.md` + `Synapse.Version.inc` + README + `Analise/Protocols/TSMTPSend.md` actualizados.

---

## 9. Roadmap pos-V41.5

- **V41.5.1** — DKIM signing (RFC 6376) usando OpenSSL EVP_PKEY.
- **V41.5.2** — DSN (Delivery Status Notification) RFC 3461.
- **V41.5.3** — BDAT chunked body (RFC 3030).

---

**Changelog (este arquivo):**

- 1.0.0 (22/04/2026): Criacao. Onda 3 de 4 ICS-inspired modernization. Status draft — requer aprovacao.
