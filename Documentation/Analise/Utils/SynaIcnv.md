# SynaIcnv

**Unit:** `synaicnv.pas` | **Versao:** 001.001.003 | **Tipo:** Unit | **Origem:** Upstream

---

## 1. O que e?

A `synaicnv` e o binding Pascal para a biblioteca C `libiconv` (GNU iconv), consumido internamente por `synachar` para converter charsets asiaticos (Shift-JIS, GB2312, Big5, EUC-JP/KR/TW, UTF-16/32 etc.) que nao tem tabelas internas no Synapse. A carga da biblioteca e **dinamica e on-demand**: se `libiconv.so` / `iconv.dll` nao estiver presente no sistema, as funcoes retornam imediatamente com codigo de erro, permitindo que a aplicacao degrade graciosamente para tabelas internas. A unit expoe tres aberturas (`SynaIconvOpen` normal, `SynaIconvOpenTranslit` com `//TRANSLIT`, `SynaIconvOpenIgnore` com `//IGNORE`), controlo de conversao (`SynaIconvCtl`), e lifecycle helpers (`IsIconvLoaded`, `InitIconvInterface`, `DestroyIconvInterface`).

## 2. Caracteristicas

- Nome do ficheiro DLL/SO:
  - Windows: `iconv.dll`.
  - OS/2: `iconv.dll`.
  - Unix/POSIX: `libiconv.so`.
- Thread-safe: usa `TCriticalSection` (`IconvCS`) para proteger `InitIconvInterface` / `DestroyIconvInterface`.
- Load-on-demand: `InitIconvInterface` so carrega DLL na primeira chamada util.
- Four function pointers carregados dinamicamente: `libiconv_open`, `libiconv`, `libiconv_close`, `libiconvctl`.
- Suporta `CIL` (Delphi.NET) via `DllImport` explicito sobre `DLLIconvName`.
- Variavel global `iconvLibHandle: TLibHandle` (default 0) serve como flag "loaded?".
- `//IGNORE//TRANSLIT` e `//IGNORE` sao sufixos entendidos pelo proprio libiconv: o primeiro tenta transliterar unicode para ASCII quando nao representavel; o segundo ignora silenciosamente.

## 3. Engine

- `LoadLibrary(DLLIconvName)` (via `synafpc`) + 4x `GetProcAddress` para popular os function pointers.
- `SynaIconvOpen` chama `_iconv_open(tocode, fromcode)` -> handle `iconv_t`.
- `SynaIconv` chama `_iconv(cd, inbuf, inbytesleft, outbuf, outbytesleft)` — formato padrao GNU libiconv:
  - `size_t _iconv(iconv_t cd, char** in, size_t* inleft, char** out, size_t* outleft)`
  - Retorno: numero de caracteres irreversivelmente convertidos.
- Buffer de saida sempre 4x tamanho de input (defensivo).
- `SynaIconvClose` chama `_iconv_close(cd)` e zera `cd`.

## 4. Funcionalidades

### 4.1 Tipos

| Nome | Definicao | Observacao |
| --- | --- | --- |
| `size_t` | `NativeUInt` (FPC) / `Cardinal` (Delphi) | Tamanho do buffer (64-bit em FPC/Delphi 64). |
| `iconv_t` | `Pointer` / `IntPtr` (CIL) | Handle de conversao opaco. |
| `argptr` | `iconv_t` (alias) | Para iconvctl. |

### 4.2 Abertura / fecho

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SynaIconvOpen` | `function SynaIconvOpen(const tocode, fromcode: AnsiString): iconv_t;` | Abre handle `fromcode -> tocode`. Retorna `iconv_t(-1)` se libiconv nao disponivel. |
| `SynaIconvOpenTranslit` | `function SynaIconvOpenTranslit(const tocode, fromcode: AnsiString): iconv_t;` | Idem + `//IGNORE//TRANSLIT` (transliterate). |
| `SynaIconvOpenIgnore` | `function SynaIconvOpenIgnore(const tocode, fromcode: AnsiString): iconv_t;` | Idem + `//IGNORE` (skip silently). |
| `SynaIconvClose` | `function SynaIconvClose(var cd: iconv_t): integer;` | Fecha handle e seta `cd := iconv_t(-1)`. |

### 4.3 Conversao

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SynaIconv` | `function SynaIconv(cd: iconv_t; inbuf: AnsiString; var outbuf: AnsiString): integer;` | Converte `inbuf` -> `outbuf`. Retorna numero de caracteres **irreversivelmente** convertidos. |
| `SynaIconvCtl` | `function SynaIconvCtl(cd: iconv_t; request: integer; argument: argptr): integer;` | Controlo (iconvctl) para flags `ICONV_TRIVIALP`, transliteracao, discard-ilseq. |

### 4.4 Lifecycle

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `IsIconvloaded` | `function IsIconvloaded: Boolean;` | True se DLL carregada com sucesso. |
| `InitIconvInterface` | `function InitIconvInterface: Boolean;` | Carga on-demand (chamada internamente por todas as funcoes). |
| `DestroyIconvInterface` | `function DestroyIconvInterface: Boolean;` | Descarga manual (chamada em `finalization`). |

### 4.5 Constantes iconvctl

| Nome | Valor | Uso |
| --- | --- | --- |
| `ICONV_TRIVIALP` | `0` | `int*` (query) — conversao trivial? |
| `ICONV_GET_TRANSLITERATE` | `1` | `int*` (query). |
| `ICONV_SET_TRANSLITERATE` | `2` | `const int*` (set). |
| `ICONV_GET_DISCARD_ILSEQ` | `3` | `int*` (query). |
| `ICONV_SET_DISCARD_ILSEQ` | `4` | `const int*` (set). |

## 5. Aplicabilidades

- **Conversao de charsets asiaticos (via `synachar`):** qualquer `CharsetConversion(x, y, Shift_JIS)` acaba aqui.
- **Standalone:** aplicacoes podem usar directamente `synaicnv` para converter ficheiros entre charsets sem passar por `synachar`.
- **Fallback gracioso:** apps podem testar `IsIconvloaded` e usar `synachar` tabelas internas quando indisponivel.
- **AD/LDAP:** raramente necessario — o ADORM trata quase tudo em UTF-8 puro (RTL `Utf8Encode`/`Utf8Decode`). libiconv seria util apenas para sistemas legacy com charset de aplicacao em CP932/Shift_JIS.
- **Tranformacao ad-hoc:** converter ficheiros `.csv` importados de ERP legacy Windows-1252 para UTF-8 sem ActiveX.

## 6. Exemplos de uso

```pascal
uses
  SysUtils, synaicnv;
var
  cd: iconv_t;
  input, output: AnsiString;
begin
  // Verificar se libiconv esta disponivel
  if not InitIconvInterface then
  begin
    Writeln('libiconv nao instalada; fallback para tabelas internas');
    Exit;
  end;

  // Converter de Shift_JIS para UTF-8
  cd := SynaIconvOpen('UTF-8', 'SHIFT_JIS');
  if cd = iconv_t(-1) then
  begin
    Writeln('Conversao nao suportada');
    Exit;
  end;
  try
    input := #$82#$B1#$82#$F1#$82#$C9#$82#$BF#$82#$CD;  // "konnichiwa" em Shift_JIS
    SynaIconv(cd, input, output);
    Writeln('UTF-8 output length = ', Length(output));
  finally
    SynaIconvClose(cd);
  end;
end;
```

```pascal
uses
  SysUtils, synaicnv;
var
  cd: iconv_t;
  inp, out_: AnsiString;
begin
  // Transliteracao (japones -> latin com aproximacao ASCII)
  cd := SynaIconvOpenTranslit('ASCII', 'UTF-8');
  if cd <> iconv_t(-1) then
  try
    inp := 'Tóquio';  // UTF-8
    SynaIconv(cd, inp, out_);
    Writeln('Translit: ', out_);   // 'Toquio' ou similar (depende do libiconv)
  finally
    SynaIconvClose(cd);
  end;
end;
```

```pascal
uses
  SysUtils, synaicnv;
var
  cd: iconv_t;
  flag: integer;
begin
  // Interrogar se a conversao e trivial (mesmo charset)
  cd := SynaIconvOpen('UTF-8', 'UTF-8');
  if cd <> iconv_t(-1) then
  try
    flag := 0;
    SynaIconvCtl(cd, ICONV_TRIVIALP, @flag);
    Writeln('Trivial conversion = ', flag);
  finally
    SynaIconvClose(cd);
  end;
end;
```

## 7. Relacionamentos

- **Consumida por:** `synachar.pas` (motor externo quando charset esta em `IconvOnlyChars`).
- **Depende de:** `synafpc`, `SysUtils`, `SyncObjs` (CriticalSection), `Windows` (MSWINDOWS) ou `Libc`/`Posix.Base`.
- **Biblioteca externa:**
  - Windows: `iconv.dll` (GnuWin32).
  - Linux: `libiconv.so` (geralmente empacotada na glibc do sistema ou via libiconv-dev).
  - macOS: `libiconv.dylib` (normalmente pre-instalada).
  - OS/2: `iconv.dll`.
- **Lifecycle global:** `initialization` cria `IconvCS`; `finalization` chama `DestroyIconvInterface` + `IconvCS.Free`.
- **Fork CSL:** sem modificacoes.
