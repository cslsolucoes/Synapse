# TOpenSSLPaths / ssl_openssl_paths.pas

**Unit:** `ssl_openssl_paths.pas` | **Versao:** 001.000.000 | **Tipo:** Classe (class methods estaticos) | **Origem:** CSL fork (100% novo, 2026-04-21)

---

## 1. O que e?

`TOpenSSLPaths` e uma classe utilitaria do fork CSL do Synapse que resolve o path fisico das DLLs OpenSSL antes do loader do Windows as procurar. Usa `SetDllDirectory` (Win32 API) para forcar que `libssl-*.dll`/`libcrypto-*.dll` sejam carregadas de uma sub-pasta especifica do executavel (`dll\v1\win64\`, `dll\v3\win32\`, `dll\v4\win64\`), em vez de depender da ordem de busca padrao (pasta do `.exe` -> System32 -> PATH).

Isto resolve varios problemas operacionais do fork: colisao com `libssl-3.dll` instalado globalmente em `System32` que pode ser versao diferente da esperada; conflito com PostgreSQL, Apache, ou outro software que tambem carrega OpenSSL; distribuicao de binarios self-contained. Em POSIX (Linux/macOS) e no-op — dlopen respeita `LD_LIBRARY_PATH` ou path absoluto passado no proprio `LoadLibrary`; `SetDllDirectory` nao existe.

---

## 2. Caracteristicas

- **Windows-only efectivo:** so o Windows invoca `SetDllDirectory`; POSIX compila mas stub vazio.
- **Arquitectura segregada:** sub-pastas `dll\v<N>\win32\` vs `dll\v<N>\win64\` (via `$IFDEF WIN32/WIN64`).
- **3 versoes OpenSSL suportadas:** `v1` (1.0/1.1 legacy), `v3` (3.6.2 FireDaemon), `v4` (4.0.0 FireDaemon).
- **Custom path opcional:** `SetCustomPath` sobrescreve a heuristica por pasta ao lado do `.exe`.
- **Fail-safe:** se versao nao for 1/3/4 cai em default `v3`.
- **SetDllDirectory tolerante:** mesmo que a pasta nao exista, Windows aceita e volta aos fallbacks padrao.
- **Cross-compiler:** FPC (`uses Windows`) e Delphi (`Winapi.Windows`) via `$IFDEF FPC`.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` | FPC em modo Delphi |
| `{$IFDEF MSWINDOWS}` | Guarda para `SetDllDirectory` — POSIX fica stub |
| `Winapi.Windows` / `Windows` | Import de `SetDllDirectory(PChar)` |
| `ParamStr(0)` | Caminho do executavel corrente |
| `ExtractFilePath` | Dirname do executavel |

Subpastas canonicas:

| Constante | Valor | Uso |
| --- | --- | --- |
| `OPENSSL_DLL_SUBDIR_V1` | `'dll\v1'` | OpenSSL 1.0/1.1 legacy |
| `OPENSSL_DLL_SUBDIR_V3` | `'dll\v3'` | OpenSSL 3.6.2 |
| `OPENSSL_DLL_SUBDIR_V4` | `'dll\v4'` | OpenSSL 4.0.0 |
| `OPENSSL_DLL_ARCH` | `'win32'` ou `'win64'` | Depende de `$IFDEF WIN32/WIN64` |

---

## 4. Funcionalidades

### 4.1 Metodos de classe (estaticos)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SetCustomPath` | `class procedure SetCustomPath(const APath: string); static` | Define um path custom absoluto. String vazia limpa (volta a heuristica relativa ao `.exe`) |
| `Resolve` | `class function Resolve(AVersion: Integer): string; static` | Devolve o path que `Apply` usaria, sem efeitos colaterais. Ideal para diagnostico/log |
| `Apply` | `class procedure Apply(AVersion: Integer); static` | Aplica o path via `SetDllDirectory`. No-op em POSIX |

### 4.2 Estado interno

| Campo | Tipo | Descricao |
| --- | --- | --- |
| `FCustomPath` | `class var string` (strict private) | Guardado por `SetCustomPath`; limpo em `initialization` |

### 4.3 Logica de resolucao

1. Se `FCustomPath <> ''` -> retorna `FCustomPath`.
2. Escolhe subdir conforme `AVersion`:
   - `1` -> `dll\v1`
   - `3` -> `dll\v3`
   - `4` -> `dll\v4`
   - outro -> fallback `dll\v3`
3. Windows: `Result := ExtractFilePath(ParamStr(0)) + LSubdir + '\' + OPENSSL_DLL_ARCH;`
4. POSIX: `Result := ExtractFilePath(ParamStr(0)) + LSubdir;` (sem sub-pasta de arch)

---

## 5. Aplicabilidades

1. **Deploy self-contained:** distribuir `<exe>/dll/v3/win64/libssl-3-x64.dll` ao lado do binario, sem depender de OpenSSL instalado na maquina.
2. **Isolamento de conflito:** evitar colisao com `libssl-3.dll` de outro software (PostgreSQL, Python, Node).
3. **Teste A/B:** um mesmo `.exe` pode trocar entre `Apply(3)` e `Apply(4)` entre execucoes para comparar OpenSSL 3.6.2 vs 4.0.0.
4. **Deteccao de ambiente:** `Resolve(3)` em log de startup para documentar onde as DLLs deveriam estar.
5. **Custom path para instalacao especial:** `SetCustomPath('C:\Tools\OpenSSL-3\bin')` antes de `Apply` numa maquina de CI.

---

## 6. Exemplos de uso

### 6.1 Apply na inicializacao da aplicacao (uso tipico)

```pascal
program MyApp;

uses
  ssl_openssl_paths,
  ssl_openssl3;   // plugin carrega DLLs apos SetDllDirectory

begin
  // Aponta para <exe>\dll\v3\win64\
  TOpenSSLPaths.Apply(3);

  // Agora qualquer codigo que carregue OpenSSL usa as DLLs desta pasta
  // ...
end.
```

### 6.2 Custom path (ambiente de teste)

```pascal
uses
  ssl_openssl_paths, ssl_openssl4;

begin
  TOpenSSLPaths.SetCustomPath('C:\OpenSSL-4\bin\');
  TOpenSSLPaths.Apply(4);
  // libssl-4-x64.dll sera carregada de C:\OpenSSL-4\bin\
end.
```

### 6.3 Diagnostico do path resolvido

```pascal
uses
  SysUtils, ssl_openssl_paths;

begin
  WriteLn('Path OpenSSL 1.x: ', TOpenSSLPaths.Resolve(1));
  WriteLn('Path OpenSSL 3.x: ', TOpenSSLPaths.Resolve(3));
  WriteLn('Path OpenSSL 4.0: ', TOpenSSLPaths.Resolve(4));
  // Exemplo de saida:
  //   Path OpenSSL 3.x: C:\App\bin\dll\v3\win64
end.
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Consumida por | Aplicacoes CSL | Invocar `TOpenSSLPaths.Apply(N)` antes de usar `ssl_openssl*` |
| Depende de | Winapi.Windows / Windows (RTL) | `SetDllDirectory(PChar)` em Windows |
| Complementa | `ssl_openssl3` / `ssl_openssl4` | Modula de onde vem `libssl-3`/`libssl-4` |
| Seguranca | `SetDllDirectory` substitui | O loader antes de LoadLibrary — protege contra DLL hijacking na pasta actual |
| Posix fallback | Stub no-op | Nao ha equivalente directo; usa `LD_LIBRARY_PATH` ou `dlopen` com path absoluto |
| Design | Fail-safe | Versao desconhecida cai em `dll\v3\<arch>\` por default |
