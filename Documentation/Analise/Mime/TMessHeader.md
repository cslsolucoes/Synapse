# TMessHeader

**Unit:** `mimemess.pas` | **Versao:** 002.006.001 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TMessHeader` e o objecto que encapsula os cabecalhos "tradicionais" de um email RFC-822 usados pelo Synapse. Vive como propriedade `Header` dentro de `TMimeMess` e e responsavel por parsing e serializacao de: From, To, CC, Subject, Date, Message-ID, Reply-To, Priority, Organization, X-Mailer e a colecao de cabecalhos nao parseados (`CustomHeaders`).

Faz tambem deteccao de prioridade tri-origem (Priority, X-Priority, X-MSMAIL-Priority) combinando as tres fontes num unico `TMessPriority`. O parse respeita case-insensitive e usa `InlineDecode` (RFC-2047 encoded-word) para decifrar subjects com acentos/caracteres nao-ASCII.

A classe e subclassavel via `TMessHeaderClass` + `TMimeMess.CreateAltHeaders` permitindo adicionar campos ou heuristicas customizadas em projectos de nicho (ex.: mailing list engines com `List-Id`/`List-Unsubscribe`).

## 2. Caracteristicas

- Parsing RFC-822 com suporte RFC-2047 (encoded-word em Subject)
- Deteccao conservadora de prioridade com 3 headers fallback
- `CustomHeaders` preserva tudo que nao for campo standard
- Find / FindList case-insensitive
- Charset base configuravel (`CharsetCode`) para encoding de saida
- Extensivel via subclassing + `CreateAltHeaders`

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Unit | `mimemess.pas` |
| Headers parsed dedicados | X-MAILER, FROM, SUBJECT, ORGANIZATION, TO, CC, DATE, MIME-VERSION, CONTENT-TYPE, CONTENT-DESCRIPTION, CONTENT-DISPOSITION, CONTENT-ID, CONTENT-TRANSFER-ENCODING, REPLY-TO, MESSAGE-ID, X-MSMAIL-PRIORITY, X-PRIORITY, PRIORITY |
| TMessPriority | `(MP_unknown, MP_low, MP_normal, MP_high)` |
| TMessHeaderClass | `class of TMessHeader` |

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create; virtual;` | Alocacao default. |
| Destroy | `destructor Destroy; override;` | Liberta stringlists internas. |
| Clear | `procedure Clear; virtual;` | Reset. |

### 4.2 Codec

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| EncodeHeaders | `procedure EncodeHeaders(const Value: TStrings); virtual;` | Serializa campos + `CustomHeaders` em `Value`. |
| DecodeHeaders | `procedure DecodeHeaders(const Value: TStrings);` | Parse de `Value` em properties. |
| ParsePriority | `function ParsePriority(value: string): TMessPriority;` | Helper (usado em 3 headers). |
| DecodeHeader | `function DecodeHeader(value: string): boolean; virtual;` | Parse linha-a-linha (override point). |

### 4.3 Lookup

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| FindHeader | `function FindHeader(Value: string): string;` | Pesquisa case-insensitive em `CustomHeaders`. |
| FindHeaderList | `procedure FindHeaderList(Value: string; const HeaderList: TStrings);` | Multiple matches (ex.: `Received:`). |

### 4.4 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| From | `property string;` | Sender. |
| ToList | `property TStringList;` | 1 entrada por destinatario. |
| CCList | `property TStringList;` | Idem para CC. |
| Subject | `property string;` | Subject (ja decoded para RFC-2047). |
| Organization | `property string;` | Campo Organization. |
| CustomHeaders | `property TStringList;` | Todas as linhas nao parseadas. |
| Date | `property TDateTime;` | Data parseada. |
| XMailer | `property string;` | X-Mailer. |
| ReplyTo | `property string;` | Reply-To. |
| MessageID | `property string;` | Message-ID. |
| Priority | `property TMessPriority;` | Prioridade (MP_unknown/low/normal/high). |
| CharsetCode | `property TMimeChar;` | Charset base para encoding em saida. |

## 5. Aplicabilidades

1. **Template engine** -- preencher campos padrao a partir de contexto.
2. **Filter / regras** -- classificar por From/Subject/Custom headers (List-Id, X-Spam-Score).
3. **Audit log** -- extrair Message-ID para rastreabilidade cross-system.
4. **Reply-constructor** -- usar ReplyTo (fallback para From) na montagem de resposta.
5. **Mailer identification** -- analise de X-Mailer para deteccao de ferramentas client.

## 6. Exemplos de uso

### 6.1 Construcao simples

```pascal
uses
  SysUtils, mimemess;

var
  LHeader: TMessHeader;
  LLines: TStringList;
begin
  LHeader := TMessHeader.Create;
  LLines := TStringList.Create;
  try
    LHeader.From := 'sender@example.com';
    LHeader.ToList.Add('a@example.com');
    LHeader.ToList.Add('b@example.com');
    LHeader.CCList.Add('c@example.com');
    LHeader.Subject := 'Assunto com acentos: açao';
    LHeader.Date := Now;
    LHeader.MessageID := '<' + FormatDateTime('yyyymmddhhnnss', Now) + '@example.com>';
    LHeader.Priority := MP_high;
    LHeader.CustomHeaders.Add('X-Request-ID: abc-123');
    LHeader.EncodeHeaders(LLines);
    Writeln(LLines.Text);
  finally
    LLines.Free;
    LHeader.Free;
  end;
end.
```

### 6.2 Parse de headers crus

```pascal
uses
  SysUtils, Classes, mimemess;

var
  LHeader: TMessHeader;
  LLines: TStringList;
begin
  LHeader := TMessHeader.Create;
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile('/path/to/headers.txt');
    LHeader.DecodeHeaders(LLines);
    Writeln('From=', LHeader.From);
    Writeln('Subject=', LHeader.Subject);
    Writeln('Date=', FormatDateTime('yyyy-mm-dd hh:nn', LHeader.Date));
    Writeln('Priority=', Ord(LHeader.Priority));
    Writeln('List-Id=', LHeader.FindHeader('List-Id'));
  finally
    LLines.Free;
    LHeader.Free;
  end;
end.
```

### 6.3 Extraccao multi-valor (Received chain)

```pascal
uses
  SysUtils, Classes, mimemess;

var
  LHeader: TMessHeader;
  LLines, LReceived: TStringList;
  I: Integer;
begin
  LHeader := TMessHeader.Create;
  LLines := TStringList.Create;
  LReceived := TStringList.Create;
  try
    LLines.LoadFromFile('/path/to/mail.eml');
    LHeader.DecodeHeaders(LLines);
    LHeader.FindHeaderList('Received', LReceived);
    for I := 0 to LReceived.Count - 1 do
      Writeln(Format('Hop %d: %s', [I + 1, LReceived[I]]));
  finally
    LReceived.Free;
    LLines.Free;
    LHeader.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TMimeMess` | Container | Contem `Header` como property. |
| `mimeinln` | Dependencia | RFC-2047 encoded-word. |
| `synachar` | Dependencia | Charset handling. |
| `synautil` | Dependencia | Parser de datas RFC-822. |
| `TMessHeaderClass` | Type | Meta-class para subclassing. |
