# SynaUtil

**Unit:** `synautil.pas` | **Versao:** 004.016.003 | **Tipo:** Unit | **Origem:** Upstream + CSL fork

---

## 1. O que e?

A `synautil` e a unit de utilitarios transversais do pacote Ararat Synapse. Concentra funcoes de baixo nivel usadas por praticamente todos os clientes de protocolo do Synapse (HTTP, SMTP, LDAP, POP3, IMAP, NNTP, FTP) e, no ActiveDirectoryORM, e consumida directamente por `ldapsend.pas`. Agrupa cinco familias principais: (1) datetime / timezone (RFC-822, RFC-3339, ANSI C, asctime); (2) trimming e parsing de strings (SeparateLeft/Right, Fetch, FetchBin, FetchEx, GetBetween, GetParameter); (3) conversao de inteiros big-endian (CodeInt/DecodeInt/CodeLongInt/DecodeLongInt); (4) utilitarios de stream (ReadStrFromStream, WriteStrToStream, PadString, XorString); (5) dump/debug (StrToHex, DumpStr, DumpExStr). O fork CSL acrescentou ao header a intencao de expor helpers `Utf8EncodeToAnsi` / `Utf8DecodeFromAnsi` / `FileTimeToDateTime` / `DateTimeToFileTime` para AD Windows Server 2025, mas o baseline 004.016.003 ainda nao publica essas funcoes no bloco `interface` (roadmap CSL).

## 2. Caracteristicas

- Zero dependencias de GUI ou SQL; usa apenas `SysUtils`, `Classes`, `SynaFpc` e, quando necessario, `Windows` (MSWINDOWS) ou `Unix`/`Posix` (POSIX/FPC).
- Cross-platform: ramos `{$IFDEF MSWINDOWS}`, `{$IFDEF FPC}`, `{$IFDEF POSIX}`, `{$IFDEF OS2}`, `{$IFDEF CIL}`.
- Trabalha predominantemente em `AnsiString` — adequado ao socket layer Synapse que expoe sempre `AnsiString`.
- Isento de classes; todo o conteudo e `function` / `procedure` livre.
- Variavel publica `CustomMonthNames` permite traducao local dos nomes de mes (usada por `GetMonthNumber`).
- Bloco `initialization` reinicializa `CustomMonthNames` e `MyMonthNames[0]` a partir de `FormatSettings.ShortMonthNames`.

## 3. Engine

A engine e puramente Pascal / RTL:

- Datetime: `EncodeDate`, `DecodeDate`, `SystemTimeToDateTime`, `FormatDateTime` (SysUtils / Windows / Posix.SysTime).
- Parsing: `Pos`, `Copy`, `Delete`, `LastDelimiter` da RTL.
- Tick: `QueryPerformanceCounter` / `GetTickCount` (Windows) ou `DateTimeToTimeStamp(Now)` (POSIX).
- Temp file: `GetTempPath` + `GetTempFileName` (Windows) ou `tempnam` (POSIX).
- `initialization` aproveita `FormatSettings.ShortMonthNames` para localizar nomes de meses ingleses/alemaes/franceses/checos.

## 4. Funcionalidades

### 4.1 Datetime e timezone

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `TimeZoneBias` | `function TimeZoneBias: integer;` | Devolve offset local em minutos face a UTC (considera DST). |
| `TimeZone` | `function TimeZone: string;` | Devolve offset no formato `+HHMM` / `-HHMM`. |
| `Rfc822DateTime` | `function Rfc822DateTime(t: TDateTime): string;` | `Fri, 15 Oct 1999 21:14:56 +0200`. |
| `Rfc822DateTimeGMT` | `function Rfc822DateTimeGMT(t: TDateTime): string;` | Como anterior, mas em GMT. |
| `Rfc3339DateTime` | `function Rfc3339DateTime(t: TDateTime): string;` | `yyyy-mm-ddThh:nn:ss.zzz+HHMM`. |
| `CDateTime` | `function CDateTime(t: TDateTime): string;` | `mmm dd hh:nn:ss`. |
| `SimpleDateTime` | `function SimpleDateTime(t: TDateTime): string;` | `yymmdd hhnnss`. |
| `AnsiCDateTime` | `function AnsiCDateTime(t: TDateTime): string;` | `ddd mmm d hh:nn:ss yyyy`. |
| `GetMonthNumber` | `function GetMonthNumber(Value: String): integer;` | Tres letras -> 1..12 (EN/FR/DE/CZ + locale). |
| `GetTimeFromStr` | `function GetTimeFromStr(Value: string): TDateTime;` | `hh:mm` ou `hh:mm:ss`. |
| `DecodeTimeZone` | `function DecodeTimeZone(Value: string; var Zone: integer): Boolean;` | Aceita `+0200`, `CEST`, `GMT`, etc. |
| `GetDateMDYFromStr` | `function GetDateMDYFromStr(Value: string): TDateTime;` | Formato `m-d-y`. |
| `DecodeRfcDateTime` | `function DecodeRfcDateTime(Value: string): TDateTime;` | Multi-formato (RFC-822/1123/850/asctime). |
| `GetUTTime` | `function GetUTTime: TDateTime;` | Data/hora UTC do sistema. |
| `SetUTTime` | `function SetUTTime(Newdt: TDateTime): Boolean;` | Grava UTC no relogio (precisa Administrator). |
| `GetTick` | `function GetTick: LongWord;` | Tick em milissegundos (PerformanceCounter). |
| `TickDelta` | `function TickDelta(TickOld, TickNew: LongWord): LongWord;` | Delta com tratamento de rollover. |

> Nota: `FileTimeToDateTime` / `DateTimeToFileTime` / `Utf8EncodeToAnsi` / `Utf8DecodeFromAnsi` estao declarados como intencao no header CSL (linhas 54-61) mas nao fazem parte do bloco `interface` deste baseline; AD WS 2025 FileTime deve usar por agora `FileTimeToSystemTime` do `Windows.pas` ou os helpers de `ActiveDirectory.Helpers`.

### 4.2 Codificacao de inteiros big-endian

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `CodeInt` | `function CodeInt(Value: Word): Ansistring;` | Word -> 2 bytes big-endian. |
| `DecodeInt` | `function DecodeInt(const Value: Ansistring; Index: Integer): Word;` | 2 bytes BE -> Word. |
| `CodeLongInt` | `function CodeLongInt(Value: LongInt): Ansistring;` | LongInt -> 4 bytes BE. |
| `DecodeLongInt` | `function DecodeLongInt(const Value: Ansistring; Index: Integer): LongInt;` | 4 bytes BE -> LongInt. |
| `SwapBytes` | `function SwapBytes(Value: integer): integer;` | Byte reversal. |

### 4.3 String parsing e fetch

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `TrimSPLeft` | `function TrimSPLeft(const S: string): string;` | Remove so espacos a esquerda. |
| `TrimSPRight` | `function TrimSPRight(const S: string): string;` | Remove so espacos a direita. |
| `TrimSP` | `function TrimSP(const S: string): string;` | Combinacao dos dois. |
| `SeparateLeft` | `function SeparateLeft(const Value, Delimiter: string): string;` | Fragmento antes do delimitador. |
| `SeparateRight` | `function SeparateRight(const Value, Delimiter: string): string;` | Fragmento depois do delimitador. |
| `GetParameter` | `function GetParameter(const Value, Parameter: string): string;` | `param1="v1"; param2=v2` -> valor. |
| `ParseParameters` | `procedure ParseParameters(Value: string; const Parameters: TStrings);` | Separa por `;`. |
| `ParseParametersEx` | `procedure ParseParametersEx(Value, Delimiter: string; const Parameters: TStrings);` | Separa por delimitador custom. |
| `IndexByBegin` | `function IndexByBegin(Value: string; const List: TStrings): integer;` | Procura prefixo (case-insensitive). |
| `GetEmailAddr` | `function GetEmailAddr(const Value: string): string;` | Extrai `nobody@x.com` de `"someone" <nobody@x.com>`. |
| `GetEmailDesc` | `function GetEmailDesc(Value: string): string;` | Extrai `someone` de `"someone" <nobody@x.com>`. |
| `ReplaceString` | `function ReplaceString(Value, Search, Replace: AnsiString): AnsiString;` | Substitui todas as ocorrencias. |
| `RPosEx` | `function RPosEx(const Sub, Value: string; From: integer): Integer;` | Reverse-Pos a partir de offset. |
| `RPos` | `function RPos(const Sub, Value: String): Integer;` | Pos reverso. |
| `PosFrom` | `function PosFrom(const SubStr, Value: String; From: integer): integer;` | Pos a partir de posicao. |
| `Fetch` | `function Fetch(var Value: string; const Delimiter: string): string;` | Consome e retorna head ate delimitador. |
| `FetchBin` | `function FetchBin(var Value: string; const Delimiter: string): string;` | Idem para binario. |
| `FetchEx` | `function FetchEx(var Value: string; const Delimiter, Quotation: string): string;` | Ignora delimitador dentro de quotes. |
| `GetBetween` | `function GetBetween(const PairBegin, PairEnd, Value: string): string;` | Respeita nesting (`(hello(yes!))` -> `hello(yes!)`). |
| `CountOfChar` | `function CountOfChar(const Value: string; Chr: char): integer;` | Conta ocorrencias de caracter. |
| `UnquoteStr` | `function UnquoteStr(const Value: string; Quote: Char): string;` | Remove aspas envolventes. |
| `QuoteStr` | `function QuoteStr(const Value: string; Quote: Char): string;` | Adiciona aspas e duplica internas. |
| `IsBinaryString` | `function IsBinaryString(const Value: AnsiString): Boolean;` | True se contem chars nao-imprimiveis. |
| `PosCRLF` | `function PosCRLF(const Value: AnsiString; var Terminator: AnsiString): integer;` | Deteccao de terminador (CRLF/LFCR/CR/LF). |
| `StringsTrim` | `procedure StringsTrim(const value: TStrings);` | Remove linhas vazias finais. |

### 4.4 Hex / Binario / Dump

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `StrToHex` | `function StrToHex(const Value: Ansistring): string;` | Cada byte -> 2 hex lowercase. |
| `IntToBin` | `function IntToBin(Value: Integer; Digits: Byte): string;` | Inteiro -> string de `0`/`1`. |
| `BinToInt` | `function BinToInt(const Value: string): Integer;` | `"10001010"` -> 138. |
| `DumpStr` | `function DumpStr(const Buffer: Ansistring): string;` | Todos os bytes como ` +#$xx`. |
| `DumpExStr` | `function DumpExStr(const Buffer: Ansistring): string;` | Chars imprimiveis como `'A'`, resto hex. |
| `Dump` | `procedure Dump(const Buffer: AnsiString; DumpFile: string);` | Escreve `DumpStr` em ficheiro. |
| `DumpEx` | `procedure DumpEx(const Buffer: AnsiString; DumpFile: string);` | Escreve `DumpExStr` em ficheiro. |

### 4.5 URL, streams e headers

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `ParseURL` | `function ParseURL(URL: string; var Prot, User, Pass, Host, Port, Path, Para: string): string;` | Decompoe URL completa. |
| `ReadStrFromStream` | `function ReadStrFromStream(const Stream: TStream; len: integer): AnsiString;` | Le `len` bytes em string. |
| `WriteStrToStream` | `procedure WriteStrToStream(const Stream: TStream; Value: AnsiString);` | Escreve string binaria. |
| `GetTempFile` | `function GetTempFile(const Dir, prefix: String): String;` | Nome de ficheiro temporario. |
| `PadString` | `function PadString(const Value: AnsiString; len: integer; Pad: AnsiChar): AnsiString;` | Padding/truncatura. |
| `XorString` | `function XorString(Indata1, Indata2: AnsiString): AnsiString;` | XOR byte-a-byte. |
| `NormalizeHeader` | `function NormalizeHeader(Value: TStrings; var Index: Integer): string;` | Fold de headers multi-linha. |
| `HeadersToList` | `procedure HeadersToList(const Value: TStrings);` | `name: value` -> `name=value`. |
| `ListToHeaders` | `procedure ListToHeaders(const Value: TStrings);` | Inverso. |
| `IncPoint` | `function IncPoint(const p: pointer; Value: integer): pointer;` | Aritmetica de ponteiros (nao disponivel em CIL). |

### 4.6 Line-break helpers (Petr Fejfar contrib)

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SearchForLineBreak` | `procedure SearchForLineBreak(var APtr: PANSIChar; AEtx: PANSIChar; out ABol: PANSIChar; out ALength: integer);` | Avanca ate CR/LF/NUL. |
| `SkipLineBreak` | `procedure SkipLineBreak(var APtr: PANSIChar; AEtx: PANSIChar);` | Salta CRLF. |
| `SkipNullLines` | `procedure SkipNullLines(var APtr: PANSIChar; AEtx: PANSIChar);` | Pula linhas vazias consecutivas. |
| `CopyLinesFromStreamUntilNullLine` | `procedure CopyLinesFromStreamUntilNullLine(var APtr: PANSIChar; AEtx: PANSIChar; ALines: TStrings);` | Copia ate linha vazia. |
| `CopyLinesFromStreamUntilBoundary` | `procedure CopyLinesFromStreamUntilBoundary(var APtr: PANSIChar; AEtx: PANSIChar; ALines: TStrings; const ABoundary: ANSIString);` | Copia ate boundary MIME. |
| `SearchForBoundary` | `function SearchForBoundary(var APtr: PANSIChar; AEtx: PANSIChar; const ABoundary: ANSIString): PANSIChar;` | Procura boundary. |
| `MatchBoundary` | `function MatchBoundary(ABOL, AETX: PANSIChar; const ABoundary: ANSIString): PANSIChar;` | Compara posicao com boundary. |
| `MatchLastBoundary` | `function MatchLastBoundary(ABOL, AETX: PANSIChar; const ABoundary: ANSIString): PANSIChar;` | Boundary terminador (`--boundary--`). |
| `BuildStringFromBuffer` | `function BuildStringFromBuffer(AStx, AEtx: PANSIChar): ANSIString;` | Copia range de ponteiros. |

### 4.7 Constantes e variaveis publicas

- `CustomMonthNames: array[1..12] of string` — override localizado dos nomes de mes.

## 5. Aplicabilidades

- **LDAP (ldapsend):** parsing de filtros LDAP, encoding de DNs, conversao big-endian de tamanhos ASN.1 (`CodeInt`/`DecodeInt`).
- **Active Directory (ADORM):** helpers de tempo para `pwdLastSet`, `lastLogonTimestamp`, `accountExpires`, `whenCreated`, `whenChanged`; parsing de `dnsHostName`.
- **HTTP/SMTP/POP3 (outros clientes Synapse):** `Rfc822DateTime` para header `Date:`, `ParseURL` para URL absoluta, `NormalizeHeader` para RFC-822 folding.
- **Debugging/logging:** `DumpStr`/`DumpExStr` para capturar buffers ASN.1 em logs de ldapsend.
- **MIME parsing:** toda a familia `SearchForBoundary` / `MatchBoundary` e base de `mimepart` e `mimemess`.

## 6. Exemplos de uso

```pascal
uses
  SysUtils, synautil;
var
  dt: TDateTime;
  rfc: string;
  user, desc: string;
begin
  // 1. Formatar uma data no formato RFC-822 (header HTTP/SMTP Date:)
  rfc := Rfc822DateTime(Now);
  Writeln('Date: ', rfc);

  // 2. Extrair endereco + descricao de uma string de email composta
  desc := GetEmailDesc('"John Doe" <john.doe@empresa.local>');
  user := GetEmailAddr('"John Doe" <john.doe@empresa.local>');
  Writeln('Desc=', desc, ' Addr=', user);

  // 3. Decodificar data de log AD
  dt := DecodeRfcDateTime('Fri, 15 Oct 1999 21:14:56 +0200');
  Writeln(FormatDateTime('yyyy-mm-dd hh:nn:ss', dt));
end;
```

```pascal
uses
  SysUtils, synautil;
var
  raw, head: string;
begin
  // Fetch progressivo com delimitador
  raw := 'cn=John Doe,ou=Users,dc=empresa,dc=local';
  while raw <> '' do
  begin
    head := Fetch(raw, ',');
    Writeln('RDN: ', head);
  end;
  // Saida: cn=John Doe / ou=Users / dc=empresa / dc=local
end;
```

```pascal
uses
  SysUtils, Classes, synautil;
var
  s: string;
  ms: TMemoryStream;
begin
  // Dump de buffer binario para diagnostico LDAP
  s := CodeInt(65535) + CodeLongInt(12345678);
  Writeln('Hex: ', StrToHex(s));       // hex lowercase
  Writeln('Dump: ', DumpExStr(s));     // chars imprimiveis + bytes

  // Escrita/leitura de stream em AnsiString
  ms := TMemoryStream.Create;
  try
    WriteStrToStream(ms, s);
    ms.Position := 0;
    Writeln('Lido: ', StrToHex(ReadStrFromStream(ms, ms.Size)));
  finally
    ms.Free;
  end;
end;
```

## 7. Relacionamentos

- **Consumida por:** `blcksock.pas`, `ldapsend.pas`, `httpsend.pas`, `smtpsend.pas`, `pop3send.pas`, `imapsend.pas`, `nntpsend.pas`, `ftpsend.pas`, `synadbg.pas`, `synaip.pas`, `synachar.pas`, `synaicnv.pas` (indirectamente), `synacrypt.pas`, `mimepart.pas`, `mimemess.pas`, `asn1util.pas`.
- **Depende de:** `SysUtils`, `Classes`, `SynaFpc`, `Windows` (MSWINDOWS), `Unix`/`BaseUnix`/`UnixUtil` (FPC Unix), `Posix.*` (Delphi POSIX), `Libc` (Kylix), `System.IO` (CIL), `AnsiStrings` (DelphiX Seattle+).
- **Fork CSL:** ~70 linhas de diferenca face a `bak/synautil.pas.bak`; header documenta futuras `FileTimeToDateTime`, `DateTimeToFileTime`, `Utf8EncodeToAnsi`, `Utf8DecodeFromAnsi` para AD WS 2025 (roadmap — nao expostas no baseline).
