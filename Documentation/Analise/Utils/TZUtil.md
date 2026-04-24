# TZUtil

**Unit:** `tzutil.pas` | **Versao:** (sem tag explicita; parte do pacote Synapse) | **Tipo:** Unit | **Origem:** Upstream (contrib Tomas Hajny)

---

## 1. O que e?

A `tzutil` e uma unit de suporte de timezone especificamente escrita para plataformas FreePascal onde o RTL nao fornece informacao DST madura — classicamente OS/2, DOS e algumas variantes POSIX antigas. Parsa a variavel de ambiente `TZ` (ou `EMXTZ` em OS/2 EMX) segundo a sintaxe POSIX/GNU (`NameOffsetDSTName[Dstoffset],Start[/StartHour],End[/EndHour]`), suporta quatro tipos de especificacao de DST transition (`DSTMonthWeekDay`, `DSTMonthDay`, `DSTJulian`, `DSTJulianX`), e expoe uma funcao unica — `TZSeconds` — que retorna o offset UTC corrente em segundos, respeitando DST baseado na data/hora actual. No Synapse, a unit e consumida exclusivamente por `synautil` em ramo `{$IFDEF OS2}` para calcular `TimeZoneBias` em OS/2.

## 2. Caracteristicas

- Zero dependencias externas: usa apenas `Dos` (FPC RTL OS/2/DOS).
- Parsing inteiramente manual da string `TZ` — nao delega ao RTL.
- Suporta tres formatos de data de transicao:
  - `Mmonth.week.dayofweek` (3a Sunday de Marco = `M3.2.0`).
  - `Jjulianday` (dia do ano Juliano, excluindo 29 Fev).
  - `julianday` (dia 0-based, 0-365).
- Defaults: timezone UTC+4 start DST, DST end em Outubro.
- Consta `DSTSpecType` com 4 variantes: `DSTMonthWeekDay`, `DSTMonthDay`, `DSTJulian`, `DSTJulianX`.
- E inicializada no bloco `begin..end.` principal da unit (chama `InitTZ` que le `TZ` do ambiente).

## 3. Engine

- `GetEnv('TZ')` ou `GetEnv('EMXTZ')` — le variavel de ambiente.
- `GetDate(Y, Mo, D, WD)` + `GetTime(H, Mi, S, S100)` da unit `Dos` — obtem data/hora local corrente.
- Algoritmo:
  1. Parse name + offset + DST name + DST offset.
  2. Parse DST start (M|J|number) e DST end.
  3. Determina se "agora" esta entre DST start e DST end.
  4. Retorna `DSTOffset` se sim, senao `TZOffset`.
- Tratamento de leap year: `LeapDay` helper interno retorna 0 ou 1 conforme `Y mod 400 = 0 or (Y mod 100 <> 0 and Y mod 4 = 0)`.

## 4. Funcionalidades

### 4.1 Funcao publica

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `TZSeconds` | `function TZSeconds: longint;` | Offset corrente em segundos face UTC, considerando DST ligado na data/hora actual do SO. Usa todas as variaveis globais `TZOffset`/`DSTOffset`/DST start/end declaradas. |

### 4.2 Tipo enumerado publico

| Nome | Definicao |
| --- | --- |
| `DSTSpecType` | `(DSTMonthWeekDay, DSTMonthDay, DSTJulian, DSTJulianX)` |

### 4.3 Variaveis globais publicas (inicializadas por `InitTZ`)

| Nome | Tipo | Default | Descricao |
| --- | --- | --- | --- |
| `TZName` | `string` | `''` | Nome do timezone standard (`CET`, `EST`, etc.). |
| `TZDSTName` | `string` | `''` | Nome do timezone DST (`CEST`, `EDT`, etc.). |
| `TZOffset` | `longint` | `0` | Offset standard (segundos). |
| `DSTOffset` | `longint` | `0` | Offset DST (segundos). |
| `DSTStartMonth` | `byte` | `4` | Abril. |
| `DSTStartWeek` | `shortint` | `1` | Primeira semana. |
| `DSTStartDay` | `word` | `0` | Domingo. |
| `DSTStartSec` | `cardinal` | `7200` | 02:00. |
| `DSTEndMonth` | `byte` | `10` | Outubro. |
| `DSTEndWeek` | `shortint` | `-1` | Ultima semana. |
| `DSTEndDay` | `word` | `0` | Domingo. |
| `DSTEndSec` | `cardinal` | `10800` | 03:00. |
| `DSTStartSpecType` | `DSTSpecType` | `DSTMonthWeekDay` | Tipo de specificacao. |
| `DSTEndSpecType` | `DSTSpecType` | `DSTMonthWeekDay` | Tipo de specificacao. |

### 4.4 Procedimento privado

| Nome | Assinatura | Descricao |
| --- | --- | --- |
| `InitTZ` | `procedure InitTZ;` (apenas no `implementation`) | Executado no `initialization` da unit; le `TZ` env var e popula globals. |
| `ParseOffset` | `function ParseOffset(OffStr: string): longint;` (nested) | Parsing de `[-|+]HH[:MI[:SS]]`. |
| `FirstDay` | `function FirstDay(MM: byte): byte;` (nested em `TZSeconds`) | Calcula dia-da-semana (0..6) do primeiro dia do mes. |
| `LeapDay` | `function LeapDay: byte;` (nested) | 0 ou 1. |

## 5. Aplicabilidades

- **OS/2 / DOS / POSIX legacy (FPC):** unico caminho para DST-aware time arithmetic — usado em ramo `{$IFDEF OS2}` de `synautil.TimeZoneBias`.
- **Consola tools:** scripts FPC que precisam imprimir timestamps UTC num sistema sem `tzdata` completo.
- **AD / LDAP em Linux/OS2:** teoricamente podia ser usada para converter valores FileTime AD (UTC) para local time, mas o ADORM prefere `TimeZoneBias` do `synautil` em Windows (com `TTimeZoneInformation` nativo).
- **Nao aplicavel em Windows/Delphi:** em Windows, `GetTimeZoneInformation` e nativo e muito mais fiel (usa a TZ database do registry).

## 6. Exemplos de uso

```pascal
uses
  SysUtils, tzutil;
var
  offset: longint;
begin
  // Chamado tipicamente assim: offset em segundos face UTC, ja com DST
  offset := TZSeconds;
  Writeln(Format('TZ=%s DST=%s offset=%d seg (%d min)',
    [TZName, TZDSTName, offset, offset div 60]));

  // Exemplo: Export TZ=CET-1CEST,M3.5.0,M10.5.0/3 antes de executar
  // Saida: TZ=CET DST=CEST offset=7200 seg (120 min)  (em verao)
end.
```

```pascal
uses
  SysUtils, tzutil;
begin
  // Verificar info de DST configurada
  Writeln('TZName      = ', TZName);
  Writeln('TZOffset    = ', TZOffset, ' segundos');
  Writeln('DSTName     = ', TZDSTName);
  Writeln('DSTOffset   = ', DSTOffset, ' segundos');
  Writeln(Format('Start DST   = mes %d, semana %d, dia %d, hora %d',
    [DSTStartMonth, DSTStartWeek, DSTStartDay, DSTStartSec div 3600]));
  Writeln(Format('End DST     = mes %d, semana %d, dia %d, hora %d',
    [DSTEndMonth, DSTEndWeek, DSTEndDay, DSTEndSec div 3600]));
end.
```

```pascal
uses
  SysUtils, tzutil, synautil;
var
  nowUtc: TDateTime;
  nowLocal: TDateTime;
  offsetDays: double;
begin
  // Converter now() local para UTC usando TZSeconds
  nowLocal := Now;
  offsetDays := TZSeconds / 86400.0;
  nowUtc := nowLocal - offsetDays;

  Writeln(Format('Local : %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', nowLocal)]));
  Writeln(Format('UTC   : %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', nowUtc)]));
end.
```

## 7. Relacionamentos

- **Consumida por:** `synautil.pas` em ramo `{$IFDEF OS2}` (`TimeZoneBias := TZSeconds div 60`).
- **Depende de:** `Dos` (RTL FPC OS/2/DOS).
- **Nao usada em:** Delphi Windows (tem `GetTimeZoneInformation` nativo), FPC Unix moderno (`UnixUtil`), FPC Linux com `tzdata` completo.
- **Fork CSL:** sem modificacoes. Autor original Tomas Hajny (contrib FPC OS/2).
- **Envvar esperada:** `TZ` ou `EMXTZ`. Sem envvar, retorna 0 + defaults CET/CEST.
