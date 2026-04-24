# SynaCode

**Unit:** `synacode.pas` | **Versao:** 002.002.005 | **Tipo:** Unit | **Origem:** Upstream + CSL fork

---

## 1. O que e?

A `synacode` e o modulo de encoding/decoding e hashing do pacote Ararat Synapse. Agrupa quatro familias: (1) encoding `N-to-M` (Base64 padrao + modificado IMAP, UU, XX, YEnc); (2) triplet encoding (quoted-printable + URL percent-encoding); (3) hashes criptograficos (MD5, MD4, SHA-1 + variantes HMAC e LongHash); (4) checksums (CRC32, CRC16 com tabela pre-calculada). O fork CSL introduziu pequenos ajustes (~4 linhas) para compatibilidade Delphi 12 Alexandria, normalizacao de EOL e aliases de tipos. A unit e completamente self-contained (depende apenas de `SysUtils` e, em NEXTGEN, `SynaFpc`) e nao chama bibliotecas externas — util para fallback quando OpenSSL / libiconv nao estao disponiveis.

## 2. Caracteristicas

- Encoding puramente Pascal; nao requer OpenSSL, libiconv ou outras DLLs.
- Define `SYNACODE_NATIVE` para fallback em plataformas big-endian ou CIL (cada transformacao byte-a-byte).
- Tres tabelas Base64 diferentes: `TableBase64` (RFC-2045 padrao), `TableBase64mod` (IMAP UTF-7), `TableUU`, `TableXX` com reverses pre-calculados (`ReTableBase64`, `ReTableUU`, `ReTableXX`).
- Hashes implementados raw (sem OpenSSL): `MD5`, `MD4`, `SHA-1` com todas as rondas e constantes baseadas em RFC-1321/3174.
- Typedef `TSpecials = set of AnsiChar` com constantes `SpecialChar`, `NonAsciiChar`, `URLFullSpecialChar`, `URLSpecialChar` para uso com `EncodeTriplet`.

## 3. Engine

Engine Pascal pura:

- Tabelas constantes (`Crc32Tab`, `Crc16Tab`) com 256 entries pre-calculadas.
- Para MD5/SHA-1: structs internos `TMDCtx` (MD4/MD5) e `TSHA1Ctx` com buffers de 64 bytes.
- Inteiros `Integer` (32-bit signed) usados como `LongWord` via cast explicito para evitar overflow.
- `ArrByteToLong`/`ArrLongToByte`: conversao endian-aware com fallback byte-a-byte sob `SYNACODE_NATIVE`.

## 4. Funcionalidades

### 4.1 Triplet encoding (URL + quoted-printable)

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `DecodeTriplet` | `function DecodeTriplet(const Value: AnsiString; Delimiter: AnsiChar): AnsiString;` | Decode generico `=7F` ou `%7F`. |
| `DecodeQuotedPrintable` | `function DecodeQuotedPrintable(const Value: AnsiString): AnsiString;` | Delimiter = `=`. |
| `DecodeURL` | `function DecodeURL(const Value: AnsiString): AnsiString;` | Delimiter = `%`. |
| `EncodeTriplet` | `function EncodeTriplet(const Value: AnsiString; Delimiter: AnsiChar; Specials: TSpecials): AnsiString;` | Codifica so chars em `Specials`. |
| `EncodeQuotedPrintable` | `function EncodeQuotedPrintable(const Value: AnsiString): AnsiString;` | Codifica `=` + NonAscii. |
| `EncodeSafeQuotedPrintable` | `function EncodeSafeQuotedPrintable(const Value: AnsiString): AnsiString;` | Codifica Special + NonAscii. |
| `EncodeURLElement` | `function EncodeURLElement(const Value: AnsiString): AnsiString;` | Inclui delimitadores URL (`/`, `:`, `@`). |
| `EncodeURL` | `function EncodeURL(const Value: AnsiString): AnsiString;` | So criticos; preserva delimitadores. |

### 4.2 Base64 / UU / XX / YEnc

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Decode4to3` | `function Decode4to3(const Value, Table: AnsiString): AnsiString;` | 4 chars -> 3 bytes (generico). |
| `Decode4to3Ex` | `function Decode4to3Ex(const Value, Table: AnsiString): AnsiString;` | Usa REVERSE table (mais rapido). |
| `Encode3to4` | `function Encode3to4(const Value, Table: AnsiString): AnsiString;` | 3 bytes -> 4 chars. |
| `DecodeBase64` | `function DecodeBase64(const Value: AnsiString): AnsiString;` | RFC-2045 Base64. |
| `EncodeBase64` | `function EncodeBase64(const Value: AnsiString): AnsiString;` | RFC-2045 Base64. |
| `DecodeBase64mod` | `function DecodeBase64mod(const Value: AnsiString): AnsiString;` | Base64 IMAP (`+` -> `,`). |
| `EncodeBase64mod` | `function EncodeBase64mod(const Value: AnsiString): AnsiString;` | Base64 IMAP. |
| `DecodeUU` | `function DecodeUU(const Value: AnsiString): AnsiString;` | UUencode (uunet). |
| `EncodeUU` | `function EncodeUU(const Value: AnsiString): AnsiString;` | UUencode (sem header/footer). |
| `DecodeXX` | `function DecodeXX(const Value: AnsiString): AnsiString;` | XXencode. |
| `DecodeYEnc` | `function DecodeYEnc(const Value: AnsiString): AnsiString;` | YEnc para Usenet. |

### 4.3 CRCs

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `UpdateCrc32` | `function UpdateCrc32(Value: Byte; Crc32: Cardinal): Cardinal;` | Step de CRC32 polinomio 0xEDB88320. |
| `Crc32` | `function Crc32(const Value: AnsiString): Cardinal;` | CRC32 completo de string. |
| `UpdateCrc16` | `function UpdateCrc16(Value: Byte; Crc16: Word): Word;` | Step CRC16. |
| `Crc16` | `function Crc16(const Value: AnsiString): Word;` | CRC16 completo. |

### 4.4 Hashes criptograficos

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `MD5` | `function MD5(const Value: AnsiString): AnsiString;` | RSA-MD5 (RFC-1321). 16 bytes binarios. |
| `MD4` | `function MD4(const Value: AnsiString): AnsiString;` | RSA-MD4. 16 bytes. |
| `HMAC_MD5` | `function HMAC_MD5(Text, Key: AnsiString): AnsiString;` | HMAC-MD5 (RFC-2104). |
| `MD5LongHash` | `function MD5LongHash(const Value: AnsiString; Len: integer): AnsiString;` | Hash de repeticao ate `Len`. |
| `SHA1` | `function SHA1(const Value: AnsiString): AnsiString;` | SHA-1 (FIPS-180). 20 bytes. |
| `HMAC_SHA1` | `function HMAC_SHA1(Text, Key: AnsiString): AnsiString;` | HMAC-SHA1 (RFC-2104). |
| `SHA1LongHash` | `function SHA1LongHash(const Value: AnsiString; Len: integer): AnsiString;` | Analogue a MD5LongHash. |

### 4.5 Constantes publicas

| Nome | Tipo | Valor |
| --- | --- | --- |
| `SpecialChar` | `TSpecials` | `['=','(',')','[',']','<','>',':',';',',','@','/','?','\','"','_']`. |
| `NonAsciiChar` | `TSpecials` | `[#0..#31, #127..#255]`. |
| `URLFullSpecialChar` | `TSpecials` | `[';','/','?',':','@','=','&','#','+']`. |
| `URLSpecialChar` | `TSpecials` | `[#0..#20, '<','>','"','%','{','}','|','\','^','[',']','`',#127..#255]`. |
| `TableBase64` | `AnsiString` | Base64 padrao + `+/=`. |
| `TableBase64mod` | `AnsiString` | Base64 IMAP (`,` em vez de `/`). |
| `TableUU` / `TableXX` | `AnsiString` | Tabelas UU/XX. |
| `ReTableBase64` / `ReTableUU` / `ReTableXX` | `AnsiString` | Reverse lookup para Decode4to3Ex. |

## 5. Aplicabilidades

- **LDAP (ldapsend):** SASL DIGEST-MD5 (via `HMAC_MD5`), DIGEST-SHA-1, encoding de password com `MD5LongHash`.
- **HTTP/SMTP:** autenticacao Basic (Base64 do `user:pass`), Digest Access Authentication (`MD5`), SMTP AUTH CRAM-MD5 (`HMAC_MD5`).
- **MIME (mimepart):** `DecodeQuotedPrintable` / `EncodeQuotedPrintable` / `DecodeBase64` / `EncodeBase64` para attachments e headers `Content-Transfer-Encoding`.
- **FTP:** `Crc32` para verificar checksum de transferencias.
- **URL:** `EncodeURL` / `DecodeURL` para query strings.
- **AD LDAP:** encoding MIME-friendly de password, tokens HMAC para integracao com modules que assinam requisicoes.

## 6. Exemplos de uso

```pascal
uses
  SysUtils, synacode, synautil;
var
  raw, b64, back: AnsiString;
  h: AnsiString;
begin
  // Autenticacao HTTP Basic: user:password em Base64
  raw := 'admin:passw0rd';
  b64 := EncodeBase64(raw);
  Writeln('Authorization: Basic ', b64);

  back := DecodeBase64(b64);
  Writeln('Decoded: ', back);

  // Hash MD5 binario -> hex lowercase
  h := MD5('Hello AD');
  Writeln('MD5 = ', StrToHex(h));
end;
```

```pascal
uses
  SysUtils, synacode;
var
  original, enc, dec: AnsiString;
begin
  // Quoted-printable (MIME header com acentos)
  original := 'Jo=C3=A3o Silva';  // ja contem `=` literal
  enc := EncodeSafeQuotedPrintable('João Silva');
  Writeln(enc);  // Jo=C3=A3o Silva (se input UTF-8)
  dec := DecodeQuotedPrintable(enc);
  Writeln(dec);
end;
```

```pascal
uses
  SysUtils, synacode, synautil;
var
  hmac: AnsiString;
  crc: Cardinal;
begin
  // HMAC-MD5 para SASL CRAM-MD5
  hmac := HMAC_MD5('<challenge@server>', 'senha-secreta');
  Writeln('HMAC: ', StrToHex(hmac));

  // CRC32 para integridade de arquivos
  crc := Crc32('conteudo a validar');
  Writeln(Format('CRC32 = %.8x', [crc]));
end;
```

## 7. Relacionamentos

- **Consumida por:** `smtpsend.pas` (AUTH/DIGEST), `pop3send.pas` (APOP), `imapsend.pas` (AUTH), `httpsend.pas` (Basic/Digest), `nntpsend.pas`, `ftpsend.pas`, `ldapsend.pas` (SASL DIGEST-MD5), `mimepart.pas` (Quoted-Printable/Base64), `mimemess.pas`, `synachar.pas` (UTF-7 encode).
- **Depende de:** `SysUtils`, `SynaFpc` (so em NEXTGEN).
- **Nao depende:** de `synautil` ou `blcksock` — e a unit "mais baixa" da cadeia Synapse.
- **Fork CSL:** ~4 linhas para Delphi 12 Alexandria (type aliases, EOL); baseline preservado em `bak/synacode.pas.bak`.
