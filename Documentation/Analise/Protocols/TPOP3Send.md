# TPOP3Send

**Unit:** `pop3send.pas` | **Versao:** 002.006.002 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TPOP3Send` e o cliente POP3 do Ararat Synapse (RFC-1939), com extensoes CAPA (RFC-2449), SASL CRAM-MD5 (RFC-1734, RFC-2195) e STLS (RFC-2595). Herda de `TSynaClient` e e suficiente para download integral ou parcial de caixas de correio POP3/POP3S.

O modo de autenticacao e autodetectavel via `TPOP3AuthType = (POP3AuthAll, POP3AuthLogin, POP3AuthAPOP)`. Com `POP3AuthAll` o cliente tenta APOP (se o servidor publicar `TimeStamp` no banner), depois faz fallback para USER/PASS tradicional.

Como o POP3 e stateless em leitura, a classe mantem `FullResult` com o conteudo do ultimo comando (util para LIST, RETR, UIDL, TOP). O fluxo tipico e `Login -> Stat -> Retr/Dele -> Logout`, mas operacoes como `UIDL` permitem dedup por message-id no cliente.

## 2. Caracteristicas

- POP3 (RFC-1939) + CAPA (RFC-2449)
- Autenticacao APOP (MD5 challenge) e USER/PASS
- STLS (RFC-2595) upgrade + POP3S (FullSSL)
- Download por `FullResult` (TStringList) ou `RetrStream` (TStream)
- UIDL para unique-id por mensagem
- TOP para download parcial (headers + N linhas)
- CustomCommand para comandos proprietarios
- Autodeteccao de auth: APOP > USER/PASS

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta POP3 | `cPop3Protocol = '110'` |
| Porta POP3S (FullSSL) | `995` (convencional) |
| Herda de | `TSynaClient` |
| AuthType default | `POP3AuthAll` (autodeteccao) |
| AutoTLS default | `False` |

## 4. Funcionalidades

### 4.1 Sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Login | `function Login: Boolean;` | Conecta, CAPA, AUTH (APOP ou USER/PASS), opcional STLS. |
| Logout | `function Logout: Boolean;` | Envia QUIT. |
| StartTLS | `function StartTLS: Boolean;` | STLS upgrade. |
| NoOp | `function NoOp: Boolean;` | Keep-alive. |
| Reset | `function Reset: Boolean;` | RSET: anula DELEs pendentes. |
| Capability | `function Capability: Boolean;` | Emite CAPA; `POP3cap` e preenchido. |
| CustomCommand | `function CustomCommand(const Command: string; MultiLine: Boolean): boolean;` | Comando arbitrario. |

### 4.2 Inbox

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Stat | `function Stat: Boolean;` | STAT: preenche `StatCount` + `StatSize`. |
| List | `function List(Value: Integer): Boolean;` | LIST (ou LIST N): listagem de mensagens em `FullResult`. |
| Uidl | `function Uidl(Value: Integer): Boolean;` | UIDL: unique-id por mensagem. |

### 4.3 Mensagens

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Retr | `function Retr(Value: Integer): Boolean;` | RETR: download completo para `FullResult`. |
| RetrStream | `function RetrStream(Value: Integer; Stream: TStream): Boolean;` | RETR para stream (grandes mensagens). |
| Top | `function Top(Value, Maxlines: Integer): Boolean;` | TOP: headers + N linhas do body. |
| Dele | `function Dele(Value: Integer): Boolean;` | DELE: marca para apagar (commit no QUIT). |
| FindCap | `function FindCap(const Value: string): string;` | Procura capability publicada. |

### 4.4 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| ResultCode | `property ResultCode: Integer;` | `1` OK / `0` ERR. |
| ResultString | `property ResultString: string;` | Resposta `+OK ...` ou `-ERR ...`. |
| FullResult | `property FullResult: TStringList;` | Linhas do ultimo comando. |
| StatCount | `property StatCount: Integer;` | Numero de mensagens. |
| StatSize | `property StatSize: Integer;` | Tamanho total da inbox. |
| ListSize | `property ListSize: Integer;` | Tamanho apos `List`. |
| TimeStamp | `property TimeStamp: string;` | Banner APOP (se suportado). |
| AuthType | `property AuthType: TPOP3AuthType;` | `POP3AuthAll` / `POP3AuthLogin` / `POP3AuthAPOP`. |
| AutoTLS | `property AutoTLS: Boolean;` | Upgrade STLS se disponivel. |
| FullSSL | `property FullSSL: Boolean;` | POP3S desde inicio. |
| Sock | `property Sock: TTCPBlockSocket;` | Socket. |

## 5. Aplicabilidades

1. **Arquivamento de mailbox** -- download em lote de todas as mensagens + DELE para limpeza.
2. **Antispam gateway** -- pipeline que pega POP3 -> classifica -> reenvia por SMTP.
3. **Bots monitor de email** -- pooling de mailbox tecnica para abrir tickets automaticos.
4. **Backup incremental de emails** -- uso de UIDL para detectar mensagens novas.
5. **Diagnostico e teste de servidores POP3** -- verificacao de capabilities e auth.

## 6. Exemplos de uso

### 6.1 Download de todas as mensagens

```pascal
uses
  SysUtils, Classes, pop3send;

var
  LPop: TPOP3Send;
  I: Integer;
begin
  LPop := TPOP3Send.Create;
  try
    LPop.TargetHost := 'pop3.example.com';
    LPop.TargetPort := '995';
    LPop.Username := 'user@example.com';
    LPop.Password := 'secret';
    LPop.FullSSL := True;
    if not LPop.Login then
      raise Exception.Create(LPop.ResultString);
    try
      if LPop.Stat then
        Writeln(Format('Mensagens: %d (total %d bytes)',
          [LPop.StatCount, LPop.StatSize]));
      for I := 1 to LPop.StatCount do
        if LPop.Retr(I) then
          LPop.FullResult.SaveToFile(Format('/path/to/msg_%d.eml', [I]));
    finally
      LPop.Logout;
    end;
  finally
    LPop.Free;
  end;
end.
```

### 6.2 Leitura incremental por UIDL

```pascal
uses
  SysUtils, Classes, pop3send;

var
  LPop: TPOP3Send;
  LKnown: TStringList;
  I: Integer;
begin
  LPop := TPOP3Send.Create;
  LKnown := TStringList.Create;
  try
    LKnown.LoadFromFile('/path/to/uidl.cache');
    LPop.TargetHost := 'pop3.example.com';
    LPop.Username := 'user';
    LPop.Password := 'pwd';
    LPop.AutoTLS := True;
    if LPop.Login then
    try
      LPop.Uidl(0);
      for I := 0 to LPop.FullResult.Count - 1 do
      begin
        if LKnown.IndexOf(LPop.FullResult[I]) < 0 then
        begin
          Writeln('Nova: ', LPop.FullResult[I]);
          LKnown.Add(LPop.FullResult[I]);
        end;
      end;
      LKnown.SaveToFile('/path/to/uidl.cache');
    finally
      LPop.Logout;
    end;
  finally
    LKnown.Free;
    LPop.Free;
  end;
end.
```

### 6.3 Download por stream (mensagem grande)

```pascal
uses
  SysUtils, Classes, pop3send;

var
  LPop: TPOP3Send;
  LFile: TFileStream;
begin
  LPop := TPOP3Send.Create;
  try
    LPop.TargetHost := 'pop3.example.com';
    LPop.Username := 'u';
    LPop.Password := 'p';
    LPop.FullSSL := True;
    if LPop.Login then
    try
      LFile := TFileStream.Create('/path/to/msg1.eml', fmCreate);
      try
        LPop.RetrStream(1, LFile);
      finally
        LFile.Free;
      end;
    finally
      LPop.Logout;
    end;
  finally
    LPop.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/credenciais. |
| `TTCPBlockSocket` | Composicao | Socket TCP + TLS. |
| `synacode` | Dependencia | MD5 para APOP. |
| `TMimeMess` (mimemess) | Parceiro | Parse da mensagem baixada. |
| Plugin SSL | Dependencia opcional | STLS / POP3S. |
