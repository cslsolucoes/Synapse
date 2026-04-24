# TSMTPSend

**Unit:** `smtpsend.pas` | **Versao:** 003.005.001 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TSMTPSend` e a implementacao cliente SMTP / ESMTP do Ararat Synapse. Suporta o protocolo base (RFC-2821) e extensoes ESMTP: AUTH (RFC-2554, LOGIN/CRAM-MD5/PLAIN), 8BITMIME e SIZE (RFC-1870), STARTTLS (RFC-2487), enhanced status codes (RFC-2034) e ETRN (RFC-1985). A classe herda de `TSynaClient`, reutilizando credenciais (`Username`/`Password`) e conectividade.

Quando chamado `Login`, o cliente tenta primeiro `EHLO` (ESMTP) e, em caso de falha, cai para `HELO` (SMTP classico). Apos identificar as capabilities (`ESMTPcap`), decide pela melhor autenticacao disponivel (preferencia: CRAM-MD5 > LOGIN > PLAIN) e aplica STARTTLS se `AutoTLS=True` e o server oferecer a extensao.

Convivem dois modos de cifragem: `FullSSL` (SMTPS, porta 465, TLS desde o byte 0) e `AutoTLS`/`StartTLS` (porta 587, upgrade mid-session). O modulo inclui ainda funcoes globais `SendTo`, `SendToRaw` e `SendToEx` que envolvem a classe para casos de envio "one-shot".

## 2. Caracteristicas

- SMTP (RFC-2821) + ESMTP (RFC-1869) + AUTH (RFC-2554)
- Autenticacao: LOGIN, CRAM-MD5 (RFC-2195), PLAIN
- STARTTLS (RFC-2487) e SMTPS (FullSSL)
- Enhanced result codes (RFC-2034): `EnhCode1`/`EnhCode2`/`EnhCode3` + tradutor `EnhCodeString`
- Extensao SIZE (RFC-1870): limita upload por `MaxSize` quando servidor publica a capability
- Extensao ETRN (RFC-1985): disparo de queue remota
- Comando VRFY (verificacao de recipient)
- `FullResult` com dump multi-linha de cada comando
- Comportamento autonomo: `Login` ja faz EHLO/HELO + AUTH + (eventual) STARTTLS

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta SMTP | `cSmtpProtocol = '25'` |
| Porta SMTP submission (STARTTLS) | `587` (convencional) |
| Porta SMTPS (FullSSL) | `465` (convencional) |
| Herda de | `TSynaClient` |
| SystemName default | Internet address da maquina local |
| Auth preferida | CRAM-MD5 > LOGIN > PLAIN (autodeteccao) |
| AutoTLS default | `False` |
| FullSSL default | `False` |

## 4. Funcionalidades

### 4.1 Sessao (conexao + auth)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Login | `function Login: Boolean;` | Conecta, faz EHLO/HELO, parse capabilities, AUTH e opcional STARTTLS. |
| Logout | `function Logout: Boolean;` | Envia QUIT e fecha socket. |
| StartTLS | `function StartTLS: Boolean;` | Upgrade da sessao para TLS (porta 587 tipicamente). |
| Reset | `function Reset: Boolean;` | Comando RSET: reinicia a transacao. |
| NoOp | `function NoOp: Boolean;` | Keep-alive. |

### 4.2 Transacao de mensagem

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| MailFrom | `function MailFrom(const Value: string; Size: Integer): Boolean;` | Define remetente (`MAIL FROM:`). Se `Size>0` e ESMTP SIZE aceito, anexa `SIZE=`. |
| MailTo | `function MailTo(const Value: string): Boolean;` | Define destinatario (`RCPT TO:`). Pode ser chamado varias vezes. |
| MailData | `function MailData(const Value: TStrings): Boolean;` | Envia body completo (headers + `\r\n\r\n` + corpo). |
| Verify | `function Verify(const Value: string): Boolean;` | VRFY: servidor verifica se recipient existe. |
| Etrn | `function Etrn(const Value: string): Boolean;` | ETRN para domain-flush. |

### 4.3 Handshake ESMTP (uso interno expostos)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Helo / Ehlo (privados) | internos | Accessiveis indirectamente via `Login`. |
| EnhCodeString | `function EnhCodeString: string;` | Descricao textual do enhanced code. |
| FindCap | `function FindCap(const Value: string): string;` | Pesquisa capability em `ESMTPcap`. |

### 4.4 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| FullResult | `property FullResult: TStringList;` | Todas as linhas do ultimo comando. |
| ESMTPcap | `property ESMTPcap: TStringList;` | Capabilities publicadas pelo servidor em resposta a EHLO. |
| ESMTP | `property ESMTP: Boolean;` | `True` se EHLO sucedeu. |
| AuthDone | `property AuthDone: Boolean;` | `True` se AUTH passou. |
| ESMTPSize | `property ESMTPSize: Boolean;` | Servidor suporta SIZE. |
| MaxSize | `property MaxSize: Integer;` | Tamanho maximo de mensagem publicado. |
| EnhCode1 / EnhCode2 / EnhCode3 | `property Integer;` | Enhanced status code partes 1/2/3. |
| SystemName | `property SystemName: string;` | Valor enviado em HELO/EHLO. |
| AutoTLS | `property AutoTLS: Boolean;` | Upgrade STARTTLS automatico se disponivel. |
| FullSSL | `property FullSSL: Boolean;` | SMTPS desde o inicio. |
| ResultCode | `property ResultCode: Integer;` | Codigo SMTP (250, 550, etc.). |
| ResultString | `property ResultString: string;` | Linha principal de resposta. |
| Sock | `property Sock: TTCPBlockSocket;` | Acesso directo ao socket. |

### 4.5 Funcoes globais (wrappers)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| SendToRaw | `function SendToRaw(const MailFrom, MailTo, SMTPHost: string; const MailData: TStrings; const Username, Password: string): Boolean;` | Envia raw (mailheaders + body ja preparados). |
| SendTo | `function SendTo(const MailFrom, MailTo, Subject, SMTPHost: string; const MailData: TStrings): Boolean;` | Monta headers Date + From + To + Subject automaticamente. |
| SendToEx | `function SendToEx(const MailFrom, MailTo, Subject, SMTPHost: string; const MailData: TStrings; const Username, Password: string): Boolean;` | Equivalente a `SendTo` com auth. |

## 5. Aplicabilidades

1. **Notificacoes transaccionais** -- envio de confirmacoes de encomenda, password reset, alertas automaticos.
2. **Mailers de relatorios** -- integracao com ERPs/MIS para mailing de relatorios PDF ou CSV.
3. **Relay via provider (Gmail/Office365)** -- configuracao `FullSSL=True` + porta 465 ou `AutoTLS=True` + 587.
4. **Bounce handling / verificacao de domains** -- uso de VRFY e ETRN em diagnostico de servidores.
5. **Cenarios enterprise ESMTP** -- deteccao de `SIZE` para rejeitar anexos gigantes antes de enviar.

## 6. Exemplos de uso

### 6.1 Envio via provider publico com STARTTLS (porta 587)

```pascal
uses
  SysUtils, Classes, smtpsend, mimemess, mimepart;

var
  LSmtp: TSMTPSend;
  LLines: TStringList;
begin
  LSmtp := TSMTPSend.Create;
  LLines := TStringList.Create;
  try
    LSmtp.TargetHost := 'smtp.example.com';
    LSmtp.TargetPort := '587';
    LSmtp.Username := 'noreply@example.com';
    LSmtp.Password := 'app-specific-password';
    LSmtp.AutoTLS := True;
    if not LSmtp.Login then
      raise Exception.Create('Login falhou: ' + LSmtp.ResultString);
    try
      LLines.Add('From: noreply@example.com');
      LLines.Add('To: destino@empresa.pt');
      LLines.Add('Subject: Relatorio diario');
      LLines.Add('');
      LLines.Add('Em anexo o relatorio de hoje.');
      if not LSmtp.MailFrom('noreply@example.com', Length(LLines.Text)) then
        raise Exception.Create(LSmtp.ResultString);
      if not LSmtp.MailTo('destino@empresa.pt') then
        raise Exception.Create(LSmtp.ResultString);
      if not LSmtp.MailData(LLines) then
        raise Exception.Create(LSmtp.ResultString);
    finally
      LSmtp.Logout;
    end;
  finally
    LLines.Free;
    LSmtp.Free;
  end;
end.
```

### 6.2 Envio rapido com `SendToEx`

```pascal
uses
  SysUtils, Classes, smtpsend;

var
  LBody: TStringList;
begin
  LBody := TStringList.Create;
  try
    LBody.Add('Ola. Este e o corpo da mensagem.');
    if SendToEx(
         'from@example.com',
         'to@example.com',
         'Assunto de teste',
         'smtp.example.com',
         LBody,
         'from@example.com',
         'secret') then
      Writeln('Enviado')
    else
      Writeln('Falhou');
  finally
    LBody.Free;
  end;
end.
```

### 6.3 Deteccao de capabilities ESMTP

```pascal
uses
  SysUtils, Classes, smtpsend;

var
  LSmtp: TSMTPSend;
  I: Integer;
begin
  LSmtp := TSMTPSend.Create;
  try
    LSmtp.TargetHost := 'mail.example.com';
    LSmtp.TargetPort := '25';
    if LSmtp.Login then
    try
      Writeln('ESMTP=', LSmtp.ESMTP);
      Writeln('SIZE=', LSmtp.ESMTPSize, ' MaxSize=', LSmtp.MaxSize);
      for I := 0 to LSmtp.ESMTPcap.Count - 1 do
        Writeln('  cap: ', LSmtp.ESMTPcap[I]);
    finally
      LSmtp.Logout;
    end;
  finally
    LSmtp.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` (blcksock) | Superclasse | Host/porta/timeout/credenciais. |
| `TTCPBlockSocket` (blcksock) | Composicao | Socket TCP + upgrade TLS. |
| `synautil` | Dependencia | URL/MIME helpers. |
| `synacode` | Dependencia | Base64 (AUTH LOGIN/PLAIN) e HMAC-MD5 (CRAM-MD5). |
| `TMimeMess` (mimemess) | Consumidor | Pre-formata body com headers + parts. |
| Plugin SSL (`ssl_openssl*`) | Dependencia opcional | Activa STARTTLS e FullSSL. |
