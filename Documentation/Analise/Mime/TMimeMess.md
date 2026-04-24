# TMimeMess

**Unit:** `mimemess.pas` | **Versao:** 002.006.001 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TMimeMess` e o objecto de alto nivel do Synapse para compor e decompor mensagens MIME (emails completos com multiparts, anexos, HTML, texto). Envolve dois colaboradores: `TMessHeader` (campos de cabecalho de email tradicional: From, To, Cc, Subject, Date, Message-ID, etc.) e um `TMimePart` raiz (arvore de parts).

O fluxo de envio tipico e: `AddPartMultipart('mixed', NIL)` para o root, depois `AddPartHTML` / `AddPartText` / `AddPartBinary` sob esse root, depois `EncodeMessage` -> `Lines` contem o email RFC-822 completo pronto para SMTP DATA. O fluxo de recepcao e: `Lines.Text := raw_email;` -> `DecodeMessage` -> `Header.*` + navegacao na arvore `MessagePart`.

A classe permite subclassar `TMessHeader` (via `CreateAltHeaders`) para reaproveitar parsing customizado em domains com campos de cabecalho exoticos.

## 2. Caracteristicas

- Composicao multipart arbitrariamente aninhada
- Helpers AddPart\* para todos os casos tipicos (texto, HTML, binario, inline CID, RFC-822 embutido)
- Conveniencias AddPart\*FromFile (le directo de ficheiro)
- Decomposicao recursiva de mensagens entrantes
- Parsing de priority (legacy `X-MSMAIL-Priority`, `X-Priority`, `Priority`)
- Pair-programming com `THTTPSend`: `DecodeMessageBinary` recebe headers + body de uma resposta HTTP (nao codificada em transfer-encoding)
- Headers customizados via `CustomHeaders`
- Suporte a encoding por charset (via `synachar`)

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Unit | `mimemess.pas` |
| Dependencias | `mimepart`, `synachar`, `synautil`, `mimeinln` |
| Formato | RFC-822 + RFC-2045/2046 (MIME) |
| Priority enum | `TMessPriority = (MP_unknown, MP_low, MP_normal, MP_high)` |

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Cria com `TMessHeader` default. |
| CreateAltHeaders | `constructor CreateAltHeaders(HeadClass: TMessHeaderClass);` | Cria com subclasse customizada de `TMessHeader`. |
| Destroy | `destructor Destroy; override;` | Liberta arvore inteira. |
| Clear | `procedure Clear; virtual;` | Reset a root vazio. |

### 4.2 Composicao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| AddPart | `function AddPart(const PartParent: TMimePart): TMimePart;` | Adiciona sub-part vazio sob parent (ou root se NIL). |
| AddPartMultipart | `function AddPartMultipart(const MultipartType: String; const PartParent: TMimePart): TMimePart;` | Cria part multipart (ex: `'mixed'`, `'alternative'`, `'related'`). |
| AddPartText | `function AddPartText(const Value: TStrings; const PartParent: TMimePart): TMimepart;` | Part text/plain. |
| AddPartTextEx | `function AddPartTextEx(const Value: TStrings; const PartParent: TMimePart; PartCharset: TMimeChar; Raw: Boolean; PartEncoding: TMimeEncoding): TMimepart;` | Part text com charset/encoding explicito. |
| AddPartHTML | `function AddPartHTML(const Value: TStrings; const PartParent: TMimePart): TMimepart;` | Part text/html. |
| AddPartTextFromFile | `function AddPartTextFromFile(const FileName: String; const PartParent: TMimePart): TMimepart;` | Text a partir de ficheiro. |
| AddPartHTMLFromFile | `function AddPartHTMLFromFile(const FileName: String; const PartParent: TMimePart): TMimepart;` | HTML a partir de ficheiro. |
| AddPartBinary | `function AddPartBinary(const Stream: TStream; const FileName: string; const PartParent: TMimePart): TMimepart;` | Anexo binario. |
| AddPartBinaryFromFile | `function AddPartBinaryFromFile(const FileName: string; const PartParent: TMimePart): TMimepart;` | Anexo binario de ficheiro. |
| AddPartHTMLBinary | `function AddPartHTMLBinary(const Stream: TStream; const FileName, Cid: string; const PartParent: TMimePart): TMimepart;` | Imagem inline com CID. |
| AddPartHTMLBinaryFromFile | `function AddPartHTMLBinaryFromFile(const FileName, Cid: string; const PartParent: TMimePart): TMimepart;` | Imagem inline a partir de ficheiro. |
| AddPartMess | `function AddPartMess(const Value: TStrings; const PartParent: TMimePart): TMimepart;` | RFC-822 embutido (`message/rfc822`). |
| AddPartMessFromFile | `function AddPartMessFromFile(const FileName: string; const PartParent: TMimePart): TMimepart;` | Mesmo de ficheiro. |

### 4.3 Codec

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| EncodeMessage | `procedure EncodeMessage; virtual;` | Gera `Lines` = email RFC-822 completo. |
| DecodeMessage | `procedure DecodeMessage; virtual;` | Parse de `Lines` para `Header` + `MessagePart`. |
| DecodeMessageBinary | `procedure DecodeMessageBinary(AHeader: TStrings; AData: TMemoryStream);` | Variante especializada para response HTTP 8-bit (nao aplicar transfer-encoding). |

### 4.4 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| MessagePart | `property TMimePart;` | Arvore de parts (raiz). |
| Lines | `property TStringList;` | Raw MIME encoded message. |
| Header | `property TMessHeader;` | Cabecalhos pre-parseados. |

## 5. Aplicabilidades

1. **Envio de email com HTML + anexos** -- multipart/mixed {multipart/alternative {text,html}, attachments}.
2. **Emails com imagens inline** -- `AddPartHTMLBinary` com CID referenciado no HTML.
3. **Receipt de email e extraccao de anexos** -- `DecodeMessage` + walk em `MessagePart`.
4. **Templates transaccionais** -- compor mensagem a partir de template + dados.
5. **Arquivo EML** -- salvar `Lines` como `.eml` para auditoria/compliance.

## 6. Exemplos de uso

### 6.1 Email HTML com anexo

```pascal
uses
  SysUtils, Classes, mimemess, mimepart, smtpsend;

var
  LMess: TMimeMess;
  LMixed, LAlt: TMimePart;
  LHtmlLines, LTextLines: TStringList;
  LFile: TFileStream;
begin
  LMess := TMimeMess.Create;
  LHtmlLines := TStringList.Create;
  LTextLines := TStringList.Create;
  try
    LMess.Header.From := 'noreply@example.com';
    LMess.Header.ToList.Add('dest@example.com');
    LMess.Header.Subject := 'Relatorio Mensal';
    LMess.Header.Date := Now;
    LMess.Header.MessageID := 'msg-' + FormatDateTime('yyyymmddhhnnss', Now) + '@example.com';
    LMess.Header.Priority := MP_normal;

    LMixed := LMess.AddPartMultipart('mixed', nil);
    LAlt := LMess.AddPartMultipart('alternative', LMixed);
    LTextLines.Add('Relatorio em anexo (versao texto).');
    LMess.AddPartText(LTextLines, LAlt);
    LHtmlLines.Add('<p>Relatorio em <b>anexo</b>.</p>');
    LMess.AddPartHTML(LHtmlLines, LAlt);
    LFile := TFileStream.Create('/path/to/report.pdf', fmOpenRead);
    try
      LMess.AddPartBinary(LFile, 'report.pdf', LMixed);
    finally
      LFile.Free;
    end;

    LMess.EncodeMessage;
    // LMess.Lines agora contem email completo pronto para SMTP DATA
    SendToRaw('noreply@example.com', 'dest@example.com',
              'smtp.example.com', LMess.Lines, 'user', 'pass');
  finally
    LTextLines.Free;
    LHtmlLines.Free;
    LMess.Free;
  end;
end.
```

### 6.2 Parse de email recebido

```pascal
uses
  SysUtils, Classes, mimemess, mimepart;

var
  LMess: TMimeMess;
  I: Integer;
  LPart: TMimePart;
begin
  LMess := TMimeMess.Create;
  try
    LMess.Lines.LoadFromFile('/path/to/received.eml');
    LMess.DecodeMessage;
    Writeln('From: ', LMess.Header.From);
    Writeln('Subject: ', LMess.Header.Subject);
    // percorrer parts
    for I := 0 to LMess.MessagePart.GetSubPartCount - 1 do
    begin
      LPart := LMess.MessagePart.GetSubPart(I);
      Writeln(Format('Part %d: %s/%s (%s)',
        [I, LPart.Primary, LPart.Secondary, LPart.FileName]));
    end;
  finally
    LMess.Free;
  end;
end.
```

### 6.3 Email simples so texto

```pascal
uses
  SysUtils, Classes, mimemess;

var
  LMess: TMimeMess;
  LBody: TStringList;
begin
  LMess := TMimeMess.Create;
  LBody := TStringList.Create;
  try
    LMess.Header.From := 'me@example.com';
    LMess.Header.ToList.Add('you@example.com');
    LMess.Header.Subject := 'Ola';
    LBody.Add('Mensagem curta em texto.');
    LMess.AddPartText(LBody, nil);
    LMess.EncodeMessage;
    LMess.Lines.SaveToFile('/path/to/out.eml');
  finally
    LBody.Free;
    LMess.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TMessHeader` | Composicao | Cabecalhos RFC-822. |
| `TMimePart` | Composicao (raiz + sub) | Arvore de parts. |
| `synachar` | Dependencia | Gestao de charsets. |
| `synautil` | Dependencia | Helpers. |
| `mimeinln` | Dependencia | RFC-2047 encoded-word para Subject/From. |
| `TSMTPSend` / `THTTPSend` | Cliente | Consome `Lines` para envio / recebimento. |
