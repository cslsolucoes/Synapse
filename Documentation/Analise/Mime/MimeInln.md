# MimeInln

**Unit:** `mimeinln.pas` | **Versao:** 001.001.011 | **Tipo:** Unit (funcoes) | **Origem:** Upstream

---

## 1. O que e?

`mimeinln.pas` implementa o encoding/decoding de MIME inline conforme RFC-2047 ("MIME Part Three: Message Header Extensions for Non-ASCII Text") e RFC-2231 ("MIME Parameter Value and Encoded Word Extensions"). O RFC-2047 define o formato `=?charset?encoding?encoded_text?=` usado em headers de email (Subject, From, To, etc.) para transportar caracteres nao-ASCII -- por exemplo `=?UTF-8?B?YcOnw6Nv?=` para `"ação"` em UTF-8 Base64.

A unit e stateless (nao tem classe principal) e oferece funcoes puras para decodificar qualquer mistura de encoded-words e texto ASCII literal numa string, e para encodar strings nao-ASCII em encoded-words com charset explicito ou auto-detectado. Tambem expoe helpers especializados para encoding de enderecos de email (`InlineEmail`) que respeitam a sintaxe RFC-2822 (preservando `<local@domain>`).

`NeedInline` e um predicado que decide se uma string contem caracteres que obrigam a encoding RFC-2047 -- usado internamente em `TMessHeader.EncodeHeaders` para emitir encoded-word so quando necessario.

## 2. Caracteristicas

- Encoding/decoding RFC-2047 (encoded-word) + RFC-2231 (continuation)
- Auto-deteccao de charset a partir do sistema (via `synachar`)
- Escolha automatica de Q (quoted-printable) ou B (base64) conforme densidade de bytes nao-ASCII
- Helper especializado para enderecos email (`InlineEmail`, `InlineEmailEx`)
- Stateless (funcoes puras)
- Cooperacao com `TMessHeader` via `DecodeHeader`/`EncodeHeaders`

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Unit | `mimeinln.pas` |
| Dependencias | `synachar`, `synacode`, `synautil` |
| Formato | `=?charset?B?base64?=` ou `=?charset?Q?quoted-printable?=` |
| RFC | RFC-2047, RFC-2231 |

## 4. Funcionalidades

### 4.1 Decode

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| InlineDecode | `function InlineDecode(const Value: string; CP: TMimeChar): string;` | Decodifica encoded-words em `Value`; converte para charset alvo `CP` (ex.: charset do sistema). |

### 4.2 Encode

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| InlineEncode | `function InlineEncode(const Value: string; CP, MimeP: TMimeChar): string;` | Encoda `Value` (do charset `CP` para o charset de saida `MimeP`). |
| InlineCode | `function InlineCode(const Value: string): string;` | Auto: source = charset do sistema; target = charset compativel auto-escolhido. |
| InlineCodeEx | `function InlineCodeEx(const Value: string; FromCP: TMimeChar): string;` | Source explicito; target auto-escolhido. |

### 4.3 Email address

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| InlineEmail | `function InlineEmail(const Value: string): string;` | Encoda display name preservando `<local@dom>` literalmente. |
| InlineEmailEx | `function InlineEmailEx(const Value: string; FromCP: TMimeChar): string;` | Mesmo com charset source explicito. |

### 4.4 Predicado

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| NeedInline | `function NeedInline(const Value: AnsiString): boolean;` | `True` se `Value` contem bytes fora do ASCII imprimivel (0x20..0x7E) ou sequencias que requerem encoding. |

## 5. Aplicabilidades

1. **Encoding de Subject com acentos** -- aplicacao passa string unicode, recebe RFC-2047 pronto.
2. **Decodificacao de From: "Joao" <j@x>** -- extrair display-name encoded-word, manter email literal.
3. **Mailing lists** -- encoding de nomes de subscribers com acentos antes de enviar MAIL FROM.
4. **Header logging** -- decodificar encoded-words em logs para legibilidade humana.
5. **Compatibilidade com clientes antigos** -- gerar Q-encoding em vez de B-encoding para maior legibilidade em transito.

## 6. Exemplos de uso

### 6.1 Decodificar subject

```pascal
uses
  SysUtils, synachar, mimeinln;

var
  LDecoded: string;
begin
  // Header cru: "Subject: =?UTF-8?B?TcOjZW3Dpw==?="
  LDecoded := InlineDecode('=?UTF-8?B?TcOjZW3Dpw==?=', GetCurCP);
  Writeln(LDecoded); // -> "Mãemç"
end.
```

### 6.2 Encodar string com acentos (auto-select charset)

```pascal
uses
  SysUtils, mimeinln;

var
  LEncoded: string;
begin
  LEncoded := InlineCode('Relatório de Março');
  Writeln(LEncoded);
  // -> "=?UTF-8?B?UmVsYXTDs3JpbyBkZSBNYXLDp28=?=" (aproximado)
end.
```

### 6.3 Encodar display-name em endereco de email

```pascal
uses
  SysUtils, mimeinln;

var
  LAddr: string;
begin
  LAddr := InlineEmail('João Silva <joao@example.com>');
  Writeln(LAddr);
  // -> '=?UTF-8?B?Sm/Do28gU2lsdmE=?= <joao@example.com>'
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `synachar` | Dependencia | Tabelas de conversao de charsets. |
| `synacode` | Dependencia | Base64 e quoted-printable encoders. |
| `synautil` | Dependencia | Helpers de string e byte arrays. |
| `TMessHeader` (mimemess) | Consumidor | Usa em Subject, From, To, Reply-To. |
| `TMimePart` (mimepart) | Consumidor | Usa em filename de anexos com acentos. |
