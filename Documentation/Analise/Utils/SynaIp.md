# SynaIp

**Unit:** `synaip.pas` | **Versao:** 001.002.002 | **Tipo:** Unit | **Origem:** Upstream + CSL fork

---

## 1. O que e?

A `synaip` e a unit de validacao e conversao de enderecos IP do pacote Ararat Synapse. Suporta IPv4 (quatro octetos `xxx.xxx.xxx.xxx`) e IPv6 (oito grupos hexadecimais com compressao `::`, zona `%interface`). Fornece tres funcionalidades principais: (1) validacao sintactica (`IsIP`, `IsIP6`), (2) conversao bi-direccional string <-> representacao binaria (4 bytes para IPv4, 16 bytes para IPv6), e (3) reverse DNS (gera nome `3.2.1.x.in-addr.arpa` para IPv4 e sequencia nibble-inversa para IPv6 `.ip6.arpa`). O fork CSL introduziu ajustes minimos (~4 linhas) para compatibilidade Delphi 12. E usada indirectamente em `ldapsend` atraves de `blcksock` durante a resolucao de `Host` para o DC.

## 2. Caracteristicas

- Cross-compiler puro: so depende de `SysUtils` e `SynaUtil`.
- Nao usa resolvedor DNS; e apenas parser sintactico/binario.
- IPv6 long-form e short-form: `ExpandIP6('::1')` retorna `0:0:0:0:0:0:0:1`.
- Suporta formato scope-id IPv6 (`fe80::1%eth0`): quando presente, aceita validacao mas mantem zona separada.
- Todas as funcoes sao stateless e sem alocacao excessiva.
- Reverse DNS util para construir queries `PTR` em `in-addr.arpa` (IPv4) e `ip6.arpa` (IPv6).

## 3. Engine

Engine puramente Pascal:

- IPv4: split por `.` via `Fetch` (de `synautil`), `StrToIntDef` para validar cada octeto [0..255].
- IPv6: split por `:` com tracking de `zerocount` (so 1 `::` permitido) e `partcount` (max 8).
- `StrToIntDef('$' + s, -1)` para hex parse 16-bit por grupo.
- `TIp6Bytes: array[0..15] of Byte` / `TIp6Words: array[0..7] of Word` — representacoes binarias.
- Algoritmo `Ip6ToStr` baseado na implementacao oficial FPC: procura a run mais longa de zeros e colapsa com `::`.

## 4. Funcionalidades

### 4.1 Validacao

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `IsIP` | `function IsIP(const Value: string): Boolean;` | True se valida IPv4 (4 octetos 0..255, so digitos). |
| `IsIP6` | `function IsIP6(const Value: string): Boolean;` | True se valida IPv6 (8 grupos hex, no max um `::`, opcional `%zone`). |

### 4.2 Conversao IPv4

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `IPToID` | `function IPToID(Host: string): Ansistring;` | `"192.168.1.1"` -> 4 chars binarios `#$C0#$A8#$01#$01`. |
| `StrToIp` | `function StrToIp(value: string): integer;` | IPv4 -> integer 32-bit big-endian. |
| `IpToStr` | `function IpToStr(value: integer): string;` | Inverso. |
| `ReverseIP` | `function ReverseIP(Value: AnsiString): AnsiString;` | `"192.168.1.1"` -> `"1.1.168.192"`. |

### 4.3 Conversao IPv6

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `StrToIp6` | `function StrToIp6(value: string): TIp6Bytes;` | IPv6 -> 16 bytes. |
| `Ip6ToStr` | `function Ip6ToStr(value: TIp6Bytes): string;` | 16 bytes -> string comprimida (`::`). |
| `ExpandIP6` | `function ExpandIP6(Value: AnsiString): AnsiString;` | `"fe80::1"` -> `"fe80:0:0:0:0:0:0:1"`. |
| `ReverseIP6` | `function ReverseIP6(Value: AnsiString): AnsiString;` | 32 nibbles em ordem inversa (para `.ip6.arpa`). |

### 4.4 Tipos publicos

| Nome | Definicao | Uso |
| --- | --- | --- |
| `TIp6Bytes` | `array[0..15] of Byte` | IPv6 binario. |
| `TIp6Words` | `array[0..7] of Word` | IPv6 em grupos de 16 bits. |

## 5. Aplicabilidades

- **Validacao de input:** aceitar `Host` como IPv4/IPv6 literal (distingue de FQDN).
- **DNS reverso:** montar PTR record para queries `dnssend`.
- **IP blacklist / whitelist:** comparar bytes binarios em vez de string.
- **IPv6 canonicalizacao:** normalizar representacao antes de comparar (`0:0::1` vs `::1`).
- **Logging LDAP/AD:** guardar IP do DC em formato compact binario.
- **Reverse lookup:** construcao de query `1.1.168.192.in-addr.arpa` para PTR.

## 6. Exemplos de uso

```pascal
uses
  SysUtils, synaip;
var
  ip: integer;
  s: string;
begin
  // Validar e converter IPv4
  if IsIP('192.168.100.5') then
  begin
    ip := StrToIp('192.168.100.5');
    Writeln('Binario int32 = ', IntToHex(ip, 8));  // C0A86405
    s := IpToStr(ip);
    Writeln('Round-trip = ', s);
  end;

  // IPv4 -> reverso para PTR
  Writeln('Reverse = ', ReverseIP('192.168.100.5'));
  // Saida: 5.100.168.192
end;
```

```pascal
uses
  SysUtils, synaip;
var
  bytes: TIp6Bytes;
  expanded, canonical: string;
begin
  // IPv6 expandido vs compacto
  expanded := ExpandIP6('fe80::1');
  Writeln('Expanded: ', expanded);  // fe80:0:0:0:0:0:0:1

  bytes := StrToIp6('2001:0db8::ff00:0042:8329');
  canonical := Ip6ToStr(bytes);
  Writeln('Canonical: ', canonical);  // 2001:db8::ff00:42:8329
end;
```

```pascal
uses
  SysUtils, synaip;
var
  bin: AnsiString;
begin
  // IPToID: util para encoding em pacote binario (ex. SNMP, DNS)
  bin := IPToID('10.0.0.1');
  Writeln('Len=', Length(bin));        // 4
  Writeln(Format('Bytes=%.2x%.2x%.2x%.2x',
    [Ord(bin[1]), Ord(bin[2]), Ord(bin[3]), Ord(bin[4])]));
  // 0A000001

  // IPv6 reverse para ip6.arpa
  Writeln(ReverseIP6('2001:db8::1'));
end;
```

## 7. Relacionamentos

- **Consumida por:** `blcksock.pas` (resolucao IPv4/IPv6), `dnssend.pas` (reverse DNS PTR queries), `pingsend.pas`.
- **Depende de:** `SysUtils`, `synautil`.
- **Interage com:** nada externo — e self-contained.
- **Fork CSL:** ~4 linhas para Delphi 12; baseline em `bak/synaip.pas.bak`.
