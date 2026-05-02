{==============================================================================|
| Project : Ararat Synapse (CSL fork)                            | 001.000.001 |
|==============================================================================|
| Content: OpenSSL DLL path resolver (SetDllDirectory helper)                  |
|==============================================================================|
| Copyright (c)2026, CSL Softwares                                             |
| All rights reserved.                                                         |
|                                                                              |
| Redistribution and use in source and binary forms, with or without           |
| modification, are permitted provided that the following conditions are met:  |
|                                                                              |
| Redistributions of source code must retain the above copyright notice, this  |
| list of conditions and the following disclaimer.                             |
|                                                                              |
| Redistributions in binary form must reproduce the above copyright notice,    |
| this list of conditions and the following disclaimer in the documentation    |
| and/or other materials provided with the distribution.                       |
|                                                                              |
| Neither the name of CSL Softwares nor the names of its contributors may      |
| be used to endorse or promote products derived from this software without    |
| specific prior written permission.                                           |
|                                                                              |
| THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"  |
| AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE    |
| IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE   |
| ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR  |
| ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL       |
| DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR   |
| SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER   |
| CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT           |
| LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY    |
| OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  |
| DAMAGE.                                                                      |
|==============================================================================|
| The Initial Developer of the Original Code is CSL Softwares (Brazil).        |
| Portions created by CSL Softwares are Copyright (c)2026.                     |
| All Rights Reserved.                                                         |
|==============================================================================|
| Contributor(s):                                                              |
|   Claiton de Souza Linhares <claiton.linhares@cslsoftwares.com.br>           |
|     (CSL Softwares) — new unit (SetDllDirectory helper)                      |
|==============================================================================|
| History: CSL fork history (this file):                                       |
|   001.000.000 (2026-04-21): Criação. Unit opt-in para resolução de path das  |
|                             DLLs OpenSSL v1/v3/v4 (libcrypto-*/libssl-*).    |
|                             Expõe TOpenSSLPaths com Apply/Resolve/           |
|                             SetCustomPath. Windows-only para SetDllDirectory;|
|                             POSIX stub no-op (usar LD_LIBRARY_PATH/dlopen).  |
|   001.000.001 (2026-04-28): Fix Delphi 12 — remoção do initialization        |
|                             "TOpenSSLPaths.FCustomPath := ''" que causa      |
|                             E2361 (Cannot access private symbol). Strict     |
|                             private class var auto-inicializa para ''.       |
|==============================================================================}

{:@abstract(OpenSSL DLL path resolver)

Unit opt-in do fork CSL do Synapse. Pertence ao vendor Packege/synapse/.
Permite que uma aplicação informe uma pasta específica onde as DLLs OpenSSL
estão, em vez de depender do padrão Windows (PATH + pasta do .exe + System32).

Comportamento de Apply:
  1. Se SetCustomPath foi chamado antes, usa esse path.
  2. Senão, calcula 'dll\v<N>\<arch>\' relativo ao executável (ParamStr(0)).
  3. SEMPRE chama SetDllDirectory (mesmo se a pasta não existir — Windows
     aceita path inexistente e continua a procurar nos fallbacks padrão:
     pasta do .exe, PATH, System32).

API:
  TOpenSSLPaths.SetCustomPath('C:\outra\pasta\');  // opcional
  TOpenSSLPaths.Apply(3);                           // aplica SetDllDirectory
  TOpenSSLPaths.Resolve(3);                         // só devolve path (diagnóstico)

Cross-compiler:
  - Delphi (Winapi.Windows) e FPC (Windows) via IFDEF FPC.
  - Windows-only: SetDllDirectory está sob IFDEF MSWINDOWS. Em POSIX,
    os métodos são stubs no-op (usar LD_LIBRARY_PATH ou dlopen com path).
}
unit ssl_openssl_paths;

{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF FPC}
uses
  {$IFDEF MSWINDOWS}Windows,{$ENDIF}
  SysUtils;
{$ELSE}
uses
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF}
  System.SysUtils;
{$ENDIF}

const
  { Subpastas padrão relativas ao executável. }
  OPENSSL_DLL_SUBDIR_V1 = 'dll\v1';   { OpenSSL 1.0/1.1 (compat V1.4.0)   }
  OPENSSL_DLL_SUBDIR_V3 = 'dll\v3';   { OpenSSL 3.6.2 (FireDaemon)        }
  OPENSSL_DLL_SUBDIR_V4 = 'dll\v4';   { OpenSSL 4.0.0 (FireDaemon)        }

  {$IFDEF WIN32}
  OPENSSL_DLL_ARCH = 'win32';
  {$ENDIF}
  {$IFDEF WIN64}
  OPENSSL_DLL_ARCH = 'win64';
  {$ENDIF}

type
  TOpenSSLPaths = class
  strict private
    class var FCustomPath: string;
  public
    { Força um path específico para as DLLs. String vazia limpa o custom path. }
    class procedure SetCustomPath(const APath: string); static;

    { Devolve o path que Apply usaria. Sem efeitos colaterais.
      Se SetCustomPath foi chamado, devolve esse path.
      Senão, devolve '<.exe dir>\dll\v<N>\<arch>'. }
    class function Resolve(AVersion: Integer): string; static;

    { Aplica o path calculado via SetDllDirectory. SEMPRE invoca a API —
      mesmo que a pasta não exista, Windows aceita e continua a procurar
      nos fallbacks padrão. Em POSIX é no-op (SetDllDirectory não existe). }
    class procedure Apply(AVersion: Integer); static;
  end;

implementation

class procedure TOpenSSLPaths.SetCustomPath(const APath: string);
begin
  FCustomPath := APath;
end;

class function TOpenSSLPaths.Resolve(AVersion: Integer): string;
var
  LSubdir: string;
begin
  if FCustomPath <> '' then
    Exit(FCustomPath);

  case AVersion of
    1: LSubdir := OPENSSL_DLL_SUBDIR_V1;
    3: LSubdir := OPENSSL_DLL_SUBDIR_V3;
    4: LSubdir := OPENSSL_DLL_SUBDIR_V4;
  else
    LSubdir := OPENSSL_DLL_SUBDIR_V3;   { fail-safe default: 3.x }
  end;

  {$IFDEF MSWINDOWS}
  Result := ExtractFilePath(ParamStr(0)) + LSubdir + '\' + OPENSSL_DLL_ARCH;
  {$ELSE}
  Result := ExtractFilePath(ParamStr(0)) + LSubdir;   { POSIX: sem subfolder de arch }
  {$ENDIF}
end;

{$IFDEF MSWINDOWS}
{$IFDEF FPC}
{ FPC RTL Windows unit pode nao expor SetDllDirectory directamente em todas as
  versoes — declarar externamente para compatibilidade. }
function _SetDllDirectoryW(lpPathName: PWideChar): LongBool; stdcall;
  external 'kernel32' name 'SetDllDirectoryW';
{$ENDIF}
{$ENDIF}

class procedure TOpenSSLPaths.Apply(AVersion: Integer);
{$IFDEF MSWINDOWS}
var
  LPath: string;
  LWide: WideString;
begin
  LPath := Resolve(AVersion);
  {$IFDEF FPC}
  LWide := WideString(LPath);
  _SetDllDirectoryW(PWideChar(LWide));
  {$ELSE}
  SetDllDirectory(PChar(LPath));
  {$ENDIF}
end;
{$ELSE}
begin
  { POSIX: SetDllDirectory não existe. Carregamento de .so usa LD_LIBRARY_PATH
    (variável de ambiente) ou dlopen com path absoluto. Stub no-op aqui. }
end;
{$ENDIF}

{ CSL patch 2026-04-28 — strict private class var auto-init para '' (string vazia)
  em Delphi 12; linha removida por causar E2361 (Cannot access private symbol).
  Original: TOpenSSLPaths.FCustomPath := ''; }

end.
