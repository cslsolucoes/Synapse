# SynaFpc

**Unit:** `synafpc.pas` | **Versao:** 001.004.001 | **Tipo:** Unit | **Origem:** Upstream + CSL fork

---

## 1. O que e?

A `synafpc` e a shim/compat layer do pacote Ararat Synapse entre FreePascal (FPC) e Delphi (todas as versoes desde D3 ate D12 Alexandria). Unifica quatro dominios onde as duas toolchains divergem: (1) gestao dinamica de DLLs/SO (`LoadLibrary`, `FreeLibrary`, `GetProcAddress`, `GetModuleFileName`); (2) tipos primitivos cuja nomenclatura varia (`TLibHandle`, `PtrInt`, `LongWord`, `AnsiString`, `AnsiChar` em NEXTGEN/Android FMX); (3) funcoes RTL que mudaram de namespace entre versoes (`StrLCopy`, `StrLComp`, `Sleep`, `CharInSet`); (4) defines simbolicos para RAD (`HAS_CHARINSET`, `MSWINDOWS`). O fork CSL introduziu ~24 linhas de ajustes para compatibilidade Delphi 12 Alexandria (sem quebrar backward-compat com Delphi classicos).

## 2. Caracteristicas

- Zero-cost abstraction: funcoes inline que delegam para a RTL certa por `{$IFDEF}`.
- Sob FPC: usa `dynlibs` para SO/DLL; sob Delphi Win: usa `Windows.pas`.
- Sob Delphi XE4+ Non-NEXTGEN: usa `System.AnsiStrings` para `StrLCopy`/`StrLComp`.
- Sob NEXTGEN (Android FMX): redefine `AnsiString = RawByteString`, `AnsiChar = UTF8Char`, `PAnsiChar = PUTF8Char`, `WideString = String` — porque NEXTGEN removeu estes tipos.
- Sob OS2/GCC: prefixa `_` em `GetProcAddress` para compat com C-OMF linker.
- Bloco `{$IfDef DELPHI2009_UP} {$DEFINE HAS_CHARINSET}` ativa o uso de `CharInSet` built-in; para versoes mais antigas, define localmente.

## 3. Engine

Engine e puramente `{$IFDEF}` + delegacao:

- FPC: `dynlibs.LoadLibrary`, `dynlibs.UnloadLibrary`, `dynlibs.GetProcedureAddress`.
- Delphi Win: `Windows.LoadLibrary`, `Windows.FreeLibrary`, `Windows.GetProcAddress`.
- CIL (.NET interop): `TLibHandle = Integer`, `PtrInt = Integer`.
- Win64: `PtrInt = NativeInt`; Win32: `PtrInt = Integer`.
- NEXTGEN: redefine tipos Ansi para UTF-8 byte-strings.

## 4. Funcionalidades

### 4.1 Tipos cross-compiler

| Nome | FPC | Delphi Win | CIL | NEXTGEN |
| --- | --- | --- | --- | --- |
| `TLibHandle` | `dynlibs.TLibHandle` | `HModule` | `Integer` | `HModule` |
| `PtrInt` | (built-in) | `NativeInt` (Win64) / `Integer` (Win32) | `Integer` | `NativeInt` |
| `LongWord` | (built-in) | `DWord` em Delphi 3 | — | — |
| `AnsiString` | (built-in) | (built-in) | — | `RawByteString` |
| `AnsiChar` | (built-in) | (built-in) | — | `UTF8Char` |
| `PAnsiChar` | (built-in) | (built-in) | — | `PUTF8Char` |
| `WideString` | (built-in) | (built-in) | — | `String` |

### 4.2 Gestao de bibliotecas dinamicas (so FPC; em Delphi delega directamente a `Windows.pas`)

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LoadLibrary` | `function LoadLibrary(ModuleName: PChar): TLibHandle;` | Carrega DLL/SO. |
| `FreeLibrary` | `function FreeLibrary(Module: TLibHandle): LongBool;` | Descarga. |
| `GetProcAddress` | `function GetProcAddress(Module: TLibHandle; Proc: PChar): Pointer;` | Obtem endereco de simbolo. |
| `GetModuleFileName` | `function GetModuleFileName(Module: TLibHandle; Buffer: PChar; BufLen: Integer): Integer;` | Retorna 0 em FPC (nao implementado). |

### 4.3 Funcoes RTL cross-version

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `StrLCopy` | `function StrLCopy(Dest: PAnsiChar; const Source: PAnsiChar; MaxLen: Cardinal): PAnsiChar;` | Delega para `SysUtils.StrLCopy` (FPC), `System.AnsiStrings.StrLCopy` (DelphiXE4+), ou `SysUtils.StrLCopy` (Delphi classic). |
| `StrLComp` | `function StrLComp(const Str1, Str2: PAnsiChar; MaxLen: Cardinal): Integer;` | Analogo a StrLCopy. |
| `Sleep` | `procedure Sleep(milliseconds: Cardinal);` | FPC: `sysutils.sleep`. Delphi MSWINDOWS: `windows.sleep`. Delphi outros: `sysutils.sleep`. |
| `CharInSet` | `function CharInSet(C: AnsiChar; const CharSet: TSysCharSet): Boolean;` | So disponibilizada quando a RTL nao traz (Delphi < 2009). |

### 4.4 Defines simbolicos contribuidos

| Define | Quando ativa | Efeito |
| --- | --- | --- |
| `MSWINDOWS` | se `WIN32` mas ainda nao existe | Ativado em Delphi antigos para unificar ramos Windows. |
| `HAS_CHARINSET` | `DELPHI2009_UP` ou `FPC` | Indica que `CharInSet` existe na RTL. |
| `LEGACYIFEND` | `NEXTGEN` | `{$LEGACYIFEND ON}` para aceitar `{$IFEND}`. |
| `ZEROBASEDSTRINGS OFF` | `NEXTGEN` | Mantem strings indexadas a partir de 1. |

## 5. Aplicabilidades

- **Obrigatoria em toda unit Synapse:** `uses synafpc` aparece em `ldapsend`, `blcksock`, `synautil`, `synachar`, etc.
- **Carga dinamica de OpenSSL:** `ssl_openssl_lib`, `ssl_openssl3_lib`, `ssl_openssl4_lib` usam `synafpc.LoadLibrary` para carregar DLLs OpenSSL sem statically-linkar.
- **Carga de libiconv:** `synaicnv.InitIconvInterface` usa `synafpc.LoadLibrary` para `iconv.dll`/`libiconv.so`.
- **Delay/backoff:** `synafpc.Sleep` em retries de conexao TCP/LDAP.
- **NEXTGEN (Android FMX):** permite compilar `ldapsend` em mobile sem tocar na base de codigo.

## 6. Exemplos de uso

```pascal
uses
  SysUtils, synafpc;
var
  hLib: TLibHandle;
  pFunc: Pointer;
begin
  // Carregar libeay32.dll manualmente
  hLib := synafpc.LoadLibrary('libeay32.dll');
  if hLib <> 0 then
  try
    pFunc := synafpc.GetProcAddress(hLib, 'SSL_library_init');
    Writeln('Addr = ', IntToHex(PtrInt(pFunc), 2 * SizeOf(PtrInt)));
  finally
    synafpc.FreeLibrary(hLib);
  end;
end;
```

```pascal
uses
  SysUtils, synafpc;
var
  dest: array[0..31] of AnsiChar;
  src: AnsiString;
begin
  // StrLCopy cross-compiler (funciona Delphi classico, D12, FPC)
  src := 'AD WS 2025';
  synafpc.StrLCopy(@dest[0], PAnsiChar(src), SizeOf(dest) - 1);
  Writeln('Dest: ', AnsiString(dest));

  // Comparacao de prefixo
  if synafpc.StrLComp(PAnsiChar(AnsiString('LDAP://')), PAnsiChar(src), 7) = 0 then
    Writeln('comeca por LDAP://')
  else
    Writeln('nao comeca por LDAP://');
end;
```

```pascal
uses
  synafpc;
begin
  // Sleep cross-platform — mesmo codigo roda em FPC Linux, FPC Win, Delphi Win, etc.
  synafpc.Sleep(1000);   // espera 1 segundo
end;
```

## 7. Relacionamentos

- **Consumida por:** `synautil.pas`, `synacode.pas`, `synachar.pas`, `synaip.pas`, `synaicnv.pas`, `synacrypt.pas`, `synadbg.pas`, `blcksock.pas`, `ldapsend.pas`, `httpsend.pas`, `smtpsend.pas`, `ssl_openssl.pas`, `ssl_openssl3.pas`, `ssl_openssl4.pas`, `ssl_openssl_lib.pas`, `ssl_cryptlib.pas`, `mimepart.pas`, `mimemess.pas`. E a unit **mais baixa** do stack Synapse.
- **Depende de:** FPC: `dynlibs`, `SysUtils`. Delphi: `Windows` (MSWINDOWS), `System.AnsiStrings` (XE4+ Non-NEXTGEN), `SysUtils`.
- **Fork CSL:** ~24 linhas para Delphi 12 Alexandria (type aliases, ifdef adicional); preservado em `bak/synafpc.pas.bak`.
- **Consumido pelo CSL ldapsend SSPI/GSSAPI:** carga de `secur32.dll` via `LoadLibrary`.
