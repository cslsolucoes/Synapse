{==============================================================================|
| Project : Ararat Synapse                                       | 001.001.000 |
|==============================================================================|
| Content: X509 chain verification companion (S9+S10 — CSL fork v41.6/v41.7)   |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
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
| Neither the name of Lukas Gebauer nor the names of its contributors may      |
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
| The Initial Developer of the Original Code is CSL Tech Solutions.            |
| Portions created by CSL Tech Solutions are Copyright (c)2026.                |
| All Rights Reserved.                                                         |
|==============================================================================|
| Contributor(s):                                                              |
|   Claiton de Souza Linhares <claiton.linhares@cslsoftwares.com.br>           |
|     (CSL Softwares) — new unit (X509 chain verification)                     |
|==============================================================================|
| History: CSL fork history (this file):                                       |
|   001.000.000 (2026-05-01): Criacao S9. Companion para validacao de cadeia   |
|                             X509 offline programatica via OpenSSL 3 stack.   |
|                             TX509ChainVerifier + TVerifyResult + bundle      |
|                             AC-Raiz loadable de PEM file.                    |
|   001.001.000 (2026-05-01): S10. Adicionados bindings CRL: d2i_X509_CRL,     |
|                             X509_CRL_free, X509_CRL_verify, e helpers para   |
|                             integracao com ssl_openssl_icpbrasil_crl.        |
|==============================================================================}

{:@abstract(X509 chain verification — Programmatic offline cert chain validation)

Companion CSL para validacao de cadeia X509 sem depender do TLS handshake. Usa
o stack OpenSSL 3 (X509_STORE_*, X509_STORE_CTX_*, X509_verify_cert) via
GetProcAddress. Permite carregar bundle de AC-Raiz a partir de PEM file
(ex.: estrutura ICP-Brasil v1-v10 do ITI).

API:
  TX509ChainVerifier.Create  / .Free
  TX509ChainVerifier.LoadStoreFromPEM('caminho/bundle.pem'): Boolean
  TX509ChainVerifier.LoadStoreFromCertList(const APEMCerts: array of string)
  TX509ChainVerifier.AddTrustedCert(ACert: PX509)
  TX509ChainVerifier.Verify(ACert: PX509; AChain: SslPtr = nil): TVerifyResult

NOTA: este unit nao baixa AC-Raiz da Internet — bundle deve ser providenciado
pelo consumidor. Ver bundles/AC-Raiz-ICP-Brasil-fetch.ps1 para auto-download
do site ITI (https://estrutura.iti.gov.br).
}
unit ssl_openssl_chain_verify;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils, Classes,
  ssl_openssl3_lib,
  ssl_openssl_x509_ext,
  {$IFDEF MSWINDOWS}Windows{$ELSE}DynLibs{$ENDIF};

type
  {$IFNDEF FPC}
  TLibHandle = THandle;
  {$ENDIF}

  { Resultado de uma verificacao de cadeia. Todos os campos populados
    independentemente do resultado (mesmo em falha — para diagnostico). }
  TVerifyResult = record
    OK:                Boolean;
    ErrCode:           Integer;     // X509_V_ERR_* (ssl_openssl3_lib)
    ErrText:           string;      // texto humano-legivel via X509_verify_cert_error_string
    ChainProfundidade: Integer;     // numero de certs ate a raiz
    SubjectCN:         string;      // CN do cert verificado (info)
    IssuerCN:          string;      // CN do issuer (info)
  end;

  EChainVerifyError = class(Exception);

  { S10 — CRL info extraida de uma X509_CRL parseada. }
  TCrlInfo = record
    Loaded:        Boolean;
    LastUpdate:    TDateTime;       // UTC
    NextUpdate:    TDateTime;       // UTC; 0 se ausente
    NumRevoked:    Integer;         // certs revogados nesta CRL
  end;

  { S10 — Resultado de IsRevogadoNaCRL. }
  TCrlCheckResult = record
    Revogado:      Boolean;
    Motivo:        string;          // 'keyCompromise', 'cACompromise', etc.
    DataRevogacao: TDateTime;       // UTC; 0 se nao aplicavel
    SerialBuscado: string;          // hex uppercase
  end;

  TX509ChainVerifier = class
  private
    FStore: SslPtr;     // X509_STORE*
    function GetStore: SslPtr;
  public
    constructor Create;
    destructor Destroy; override;

    { Carrega AC-Raiz e intermediarias de um PEM bundle (multiplos certs
      concatenados). Retorna numero de certs carregados (-1 em erro). }
    function LoadStoreFromPEM(const APath: string): Integer;

    { Carrega AC-Raiz a partir de lista de strings PEM (cada item = 1 cert
      em formato PEM). Util para usar bundle embarcado via $I include directive. }
    function LoadStoreFromCertList(const APEMCerts: array of string): Integer;

    { Adiciona um cert ja carregado (PX509) ao store de raizes confiaveis.
      Retorna True em sucesso. NAO toma ownership — caller continua dono do PX509. }
    function AddTrustedCert(ACert: PX509): Boolean;

    { Limpa o store. }
    procedure ClearStore;

    { Verifica cadeia do cert ACert contra AC-Raizes carregadas no store.
      AChain (opcional) = STACK_OF(X509)* com intermediarias (do PFX, p.ex.).
      Retorna TVerifyResult preenchido. }
    function Verify(ACert: PX509; AChain: SslPtr = nil): TVerifyResult;

    property Store: SslPtr read GetStore;

    { ============================================================
      S10 — CRL utility class methods (sem state — usar standalone). }

    { Decodifica CRL DER bytes para X509_CRL*. Caller DEVE chamar
      FreeCrl(ACrl) apos uso. Devolve True em sucesso. }
    class function LoadCrlFromBytes(const ABytes: array of Byte;
                                    out ACrl: SslPtr;
                                    out AInfo: TCrlInfo): Boolean; static;

    { Decodifica CRL PEM bytes (uma CRL, com headers BEGIN/END X509 CRL). }
    class function LoadCrlFromPEM(const APEMText: AnsiString;
                                  out ACrl: SslPtr;
                                  out AInfo: TCrlInfo): Boolean; static;

    { Libera CRL alocada por LoadCrlFromBytes/LoadCrlFromPEM. }
    class procedure FreeCrl(var ACrl: SslPtr); static;

    { Valida assinatura da CRL contra a chave publica do issuer. True se OK. }
    class function VerifyCrlSignature(ACrl: SslPtr; AIssuer: PX509): Boolean; static;

    { Verifica se ASerialHex (hex uppercase, sem prefixo 0x) esta na CRL.
      Popula AResult com motivo + data se revogado. Retorna True se a busca
      foi conclusiva (independentemente de revogado ou nao). }
    class function IsRevogadoNaCRL(ACrl: SslPtr; const ASerialHex: string;
                                   out AResult: TCrlCheckResult): Boolean; static;
  end;

implementation

const
  {$IFDEF MSWINDOWS}
  LIBCRYPTO_NAME = 'libcrypto-3-x64.dll';
  {$ELSE}
    {$IFDEF DARWIN}
    LIBCRYPTO_NAME = 'libcrypto.3.dylib';
    {$ELSE}
    LIBCRYPTO_NAME = 'libcrypto.so.3';
    {$ENDIF}
  {$ENDIF}

type
  TX509StoreNew_FN          = function: SslPtr; cdecl;
  TX509StoreFree_FN         = procedure(store: SslPtr); cdecl;
  TX509StoreAddCert_FN      = function(store: SslPtr; cert: PX509): Integer; cdecl;
  TX509StoreSetFlags_FN     = function(store: SslPtr; flags: NativeUInt): Integer; cdecl;
  TX509StoreCtxNew_FN       = function: SslPtr; cdecl;
  TX509StoreCtxFree_FN      = procedure(ctx: SslPtr); cdecl;
  TX509StoreCtxInit_FN      = function(ctx, store: SslPtr; cert: PX509;
                                       chain: SslPtr): Integer; cdecl;
  TX509StoreCtxCleanup_FN   = procedure(ctx: SslPtr); cdecl;
  TX509StoreCtxGetError_FN  = function(ctx: SslPtr): Integer; cdecl;
  TX509StoreCtxGetErrDepth_FN = function(ctx: SslPtr): Integer; cdecl;
  TX509VerifyCert_FN        = function(ctx: SslPtr): Integer; cdecl;
  TX509VerifyErrorString_FN = function(n: NativeInt): PAnsiChar; cdecl;
  TPemReadBioX509_FN        = function(bio: PBIO; x: PPointer; cb, u: Pointer): PX509; cdecl;
  TBioNewMemBuf_FN          = function(buf: Pointer; len: Integer): PBIO; cdecl;
  TBioFreeAll_FN            = procedure(b: PBIO); cdecl;

  { S10 — CRL bindings. }
  TD2iX509CRL_FN            = function(ax: PPointer; in_buf: PPointer;
                                       len: NativeInt): SslPtr; cdecl;
  TPemReadBioX509Crl_FN     = function(bio: PBIO; x: PPointer; cb, u: Pointer): SslPtr; cdecl;
  TX509CrlFree_FN           = procedure(crl: SslPtr); cdecl;
  TX509CrlVerify_FN         = function(crl, pkey: SslPtr): Integer; cdecl;
  TX509CrlGetIssuer_FN      = function(crl: SslPtr): PX509_NAME; cdecl;
  TX509CrlGet0LastUpdate_FN = function(crl: SslPtr): SslPtr; cdecl;     // ASN1_TIME*
  TX509CrlGet0NextUpdate_FN = function(crl: SslPtr): SslPtr; cdecl;     // ASN1_TIME*
  TX509CrlGetRevoked_FN     = function(crl: SslPtr): SslPtr; cdecl;     // STACK_OF(X509_REVOKED)*
  TX509CrlGet0BySerial_FN   = function(crl: SslPtr; ret: PPointer;
                                       serial: SslPtr): Integer; cdecl;
  TX509GetSerialNumber_FN   = function(x: PX509): SslPtr; cdecl;        // ASN1_INTEGER*
  TX509RevokedGet0Serial_FN = function(rev: SslPtr): SslPtr; cdecl;     // ASN1_INTEGER*
  TX509RevokedGet0RevDate_FN= function(rev: SslPtr): SslPtr; cdecl;     // ASN1_TIME*
  TX509RevokedGet0Exts_FN   = function(rev: SslPtr): SslPtr; cdecl;     // STACK_OF(X509_EXTENSION)*
  TSkX509RevokedNum_FN      = function(stack: SslPtr): Integer; cdecl;
  TSkX509RevokedValue_FN    = function(stack: SslPtr; idx: Integer): SslPtr; cdecl;
  TX509GetPubkey_FN         = function(x: PX509): SslPtr; cdecl;
  TEvpPkeyFreeBind_FN       = procedure(pkey: SslPtr); cdecl;
  TAsn1IntCmp_FN            = function(a, b: SslPtr): Integer; cdecl;
  TAsn1IntegerToBn_FN       = function(ai, bn: SslPtr): SslPtr; cdecl;
  TBnHex2Bn_FN              = function(a: PPointer; str: PAnsiChar): Integer; cdecl;
  TBnFreeBind_FN            = procedure(a: SslPtr); cdecl;
  TBnToAsn1Integer_FN       = function(bn, ai: SslPtr): SslPtr; cdecl;
  TAsn1IntegerNew_FN        = function: SslPtr; cdecl;
  TAsn1IntegerFree_FN       = procedure(a: SslPtr); cdecl;

var
  FInitialized: Boolean = False;
  FInitOK:      Boolean = False;
  FLibHandle:   TLibHandle = 0;

  _X509StoreNew:           TX509StoreNew_FN = nil;
  _X509StoreFree:          TX509StoreFree_FN = nil;
  _X509StoreAddCert:       TX509StoreAddCert_FN = nil;
  _X509StoreSetFlags:      TX509StoreSetFlags_FN = nil;
  _X509StoreCtxNew:        TX509StoreCtxNew_FN = nil;
  _X509StoreCtxFree:       TX509StoreCtxFree_FN = nil;
  _X509StoreCtxInit:       TX509StoreCtxInit_FN = nil;
  _X509StoreCtxCleanup:    TX509StoreCtxCleanup_FN = nil;
  _X509StoreCtxGetError:   TX509StoreCtxGetError_FN = nil;
  _X509StoreCtxGetErrDepth:TX509StoreCtxGetErrDepth_FN = nil;
  _X509VerifyCert:         TX509VerifyCert_FN = nil;
  _X509VerifyErrorString:  TX509VerifyErrorString_FN = nil;
  _PemReadBioX509:         TPemReadBioX509_FN = nil;
  _BioNewMemBuf:           TBioNewMemBuf_FN = nil;
  _BioFreeAll:             TBioFreeAll_FN = nil;

  { S10 — CRL function pointers. }
  _D2iX509Crl:             TD2iX509CRL_FN = nil;
  _PemReadBioX509Crl:      TPemReadBioX509Crl_FN = nil;
  _X509CrlFree:            TX509CrlFree_FN = nil;
  _X509CrlVerify:          TX509CrlVerify_FN = nil;
  _X509CrlGet0LastUpdate:  TX509CrlGet0LastUpdate_FN = nil;
  _X509CrlGet0NextUpdate:  TX509CrlGet0NextUpdate_FN = nil;
  _X509CrlGetRevoked:      TX509CrlGetRevoked_FN = nil;
  _X509CrlGet0BySerial:    TX509CrlGet0BySerial_FN = nil;
  _X509GetSerialNumberCv:  TX509GetSerialNumber_FN = nil;
  _X509RevokedGet0Serial:  TX509RevokedGet0Serial_FN = nil;
  _X509RevokedGet0RevDate: TX509RevokedGet0RevDate_FN = nil;
  _SkX509RevokedNum:       TSkX509RevokedNum_FN = nil;
  _SkX509RevokedValue:     TSkX509RevokedValue_FN = nil;
  _X509GetPubkey:          TX509GetPubkey_FN = nil;
  _EvpPkeyFreeBind:        TEvpPkeyFreeBind_FN = nil;
  _Asn1IntCmp:             TAsn1IntCmp_FN = nil;
  _Asn1IntegerNew:         TAsn1IntegerNew_FN = nil;
  _Asn1IntegerFree:        TAsn1IntegerFree_FN = nil;
  _BnHex2Bn:               TBnHex2Bn_FN = nil;
  _BnFreeBind:             TBnFreeBind_FN = nil;
  _BnToAsn1Integer:        TBnToAsn1Integer_FN = nil;

function CslLoadLib(const AName: string): TLibHandle;
begin
  {$IFDEF FPC}
  Result := SafeLoadLibrary(AName);
  {$ELSE}
  Result := LoadLibrary(PChar(AName));
  {$ENDIF}
end;

function CslGetProc(AHandle: TLibHandle; const AName: AnsiString): Pointer;
begin
  {$IFDEF MSWINDOWS}
  Result := Windows.GetProcAddress(AHandle, PAnsiChar(AName));
  {$ELSE}
  Result := DynLibs.GetProcAddress(AHandle, AName);
  {$ENDIF}
end;

procedure CslFreeLib(AHandle: TLibHandle);
begin
  {$IFDEF FPC}
  if AHandle <> 0 then UnloadLibrary(AHandle);
  {$ELSE}
  if AHandle <> 0 then FreeLibrary(AHandle);
  {$ENDIF}
end;

function InitChainBindings: Boolean;
begin
  if FInitialized then Exit(FInitOK);
  FInitialized := True;
  FInitOK := False;

  { Reusa o handle do libcrypto carregado por TX509Ext (ja resolveu
    TOpenSSLPaths.Apply(3) e ja abriu a DLL). Carregar em handle
    proprio funciona mas duplica refcount sem necessidade. }
  if not TX509Ext.Init then Exit;

  FLibHandle := CslLoadLib(LIBCRYPTO_NAME);
  if FLibHandle = 0 then Exit;

  _X509StoreNew            := TX509StoreNew_FN(CslGetProc(FLibHandle, 'X509_STORE_new'));
  _X509StoreFree           := TX509StoreFree_FN(CslGetProc(FLibHandle, 'X509_STORE_free'));
  _X509StoreAddCert        := TX509StoreAddCert_FN(CslGetProc(FLibHandle, 'X509_STORE_add_cert'));
  _X509StoreSetFlags       := TX509StoreSetFlags_FN(CslGetProc(FLibHandle, 'X509_STORE_set_flags'));
  _X509StoreCtxNew         := TX509StoreCtxNew_FN(CslGetProc(FLibHandle, 'X509_STORE_CTX_new'));
  _X509StoreCtxFree        := TX509StoreCtxFree_FN(CslGetProc(FLibHandle, 'X509_STORE_CTX_free'));
  _X509StoreCtxInit        := TX509StoreCtxInit_FN(CslGetProc(FLibHandle, 'X509_STORE_CTX_init'));
  _X509StoreCtxCleanup     := TX509StoreCtxCleanup_FN(CslGetProc(FLibHandle, 'X509_STORE_CTX_cleanup'));
  _X509StoreCtxGetError    := TX509StoreCtxGetError_FN(CslGetProc(FLibHandle, 'X509_STORE_CTX_get_error'));
  _X509StoreCtxGetErrDepth := TX509StoreCtxGetErrDepth_FN(CslGetProc(FLibHandle, 'X509_STORE_CTX_get_error_depth'));
  _X509VerifyCert          := TX509VerifyCert_FN(CslGetProc(FLibHandle, 'X509_verify_cert'));
  _X509VerifyErrorString   := TX509VerifyErrorString_FN(CslGetProc(FLibHandle, 'X509_verify_cert_error_string'));
  _PemReadBioX509          := TPemReadBioX509_FN(CslGetProc(FLibHandle, 'PEM_read_bio_X509'));
  if not Assigned(_PemReadBioX509) then
    _PemReadBioX509        := TPemReadBioX509_FN(CslGetProc(FLibHandle, 'PEM_read_bio_X509_AUX'));
  _BioNewMemBuf            := TBioNewMemBuf_FN(CslGetProc(FLibHandle, 'BIO_new_mem_buf'));
  _BioFreeAll              := TBioFreeAll_FN(CslGetProc(FLibHandle, 'BIO_free_all'));

  { S10 — CRL bindings (optional — best-effort; methods return False if missing). }
  _D2iX509Crl              := TD2iX509CRL_FN(CslGetProc(FLibHandle, 'd2i_X509_CRL'));
  _PemReadBioX509Crl       := TPemReadBioX509Crl_FN(CslGetProc(FLibHandle, 'PEM_read_bio_X509_CRL'));
  _X509CrlFree             := TX509CrlFree_FN(CslGetProc(FLibHandle, 'X509_CRL_free'));
  _X509CrlVerify           := TX509CrlVerify_FN(CslGetProc(FLibHandle, 'X509_CRL_verify'));
  _X509CrlGet0LastUpdate   := TX509CrlGet0LastUpdate_FN(CslGetProc(FLibHandle, 'X509_CRL_get0_lastUpdate'));
  _X509CrlGet0NextUpdate   := TX509CrlGet0NextUpdate_FN(CslGetProc(FLibHandle, 'X509_CRL_get0_nextUpdate'));
  _X509CrlGetRevoked       := TX509CrlGetRevoked_FN(CslGetProc(FLibHandle, 'X509_CRL_get_REVOKED'));
  _X509CrlGet0BySerial     := TX509CrlGet0BySerial_FN(CslGetProc(FLibHandle, 'X509_CRL_get0_by_serial'));
  _X509GetSerialNumberCv   := TX509GetSerialNumber_FN(CslGetProc(FLibHandle, 'X509_get_serialNumber'));
  _X509RevokedGet0Serial   := TX509RevokedGet0Serial_FN(CslGetProc(FLibHandle, 'X509_REVOKED_get0_serialNumber'));
  _X509RevokedGet0RevDate  := TX509RevokedGet0RevDate_FN(CslGetProc(FLibHandle, 'X509_REVOKED_get0_revocationDate'));
  _SkX509RevokedNum        := TSkX509RevokedNum_FN(CslGetProc(FLibHandle, 'OPENSSL_sk_num'));
  _SkX509RevokedValue      := TSkX509RevokedValue_FN(CslGetProc(FLibHandle, 'OPENSSL_sk_value'));
  _X509GetPubkey           := TX509GetPubkey_FN(CslGetProc(FLibHandle, 'X509_get_pubkey'));
  _EvpPkeyFreeBind         := TEvpPkeyFreeBind_FN(CslGetProc(FLibHandle, 'EVP_PKEY_free'));
  _Asn1IntCmp              := TAsn1IntCmp_FN(CslGetProc(FLibHandle, 'ASN1_INTEGER_cmp'));
  _Asn1IntegerNew          := TAsn1IntegerNew_FN(CslGetProc(FLibHandle, 'ASN1_INTEGER_new'));
  _Asn1IntegerFree         := TAsn1IntegerFree_FN(CslGetProc(FLibHandle, 'ASN1_INTEGER_free'));
  _BnHex2Bn                := TBnHex2Bn_FN(CslGetProc(FLibHandle, 'BN_hex2bn'));
  _BnFreeBind              := TBnFreeBind_FN(CslGetProc(FLibHandle, 'BN_free'));
  _BnToAsn1Integer         := TBnToAsn1Integer_FN(CslGetProc(FLibHandle, 'BN_to_ASN1_INTEGER'));

  FInitOK :=
    Assigned(_X509StoreNew) and Assigned(_X509StoreFree) and
    Assigned(_X509StoreAddCert) and
    Assigned(_X509StoreCtxNew) and Assigned(_X509StoreCtxFree) and
    Assigned(_X509StoreCtxInit) and
    Assigned(_X509StoreCtxGetError) and
    Assigned(_X509VerifyCert) and Assigned(_X509VerifyErrorString) and
    Assigned(_PemReadBioX509) and
    Assigned(_BioNewMemBuf) and Assigned(_BioFreeAll);

  Result := FInitOK;
end;

{ TX509ChainVerifier }

constructor TX509ChainVerifier.Create;
begin
  inherited;
  FStore := nil;
end;

destructor TX509ChainVerifier.Destroy;
begin
  ClearStore;
  inherited;
end;

function TX509ChainVerifier.GetStore: SslPtr;
begin
  if not InitChainBindings then
    raise EChainVerifyError.Create(
      'libcrypto-3 nao tem simbolos X509_STORE_*/X509_verify_cert. ' +
      'Confirmar OpenSSL 3.x instalado e acessivel.');
  if FStore = nil then
    FStore := _X509StoreNew();
  Result := FStore;
end;

procedure TX509ChainVerifier.ClearStore;
begin
  if (FStore <> nil) and Assigned(_X509StoreFree) then
    _X509StoreFree(FStore);
  FStore := nil;
end;

function TX509ChainVerifier.AddTrustedCert(ACert: PX509): Boolean;
var
  LStore: SslPtr;
begin
  Result := False;
  if not Assigned(ACert) then Exit;
  LStore := GetStore;
  if LStore = nil then Exit;
  Result := _X509StoreAddCert(LStore, ACert) = 1;
end;

function _LoadCertsFromPemString(const APem: AnsiString): TArray<PX509>;
var
  LBio: PBIO;
  LCert: PX509;
begin
  SetLength(Result, 0);
  if APem = '' then Exit;
  if not Assigned(_BioNewMemBuf) or not Assigned(_PemReadBioX509) then Exit;

  LBio := _BioNewMemBuf(PAnsiChar(APem), Length(APem));
  if not Assigned(LBio) then Exit;
  try
    repeat
      LCert := _PemReadBioX509(LBio, nil, nil, nil);
      if Assigned(LCert) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := LCert;
      end;
    until not Assigned(LCert);
  finally
    _BioFreeAll(LBio);
  end;
end;

function TX509ChainVerifier.LoadStoreFromPEM(const APath: string): Integer;
var
  LFile: TFileStream;
  LBytes: TBytes;
  LStr: AnsiString;
  LCerts: TArray<PX509>;
  I: Integer;
begin
  Result := -1;
  if not FileExists(APath) then Exit;
  if not InitChainBindings then Exit;

  LFile := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LBytes, LFile.Size);
    if Length(LBytes) > 0 then
      LFile.ReadBuffer(LBytes[0], Length(LBytes));
  finally
    LFile.Free;
  end;
  if Length(LBytes) = 0 then Exit(0);
  SetString(LStr, PAnsiChar(@LBytes[0]), Length(LBytes));

  LCerts := _LoadCertsFromPemString(LStr);
  Result := 0;
  for I := 0 to High(LCerts) do
  begin
    if AddTrustedCert(LCerts[I]) then
      Inc(Result);
    { X509_STORE_add_cert NAO toma ownership — caller continua dono.
      Mas PX509 retornado por PEM_read_bio_X509 deve ser liberado.
      Como o store guarda referencia interna, X509Free aqui e seguro. }
    X509Free(LCerts[I]);
  end;
end;

function TX509ChainVerifier.LoadStoreFromCertList(
  const APEMCerts: array of string): Integer;
var
  I, J, LAdded: Integer;
  LCerts: TArray<PX509>;
begin
  Result := 0;
  if not InitChainBindings then Exit(-1);
  for I := 0 to High(APEMCerts) do
  begin
    LCerts := _LoadCertsFromPemString(AnsiString(APEMCerts[I]));
    LAdded := 0;
    for J := 0 to High(LCerts) do
    begin
      if AddTrustedCert(LCerts[J]) then
        Inc(LAdded);
      X509Free(LCerts[J]);
    end;
    Inc(Result, LAdded);
  end;
end;

{ ============================================================
  S10 — CRL utility class methods. }

function _PopulateCrlInfo(ACrl: SslPtr; var AInfo: TCrlInfo): Boolean;
var
  LStack: SslPtr;
begin
  Result := False;
  FillChar(AInfo, SizeOf(AInfo), 0);
  if not Assigned(ACrl) then Exit;

  if Assigned(_X509CrlGet0LastUpdate) then
    AInfo.LastUpdate := TX509Ext.X509ASN1TimeToDateTimeUTC(_X509CrlGet0LastUpdate(ACrl));
  if Assigned(_X509CrlGet0NextUpdate) then
    AInfo.NextUpdate := TX509Ext.X509ASN1TimeToDateTimeUTC(_X509CrlGet0NextUpdate(ACrl));
  if Assigned(_X509CrlGetRevoked) and Assigned(_SkX509RevokedNum) then
  begin
    LStack := _X509CrlGetRevoked(ACrl);
    if Assigned(LStack) then
      AInfo.NumRevoked := _SkX509RevokedNum(LStack);
  end;
  AInfo.Loaded := True;
  Result := True;
end;

class function TX509ChainVerifier.LoadCrlFromBytes(const ABytes: array of Byte;
  out ACrl: SslPtr; out AInfo: TCrlInfo): Boolean;
var
  LDataPtr: PByte;
  LSrcPtr: PPointer;
begin
  Result := False;
  ACrl := nil;
  FillChar(AInfo, SizeOf(AInfo), 0);

  if not InitChainBindings then Exit;
  if not Assigned(_D2iX509Crl) then Exit;
  if Length(ABytes) = 0 then Exit;

  LDataPtr := @ABytes[0];
  LSrcPtr := @LDataPtr;
  ACrl := _D2iX509Crl(nil, PPointer(LSrcPtr), Length(ABytes));
  if not Assigned(ACrl) then Exit;

  Result := _PopulateCrlInfo(ACrl, AInfo);
end;

class function TX509ChainVerifier.LoadCrlFromPEM(const APEMText: AnsiString;
  out ACrl: SslPtr; out AInfo: TCrlInfo): Boolean;
var
  LBio: PBIO;
begin
  Result := False;
  ACrl := nil;
  FillChar(AInfo, SizeOf(AInfo), 0);

  if not InitChainBindings then Exit;
  if not Assigned(_PemReadBioX509Crl) or not Assigned(_BioNewMemBuf) or
     not Assigned(_BioFreeAll) then Exit;
  if APEMText = '' then Exit;

  LBio := _BioNewMemBuf(PAnsiChar(APEMText), Length(APEMText));
  if not Assigned(LBio) then Exit;
  try
    ACrl := _PemReadBioX509Crl(LBio, nil, nil, nil);
  finally
    _BioFreeAll(LBio);
  end;
  if not Assigned(ACrl) then Exit;
  Result := _PopulateCrlInfo(ACrl, AInfo);
end;

class procedure TX509ChainVerifier.FreeCrl(var ACrl: SslPtr);
begin
  if Assigned(ACrl) and Assigned(_X509CrlFree) then
    _X509CrlFree(ACrl);
  ACrl := nil;
end;

class function TX509ChainVerifier.VerifyCrlSignature(ACrl: SslPtr;
  AIssuer: PX509): Boolean;
var
  LPkey: SslPtr;
begin
  Result := False;
  if not InitChainBindings then Exit;
  if not Assigned(ACrl) or not Assigned(AIssuer) then Exit;
  if not Assigned(_X509GetPubkey) or not Assigned(_X509CrlVerify) or
     not Assigned(_EvpPkeyFreeBind) then Exit;

  LPkey := _X509GetPubkey(AIssuer);
  if not Assigned(LPkey) then Exit;
  try
    Result := _X509CrlVerify(ACrl, LPkey) = 1;
  finally
    _EvpPkeyFreeBind(LPkey);
  end;
end;

function _HexSerialToAsn1Integer(const ASerialHex: string): SslPtr;
var
  LBn: SslPtr;
  LCleanHex: AnsiString;
begin
  Result := nil;
  LCleanHex := AnsiString(StringReplace(StringReplace(ASerialHex, ' ', '',
    [rfReplaceAll]), ':', '', [rfReplaceAll]));
  if LCleanHex = '' then Exit;
  if not Assigned(_BnHex2Bn) or not Assigned(_BnToAsn1Integer) or
     not Assigned(_BnFreeBind) then Exit;

  LBn := nil;
  if _BnHex2Bn(@LBn, PAnsiChar(LCleanHex)) = 0 then
  begin
    if Assigned(LBn) then _BnFreeBind(LBn);
    Exit;
  end;
  try
    Result := _BnToAsn1Integer(LBn, nil);
  finally
    _BnFreeBind(LBn);
  end;
end;

class function TX509ChainVerifier.IsRevogadoNaCRL(ACrl: SslPtr;
  const ASerialHex: string; out AResult: TCrlCheckResult): Boolean;
var
  LStack, LRev, LRevSerial, LSerialNeedle: SslPtr;
  LCount, I: Integer;
begin
  Result := False;
  FillChar(AResult, SizeOf(AResult), 0);
  AResult.SerialBuscado := UpperCase(ASerialHex);

  if not InitChainBindings then Exit;
  if not Assigned(ACrl) or (ASerialHex = '') then Exit;
  if not Assigned(_X509CrlGetRevoked) or not Assigned(_SkX509RevokedNum) or
     not Assigned(_SkX509RevokedValue) or not Assigned(_X509RevokedGet0Serial) or
     not Assigned(_Asn1IntCmp) then Exit;

  LSerialNeedle := _HexSerialToAsn1Integer(ASerialHex);
  if not Assigned(LSerialNeedle) then Exit;
  try
    LStack := _X509CrlGetRevoked(ACrl);
    if not Assigned(LStack) then
    begin
      Result := True;     // empty CRL — not revoked
      Exit;
    end;
    LCount := _SkX509RevokedNum(LStack);
    Result := True;
    for I := 0 to LCount - 1 do
    begin
      LRev := _SkX509RevokedValue(LStack, I);
      if not Assigned(LRev) then Continue;
      LRevSerial := _X509RevokedGet0Serial(LRev);
      if not Assigned(LRevSerial) then Continue;
      if _Asn1IntCmp(LRevSerial, LSerialNeedle) = 0 then
      begin
        AResult.Revogado := True;
        AResult.Motivo := 'unspecified';   { TODO: parse reason ext from LRev }
        if Assigned(_X509RevokedGet0RevDate) then
          AResult.DataRevogacao := TX509Ext.X509ASN1TimeToDateTimeUTC(
            _X509RevokedGet0RevDate(LRev));
        Break;
      end;
    end;
  finally
    if Assigned(_Asn1IntegerFree) then _Asn1IntegerFree(LSerialNeedle);
  end;
end;

function TX509ChainVerifier.Verify(ACert: PX509; AChain: SslPtr): TVerifyResult;
var
  LCtx: SslPtr;
  LStore: SslPtr;
  LErrText: PAnsiChar;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.OK := False;
  Result.ErrCode := -1;
  Result.ErrText := '';

  if not Assigned(ACert) then
  begin
    Result.ErrText := 'Cert e nil.';
    Exit;
  end;
  if not InitChainBindings then
  begin
    Result.ErrText := 'libcrypto-3 X509_STORE/verify_cert nao disponiveis.';
    Exit;
  end;

  Result.SubjectCN := string(TX509Ext.X509GetSubjectCN(ACert));
  Result.IssuerCN  := string(TX509Ext.X509GetIssuerCN(ACert));

  LStore := GetStore;
  if LStore = nil then
  begin
    Result.ErrText := 'X509_STORE nao pode ser criado.';
    Exit;
  end;

  LCtx := _X509StoreCtxNew();
  if LCtx = nil then
  begin
    Result.ErrText := 'X509_STORE_CTX_new falhou (alocacao).';
    Exit;
  end;
  try
    if _X509StoreCtxInit(LCtx, LStore, ACert, AChain) <> 1 then
    begin
      Result.ErrText := 'X509_STORE_CTX_init falhou.';
      Exit;
    end;

    Result.OK := _X509VerifyCert(LCtx) = 1;
    Result.ErrCode := _X509StoreCtxGetError(LCtx);
    if Assigned(_X509StoreCtxGetErrDepth) then
      Result.ChainProfundidade := _X509StoreCtxGetErrDepth(LCtx);

    if Assigned(_X509VerifyErrorString) then
    begin
      LErrText := _X509VerifyErrorString(Result.ErrCode);
      if LErrText <> nil then
        Result.ErrText := string(AnsiString(LErrText));
    end;
  finally
    if Assigned(_X509StoreCtxCleanup) then
      _X509StoreCtxCleanup(LCtx);
    _X509StoreCtxFree(LCtx);
  end;
end;

initialization
  { Lazy init na primeira chamada. }

finalization
  CslFreeLib(FLibHandle);
  FLibHandle := 0;

end.
