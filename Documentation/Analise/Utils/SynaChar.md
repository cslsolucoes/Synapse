# SynaChar

**Unit:** `synachar.pas` | **Versao:** 005.002.005 | **Tipo:** Unit | **Origem:** Upstream

---

## 1. O que e?

A `synachar` e a unit de conversao entre code pages / charsets do pacote Ararat Synapse. Suporta ~100 charsets (ISO-8859-1..16, CP1250-1258, KOI8-R/U/RU/T, Shift-JIS, GB2312, Big5, EUC-JP/KR/TW, UTF-7/8/16/32, CP737..CP1361, etc.) atraves de duas abordagens complementares: (1) tabelas internas em memoria (charsets europeus/americanos mais comuns, via constantes `CharISO_8859_X`) e (2) chamadas dinamicas a `libiconv` via `synaicnv` para charsets asiaticos e exoticos (conjunto `IconvOnlyChars`). Expoe tambem conversao para/de `WideString` (UCS-2 little endian), tabelas de transliteracao (ex. `Replace_Czech`), e utilitarios de deteccao de charset ideal (`IdealCharsetCoding`).

## 2. Caracteristicas

- Enumerado `TMimeChar` com ~100 valores cobrindo todo o espectro relevante RFC-2978.
- Tabelas pre-carregadas so para charsets europeus/americanos; asiaticos redirigem para libiconv.
- Flag `DisableIconv: Boolean = False` permite desactivar libiconv globalmente.
- Constantes `NoIconvChars` (so internamente) e `IconvOnlyChars` (so libiconv).
- Tabelas de transliteracao `Replace_None`, `Replace_Czech`, e suporte para tabelas customizadas (array of Word UCS-2 pairs).
- Default set `IdealCharsets` com ISO-8859-1..10, KOI8-R/U, GB2312, EUC-KR, ISO-2022-JP, EUC-TW para auto-deteccao.
- Todas as funcoes retornam `AnsiString` binario. Conversao de/para WideString explicita via `StringToWide`/`WideToString`.

## 3. Engine

Duas engines:

- **Interna (tabelas):** arrays `CharISO_8859_X: array[128..255] of Word` (UCS-2). Converte byte -> UCS-2 -> byte via `Pos` em tabela reversa.
- **Externa (libiconv):** `synaicnv.SynaIconvOpen`, `SynaIconv`, `SynaIconvClose` via DLL dinamica `iconv.dll`/`libiconv.so`. Aberto com sufixo `//IGNORE//TRANSLIT` para caracteres nao convertiveis.
- **OEM/ANSI:** `GetACP` + `GetOEMCP` (Windows), `nl_langinfo` (POSIX), ou deteccao via `GetLocaleInfo` como fallback.

## 4. Funcionalidades

### 4.1 Conversao

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `CharsetConversion` | `function CharsetConversion(const Value: AnsiString; CharFrom, CharTo: TMimeChar): AnsiString;` | Conversao simples entre charsets. |
| `CharsetConversionEx` | `function CharsetConversionEx(const Value: AnsiString; CharFrom, CharTo: TMimeChar; const TransformTable: array of Word): AnsiString;` | Com tabela de transliteracao UCS-2. |
| `CharsetConversionTrans` | `function CharsetConversionTrans(Value: AnsiString; CharFrom, CharTo: TMimeChar; const TransformTable: array of Word; Translit: Boolean): AnsiString;` | Permite desligar transliteracao. |

### 4.2 Deteccao de charset

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetCurCP` | `function GetCurCP: TMimeChar;` | Charset do SO (ACP Windows ou `nl_langinfo` POSIX). |
| `GetCurOEMCP` | `function GetCurOEMCP: TMimeChar;` | Charset OEM (DOS box, Windows). |
| `NeedCharsetConversion` | `function NeedCharsetConversion(const Value: AnsiString): Boolean;` | True se contem chars > 127. |
| `IdealCharsetCoding` | `function IdealCharsetCoding(const Value: AnsiString; CharFrom: TMimeChar; CharTo: TMimeSetChar): TMimeChar;` | Selecciona charset destino com menos perdas. |

### 4.3 Mapeamento enum <-> string

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetCPFromID` | `function GetCPFromID(Value: AnsiString): TMimeChar;` | `"ISO-8859-2"` -> `ISO_8859_2`. |
| `GetIDFromCP` | `function GetIDFromCP(Value: TMimeChar): AnsiString;` | `ISO_8859_2` -> `"ISO-8859-2"`. |
| `GetIconvIDFromCP` | `function GetIconvIDFromCP(Value: TMimeChar): AnsiString;` | ID no formato libiconv. |
| `GetCPFromIconvID` | `function GetCPFromIconvID(Value: AnsiString): TMimeChar;` | Inverso. |

### 4.4 Unicode helpers

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetBOM` | `function GetBOM(Value: TMimeChar): AnsiString;` | BOM para `UCS_2`/`UCS_2LE`/`UTF_8`/`UTF_16`/etc. |
| `StringToWide` | `function StringToWide(const Value: AnsiString): WideString;` | `AnsiString` binario UCS-2 -> `WideString`. |
| `WideToString` | `function WideToString(const Value: WideString): AnsiString;` | Inverso. |

### 4.5 Tipos e constantes publicas

| Nome | Tipo | Descricao |
| --- | --- | --- |
| `TMimeChar` | `enum` | ~100 charsets (ISO_8859_1..16, CP1250..CP1361, KOI8_R..T, UTF_7/8/16/32, Shift_JIS, GB2312..GB18030, BIG5, EUC_JP/KR/TW). |
| `TMimeSetChar` | `set of TMimeChar` | Conjunto de charsets. |
| `IconvOnlyChars` | `set of TMimeChar` | Charsets so via libiconv. |
| `NoIconvChars` | `set of TMimeChar` | `CP895`, `UTF_7mod` (so interno). |
| `DisableIconv: Boolean` | `var` | Desactiva libiconv globalmente. |
| `IdealCharsets: TMimeSetChar` | `var` | Default set para auto-deteccao. |
| `Replace_None` | `array[0..0] of Word` | Tabela vazia (disable replace). |
| `Replace_Czech` | `array[0..59] of Word` | Remove diakritics Checa. |

## 5. Aplicabilidades

- **MIME (mimepart):** decode de `Content-Type: text/plain; charset=iso-8859-1` e conversao para local.
- **SMTP/POP3/IMAP:** conversao de subject/body entre charsets de email.
- **HTTP:** response body com `Content-Type: text/html; charset=GB2312` -> UTF-8.
- **LDAP (ldapsend):** necessario quando AD devolve atributos em UTF-8 e aplicacao local e Windows-1252; mas o ActiveDirectoryORM prefere wrappers `Utf8Encode`/`Utf8Decode` da RTL para este caso especifico.
- **Newsgroup (nntp):** `DecodeYEnc` (em synacode) + charset conversion.
- **Transliteracao:** remocao de acentos para slugs ou sorting ASCII.

## 6. Exemplos de uso

```pascal
uses
  SysUtils, synachar;
var
  s, u: AnsiString;
begin
  // Converter string CP1252 (Windows-1252) para UTF-8
  s := 'Ol' + AnsiChar(#$E1) + ' Jo' + AnsiChar(#$E3) + 'o';  // 'Olá João' em CP1252
  u := CharsetConversion(s, CP1252, UTF_8);
  Writeln('UTF-8 = ', u);

  // Obter charset do sistema
  Writeln('SO charset = ', GetIDFromCP(GetCurCP));
end;
```

```pascal
uses
  SysUtils, synachar;
var
  original, no_accents: AnsiString;
begin
  // Transliterar: remover acentos checos
  original := 'Pří' + AnsiChar(#$9A) + 'erná ' + AnsiChar(#$BE) + 'lu' + AnsiChar(#$9D) + 'ou' + AnsiChar(#$E8) + 'ká';
  no_accents := CharsetConversionEx(original, ISO_8859_2, ISO_8859_1, Replace_Czech);
  Writeln('Sem acentos: ', no_accents);
end;
```

```pascal
uses
  SysUtils, synachar;
var
  bom: AnsiString;
  wide: WideString;
begin
  // Usar BOM para UTF-8
  bom := GetBOM(UTF_8);                        // #$EF#$BB#$BF
  Writeln('BOM UTF-8 len = ', Length(bom));

  // AnsiString binaria UCS-2 LE -> WideString
  wide := StringToWide(#$48#$00#$69#$00#$21#$00);
  Writeln(wide);  // "Hi!"
end;
```

## 7. Relacionamentos

- **Consumida por:** `mimeinln.pas` (inline encode para headers), `mimepart.pas` (body charset), `mimemess.pas`.
- **Depende de:** `SysUtils`, `synautil`, `synacode`, `synaicnv`, `synafpc`, `Windows`/`Libc`/`Posix.Langinfo`.
- **Interage com:** `synaicnv` para carga dinamica de libiconv.
- **Fork CSL:** sem modificacoes registadas (upstream puro 005.002.005).
