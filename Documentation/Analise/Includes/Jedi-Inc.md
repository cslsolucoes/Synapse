# jedi.inc

**Ficheiro:** `jedi.inc` | **Versao:** (reescrita CSL, ~2240 linhas) | **Tipo:** Include file | **Origem:** Project JEDI (reescrito CSL fork 13/04/2026)

---

## 1. O que e?

`jedi.inc` e o include file canonico de **compiler defines** adoptado pela comunidade Delphi/FPC atraves do Project JEDI (<https://github.com/project-jedi/jedi>). A sua funcao e normalizar dezenas de directivas condicionais que permitem escrever codigo cross-compiler (Delphi 7 ate 12, FPC 2.x a 3.3.x) sem conhecer os detalhes de cada versao.

No fork CSL, o `jedi.inc` foi **completamente reescrito** (13/04/2026) -- ~2240 linhas -- para consolidar suporte actualizado as versoes Delphi 11/12 (Alexandria/Athens) e FPC 3.3.1+, remover directivas obsoletas (Kylix, Delphi .NET) e alinhar defines com as versoes OpenSSL 3.x e 4.0.

Serve como o **primeiro include** de praticamente todas as units Synapse via `{$I jedi.inc}` logo apos `interface`.

---

## 2. Caracteristicas

- **Detecao automatica de compilador e versao** -- define `DELPHI`, `FPC`, `COMPILER12` (Delphi 12), `FPC_VERSION_3_3` via `{$IF DECLARED(...)}`.
- **Suporte a 30+ versoes Delphi** (desde Delphi 2 ate Delphi 12).
- **Suporte a FPC 2.x a 3.3.x** -- inclui `FPC_HAS_ANSICHAR`, `FPC_HAS_FEATURE_CLASS`, etc.
- **Defines SO** -- `MSWINDOWS`, `LINUX`, `MACOS`, `DARWIN`, `UNIX`, `BSD`, `POSIX`.
- **Defines de arquitectura** -- `CPU386`, `CPUX64`, `CPUARM`, `CPUARM64`.
- **Directivas de RTTI e sintaxe** -- `SUPPORTS_GENERICS`, `SUPPORTS_ANONYMOUS_METHODS`, `SUPPORTS_DEPRECATED`, `SUPPORTS_INLINE`, `SUPPORTS_STATIC`, `UNICODE`.
- **Normalizacao de warnings** -- desliga avisos redundantes como `IMPLICIT_STRING_CAST`, `IMPLICIT_STRING_CAST_LOSS`.
- **Licenca** -- MPL 1.1 (Mozilla Public License) -- compativel com BSD do Synapse.

---

## 3. Engine

| Directiva | Efeito |
|---|---|
| `{$I jedi.inc}` | Include explicito a partir de cada unit `.pas` do package |
| `{$IFDEF FPC}` | Ramo FPC (activa `{$MODE DELPHI}`, define `FPC` + versao) |
| `{$IFDEF DELPHI}` | Ramo Delphi (define `COMPILER<N>` conforme `CompilerVersion`) |
| `{$IFDEF UNICODE}` | Delphi 2009+ e FPC 3.x+ com `String = UnicodeString` |
| `{$IFDEF SUPPORTS_GENERICS}` | Delphi 2009+ e FPC 2.6+ com `<T>` |
| `{$IFDEF SUPPORTS_DEPRECATED}` | Delphi 6+ e FPC 2.x+ com `deprecated` |

Sem DLLs -- e puramente metadata de compilacao.

---

## 4. Funcionalidades

### 4.1 Defines de compilador

| Define | Condicao |
|---|---|
| `FPC` | Free Pascal Compiler activo |
| `DELPHI` | Delphi (qualquer versao) |
| `COMPILER<N>` | `CompilerVersion` Delphi (ex.: `COMPILER28` = Alexandria, `COMPILER34` = Athens = Delphi 12) |
| `BORLAND` | Delphi ou C++Builder (alias compat) |
| `DELPHIXE` / `DELPHIXE2` / ... / `DELPHI12` | Delphi XE ate 12 (nomeado) |

### 4.2 Defines de versao FPC

| Define | Condicao |
|---|---|
| `FPC_VERSION_2` | FPC 2.x |
| `FPC_VERSION_3` | FPC 3.x |
| `FPC_VERSION_3_2` | FPC 3.2.x |
| `FPC_VERSION_3_3` | FPC 3.3.x (trunk) |

### 4.3 Defines de sistema operativo

| Define | Condicao |
|---|---|
| `MSWINDOWS` | Windows (qualquer arch) |
| `WIN32` / `WIN64` | Windows 32-bit / 64-bit |
| `LINUX` | Linux |
| `DARWIN` | macOS |
| `MACOS` / `MACOSX` | macOS (alias) |
| `BSD` | FreeBSD / OpenBSD / NetBSD |
| `UNIX` | Unix-like (Linux + BSD + macOS) |
| `POSIX` | Delphi POSIX (LINUX64, MACOS64) |
| `ANDROID` | Android |
| `IOS` | iOS |

### 4.4 Defines de arquitectura

| Define | Condicao |
|---|---|
| `CPU386` / `CPUX86` | x86 32-bit |
| `CPUX64` / `CPUX86_64` | x86-64 |
| `CPUARM` | ARM 32-bit |
| `CPUARM64` / `CPUAARCH64` | ARM 64-bit (Apple Silicon, Raspberry Pi 64) |

### 4.5 Defines de capacidades de linguagem

| Define | Significado |
|---|---|
| `UNICODE` | `String = UnicodeString` (Delphi 2009+ / FPC 3.x+) |
| `SUPPORTS_GENERICS` | `TList<T>`, `TDictionary<K,V>` |
| `SUPPORTS_ANONYMOUS_METHODS` | `procedure(x: T)` anon methods (Delphi 2009+; FPC nao suporta antes de 3.3.1 via `procedure`) |
| `SUPPORTS_DEPRECATED` | `deprecated 'msg'` attribute |
| `SUPPORTS_INLINE` | `inline` attribute |
| `SUPPORTS_STATIC` | `class var`, `class function` |
| `SUPPORTS_CLASS_CONSTRUCTORS` | `class constructor/destructor` |
| `SUPPORTS_UNICODE_STRING` | Tipo `UnicodeString` disponivel |
| `SUPPORTS_NESTED_CONSTANTS` | `const` dentro de metodos |

### 4.6 Directivas de warning

Bloco de `{$WARN ... OFF}` para suprimir avisos irrelevantes:

| Warning | Motivo |
|---|---|
| `IMPLICIT_STRING_CAST` | Cast implicito `AnsiString <-> string` (trivial em I/O binario) |
| `IMPLICIT_STRING_CAST_LOSS` | Cast com possivel perda (intencional no Synapse) |
| `EXPLICIT_STRING_CAST` | Cast explicito redundante |
| `SYMBOL_PLATFORM` | Tipo Windows-only sendo usado |
| `UNIT_PLATFORM` | Unit Windows-only |
| `GARBAGE` | Caracteres fora do codigo |
| `UNSAFE_TYPE` | `AnsiString` em Unicode Delphi |

---

## 5. Aplicabilidades

1. **Compilacao cross-compiler** -- uma unica base de codigo `.pas` compila em Delphi 12 (Win32/Win64) e FPC 3.3.1+ (Linux x86_64/ARM64, macOS Intel/Apple Silicon).
2. **Compilacao cross-OS** -- atraves dos defines `MSWINDOWS`/`UNIX`/`POSIX`, units como `ldapsend` tem ramos separados por SO.
3. **Evolucao de linguagem** -- codigo escrito hoje pode usar `SUPPORTS_GENERICS` sem quebrar compilacao em Delphi 7 (ramo else fornece implementacao classica).
4. **Supressao de warnings conhecidos** -- evita ruido no build log sem mascarar warnings reais.
5. **Interoperabilidade com ICS** -- ICS (`OverbyteIcsDefs.inc`) segue padrao similar; CSL alinha definicoes para facilitar portes de codigo entre os dois.

---

## 6. Exemplos de uso

### 6.1 Include canonico no topo de uma unit

```pascal
unit MinhaUnit;

{$I jedi.inc}

interface

uses
  SysUtils, Classes
  {$IFDEF MSWINDOWS}, Windows{$ENDIF}
  {$IFDEF UNIX}, BaseUnix{$ENDIF};

implementation

{$IFDEF SUPPORTS_GENERICS}
procedure DoStuff<T>(const AItem: T);
begin
  // Codigo moderno com generics
end;
{$ELSE}
procedure DoStuff(const AItem: TObject);
begin
  // Fallback classico pre-generics
end;
{$ENDIF}

end.
```

### 6.2 Directivas compostas

```pascal
{$I jedi.inc}

{$IF DEFINED(DELPHI) AND DEFINED(COMPILER28_UP)}
  // Delphi 10.2 Tokyo ou superior
  {$WEAKLINKRTTI ON}
{$IFEND}

{$IF DEFINED(FPC) AND DEFINED(FPC_VERSION_3_3)}
  // FPC 3.3.x trunk -- usar macros recentes
  {$DEFINE HAS_INLINE_ASSEMBLER_X64}
{$IFEND}
```

### 6.3 Guards de plataforma em ldapsend.pas (V1.7.0)

```pascal
{$I jedi.inc}

{$IFDEF MSWINDOWS}
function TLDAPSend.BindGSSAPI(const ASPN: AnsiString): Boolean;
begin
  // Impl real via secur32.dll / SSPI
  Result := BindGSSAPIWithCBT(ASPN, '');
end;
{$ELSE}
function TLDAPSend.BindGSSAPI(const ASPN: AnsiString): Boolean;
begin
  Result := False;
  FResultString := 'GSSAPI via SSPI nao disponivel em POSIX -- use Kerberos via libgssapi_krb5 (agendado V2.0.0)';
end;
{$ENDIF}
```

---

## 7. Relacionamentos

| Ficheiro / Unit | Tipo de relacao | Descricao |
|---|---|---|
| `ssl_openssl.pas` | Include | `{$I jedi.inc}` no topo |
| `ssl_openssl3.pas` | Include | idem |
| `ssl_openssl4.pas` | Include | idem (CSL fork) |
| `ssl_openssl_paths.pas` | Include | idem (CSL fork) |
| `ldapsend.pas` | Usa directivas | Usa `{$IFDEF FPC}`, `{$IFDEF MSWINDOWS}` (V1.7.0) |
| `blcksock.pas` | Usa directivas | idem + `{$IFDEF POSIX}` para Delphi LINUX/macOS |
| `kylix.inc` | Relacao historica | Defines Kylix (Delphi Linux legacy; raramente usado) |
| Project JEDI | Upstream | <https://github.com/project-jedi/jedi> -- base original antes do fork CSL |
| ICS (`OverbyteIcsDefs.inc`) | Contrapartida | ICS tem padrao similar mas nao cross-fork |

---

**Gerado:** 2026-04-21 (CSL reverse-engineering V2)
