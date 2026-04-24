# TMimePart

**Unit:** `mimepart.pas` | **Versao:** 002.009.003 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TMimePart` e a unidade atomica do modelo MIME do Synapse (RFC-2045). Cada part pode ser folha (texto, HTML, binario, RFC-822 embutido) ou compose (multipart/mixed, alternative, related, parallel, digest), podendo conter arbitraria profundidade de subparts.

A classe encapsula headers (`Headers`, `Primary`, `Secondary`, `Encoding`, `Charset`, `Description`, `Disposition`, `ContentID`, `Boundary`, `FileName`), body em varios estagios (`Lines` raw, `PartBody` encoded, `DecodedLines` ja decoded para binario), e a lista de `SubParts` com acesso por indice.

O ciclo de decodificacao e: popular `Lines` -> `DecomposeParts` (recursivo) -> cada part decodifica os headers em properties; depois, para obter o body real, chamar `DecodePart` (decodifica base64 / quoted-printable / uuencode). O ciclo de codificacao inverso: popular `DecodedLines` + properties -> `EncodePart` para gerar `Lines` + `PartBody` + headers.

Suporta convert de charset automatico (`ConvertCharset=True` + `TargetCharset`) para decodificar text parts em `ISO-8859-1`/`UTF-8`/`Windows-1252` etc. para o charset do sistema.

## 2. Caracteristicas

- Modelo arvore arbitraria de parts
- 4 tipos primarios: `MP_TEXT`, `MP_MULTIPART`, `MP_MESSAGE`, `MP_BINARY`
- 6 encodings: `ME_7BIT`, `ME_8BIT`, `ME_QUOTED_PRINTABLE`, `ME_BASE64`, `ME_UU`, `ME_XX`
- Walk pattern via `OnWalkPart` callback
- Mapeamento automatico extensao -> MIME type (`MimeTypeFromExt`) com 27 tipos conhecidos
- Proteccao contra recursao infinita (`MaxSubLevel`)
- Decomposicao binaria optimizada (`DecomposePartsBinary` para dados 8-bit nao encoded)
- Deteccao heuristica de UUencode embutido em text (`AttachInside`)

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| TMimePrimary | `(MP_TEXT, MP_MULTIPART, MP_MESSAGE, MP_BINARY)` |
| TMimeEncoding | `(ME_7BIT, ME_8BIT, ME_QUOTED_PRINTABLE, ME_BASE64, ME_UU, ME_XX)` |
| Default charset | `ISO-8859-1` (RFC); Outlook usa windows code pages |
| MaxMimeType | 26 (total 27 entries na tabela `MimeType[0..26, 0..2]`) |
| THookWalkPart | `procedure(const Sender: TMimePart) of object` |

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Cria com defaults. |
| Destroy | `destructor Destroy; override;` | Liberta arvore inteira. |
| Assign | `procedure Assign(Value: TMimePart);` | Copia so este part. |
| AssignSubParts | `procedure AssignSubParts(Value: TMimePart);` | Copia com arvore completa. |
| Clear | `procedure Clear;` | Reset + `ClearSubParts`. |

### 4.2 Codec

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| DecodePart | `procedure DecodePart;` | `Lines` -> `DecodedLines` (aplica transfer encoding). |
| DecodePartHeader | `procedure DecodePartHeader;` | Parse de `Headers` em properties. |
| EncodePart | `procedure EncodePart;` | `DecodedLines` -> `Lines` + headers. |
| EncodePartHeader | `procedure EncodePartHeader;` | Gera headers a partir de properties. |
| DecomposeParts | `procedure DecomposeParts;` | Decomposicao recursiva a partir de `Lines`. |
| DecomposePartsBinary | `procedure DecomposePartsBinary(AHeader: TStrings; AStx, AEtx: PANSIChar);` | Variante para HTTP 8-bit. |
| ComposeParts | `procedure ComposeParts;` | Composicao recursiva para `Lines`. |
| MimeTypeFromExt | `procedure MimeTypeFromExt(Value: string);` | Adivinha primary/secondary por extensao. |

### 4.3 Subparts

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| GetSubPartCount | `function GetSubPartCount: integer;` | Nao recursivo. |
| GetSubPart | `function GetSubPart(index: integer): TMimePart;` | Acesso por indice. |
| DeleteSubPart | `procedure DeleteSubPart(index: integer);` | Remove + liberta. |
| ClearSubParts | `procedure ClearSubParts;` | Remove todos. |
| AddSubPart | `function AddSubPart: TMimePart;` | Adiciona novo. |
| CanSubPart | `function CanSubPart: boolean;` | Verifica limite `MaxSubLevel`. |
| WalkPart | `procedure WalkPart;` | Invoca `OnWalkPart` para cada part (recursivo). |

### 4.4 Properties - metadata

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Primary | `property string;` | Ex.: `'text'`, `'application'`. |
| Secondary | `property string;` | Ex.: `'plain'`, `'pdf'`. |
| PrimaryCode | `property TMimePrimary;` | `MP_TEXT`/etc. |
| Encoding | `property string;` | Ex.: `'base64'`. |
| EncodingCode | `property TMimeEncoding;` | `ME_BASE64`/etc. |
| Charset | `property string;` | Ex.: `'utf-8'`. |
| CharsetCode | `property TMimeChar;` | Codigo interno. |
| DefaultCharset | `property string;` | Usado se header nao indicar. |
| TargetCharset | `property TMimeChar;` | Para conversao. |
| ConvertCharset | `property Boolean;` | Ligar conversao. |
| ForcedHTMLConvert | `property Boolean;` | Overrride meta tag charset. |
| Description | `property string;` | Content-Description. |
| Disposition | `property string;` | `inline` / `attachment`. |
| ContentID | `property string;` | CID. |
| Boundary | `property string;` | Separador de multipart. |
| FileName | `property string;` | Nome de ficheiro de anexo. |

### 4.5 Properties - conteudo

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Lines | `property TStringList;` | Part em formato MIME (raw). |
| PartBody | `property TStringList;` | Body codificado (sem headers). |
| Headers | `property TStringList;` | So headers. |
| PrePart | `property TStringList;` | Texto antes do 1o boundary em multipart. |
| PostPart | `property TStringList;` | Texto depois do ultimo boundary. |
| DecodedLines | `property TMemoryStream;` | Body decodificado. |
| SubLevel | `property integer;` | Profundidade na arvore (0 = raiz). |
| MaxSubLevel | `property integer;` | Limite de profundidade. |
| AttachInside | `property boolean;` | UUencode embutido detectado. |
| OnWalkPart | `property THookWalkPart;` | Callback. |
| MaxLineLength | `property integer;` | Para encoding split. |

### 4.6 Funcoes globais

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| GenerateBoundary | `function GenerateBoundary: string;` | Boundary unico para multipart. |
| CreateStringList | `function CreateStringList: TStringList;` | `TStringList` sem BOM. |

## 5. Aplicabilidades

1. **Extracao de anexos** -- walk na arvore + save `DecodedLines` para disco.
2. **Composicao avancada** -- multipart/related com imagens inline referenciadas por CID.
3. **Virus gateway** -- decompor mensagem, extrair partes binarias, enviar para ClamAV.
4. **Text extraction para indexacao** -- apanhar MP_TEXT parts + converter charset, enviar para Elasticsearch/Solr.
5. **Cleanup / rebuild** -- remover anexos nocivos (exe, scr, vbs) e recompor.

## 6. Exemplos de uso

### 6.1 Extrair anexos

```pascal
uses
  SysUtils, Classes, mimemess, mimepart;

type
  TWalker = class
    procedure OnPart(const Sender: TMimePart);
  end;

procedure TWalker.OnPart(const Sender: TMimePart);
begin
  if (Sender.PrimaryCode = MP_BINARY) and (Sender.FileName <> '') then
  begin
    Sender.DecodePart;
    Sender.DecodedLines.SaveToFile('/path/to/attachments/' + Sender.FileName);
  end;
end;

var
  LMess: TMimeMess;
  LWalker: TWalker;
begin
  LMess := TMimeMess.Create;
  LWalker := TWalker.Create;
  try
    LMess.Lines.LoadFromFile('/path/to/email.eml');
    LMess.DecodeMessage;
    LMess.MessagePart.OnWalkPart := LWalker.OnPart;
    LMess.MessagePart.WalkPart;
  finally
    LWalker.Free;
    LMess.Free;
  end;
end.
```

### 6.2 Codificar binario em base64 directamente

```pascal
uses
  SysUtils, Classes, mimepart;

var
  LPart: TMimePart;
  LFile: TFileStream;
begin
  LPart := TMimePart.Create;
  LFile := TFileStream.Create('/path/to/doc.pdf', fmOpenRead);
  try
    LPart.DecodedLines.CopyFrom(LFile, LFile.Size);
    LPart.MimeTypeFromExt('doc.pdf');
    LPart.Encoding := 'base64';
    LPart.Disposition := 'attachment';
    LPart.FileName := 'doc.pdf';
    LPart.EncodePart;
    LPart.Lines.SaveToFile('/path/to/doc.mime');
  finally
    LFile.Free;
    LPart.Free;
  end;
end.
```

### 6.3 Walk imprimindo estrutura

```pascal
uses
  SysUtils, mimemess, mimepart;

type
  TPrinter = class
    procedure OnPart(const Sender: TMimePart);
  end;

procedure TPrinter.OnPart(const Sender: TMimePart);
var
  I: Integer;
begin
  for I := 1 to Sender.SubLevel do Write('  ');
  Writeln(Format('- %s/%s (%s)',
    [Sender.Primary, Sender.Secondary, Sender.FileName]));
end;

var
  LMess: TMimeMess;
  LPrinter: TPrinter;
begin
  LMess := TMimeMess.Create;
  LPrinter := TPrinter.Create;
  try
    LMess.Lines.LoadFromFile('/path/to/mail.eml');
    LMess.DecodeMessage;
    LMess.MessagePart.OnWalkPart := LPrinter.OnPart;
    LMess.MessagePart.WalkPart;
  finally
    LPrinter.Free;
    LMess.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TMimeMess` | Consumidor | Wrapper de email completo. |
| `synacode` | Dependencia | Base64, QP, UU encoders/decoders. |
| `synachar` | Dependencia | Conversao de charsets. |
| `synautil` | Dependencia | Helpers. |
| `mimeinln` | Dependencia | RFC-2047 encoded-word. |
| `THookWalkPart` | Type | Callback em walk. |
