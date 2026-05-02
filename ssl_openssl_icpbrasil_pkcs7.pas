{==============================================================================|
| Project : Ararat Synapse (CSL fork)                            | 001.000.000 |
|==============================================================================|
| Content: PKCS#7/CMS signer for ICP-Brasil — CAdES-BES (S12 — v41.9)          |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
| All rights reserved.                                                         |
|==============================================================================|
| Reference: RFC 5652 (CMS) + ETSI EN 319 122 (CAdES) + ICP-Brasil DOC-ICP-15  |
|==============================================================================|
| History:                                                                     |
|   001.000.000 (2026-05-01): Criacao S12. PKCS#7 signer com bindings          |
|                             auto-contidos para PKCS7_sign / PKCS7_verify.    |
|                             Modos: detached (CAdES-BES) e attached.          |
|==============================================================================}

(*:@abstract(PKCS#7/CMS signer for ICP-Brasil — CAdES-BES detached signing)

Cliente standalone para assinatura PKCS#7 / CAdES-BES. Bindings auto-contidos
para PKCS7_sign + PKCS7_verify + i2d_PKCS7 + d2i_PKCS7. Suporta:

  - psBinarioCMS    — DER binario (default fiscal)
  - psDetached      — assinatura sem o conteudo embedded (padrao NFe)
  - psAttached      — conteudo embedded no PKCS#7
  - psBase64        — DER + Base64 wrapping

Uso tipico (assinar XML NFe):

  var
    LSigner: TPkcs7Signer;
    LSignedBytes: TBytes;
  begin
    LSigner := TPkcs7Signer.Create;
    try
      LSignedBytes := LSigner.AssinarBytes(LXmlBytes, LCert, LKey, psDetached);
      // LSignedBytes pode ser anexado ao envelope SOAP/XML da NFe
    finally
      LSigner.Free;
    end;
  end;

NOTA: para CAdES-T (com timestamp) usar ssl_openssl_icpbrasil_tsp em conjunto.
*)

unit ssl_openssl_icpbrasil_pkcs7;

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

  TPkcs7Mode = (
    psBinarioCMS,         // DER binary, attached
    psDetached,           // detached (CAdES-BES, padrao NFe)
    psAttached,           // attached signature with content
    psBase64              // detached + Base64 wrapping
  );

  TPkcs7SignResult = record
    OK:           Boolean;
    SignedBytes:  TBytes;       // DER bytes (ou Base64 se psBase64)
    ErrorMsg:     string;
    SizeBytes:    Integer;
  end;

  EPkcs7Error = class(Exception);

  TPkcs7Signer = class
  private
    FLastError: string;
  public
    constructor Create;
    destructor Destroy; override;

    { Assina ABytes com ACert+AKey produzindo PKCS#7. }
    function AssinarBytes(const ABytes: TBytes; ACert: PX509; AKey: SslPtr;
                          AMode: TPkcs7Mode = psDetached): TPkcs7SignResult;

    { Verifica assinatura PKCS#7 contra trust store (X509_STORE*).
      AOriginalContent so e usado se signature for detached (psDetached). }
    function VerificarAssinatura(const ASigned: TBytes; AStore: SslPtr;
                                 const AOriginalContent: TBytes;
                                 ADetached: Boolean = True): Boolean;

    property LastError: string read FLastError;
  end;

implementation

uses
  synacode;

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

  PKCS7_BINARY  = $0080;
  PKCS7_DETACHED = $0040;
  PKCS7_NOATTR  = $0100;

type
  TPkcs7Sign_FN     = function(signcert: PX509; pkey: SslPtr; certs: SslPtr;
                              data: PBIO; flags: Integer): SslPtr; cdecl;
  TPkcs7Free_FN     = procedure(p7: SslPtr); cdecl;
  TI2dPkcs7_FN      = function(p7: SslPtr; out_buf: PPointer): Integer; cdecl;
  TD2iPkcs7_FN      = function(p7: PPointer; in_buf: PPointer; len: NativeInt): SslPtr; cdecl;
  TPkcs7Verify_FN   = function(p7, certs: SslPtr; store: SslPtr;
                              indata: PBIO; outdata: PBIO; flags: Integer): Integer; cdecl;
  TBioNew_FN        = function(meth: SslPtr): PBIO; cdecl;
  TBioNewMemBuf_FN  = function(buf: Pointer; len: Integer): PBIO; cdecl;
  TBioFreeAll_FN    = procedure(b: PBIO); cdecl;
  TBioSMem_FN       = function: SslPtr; cdecl;
  TBioWrite_FN      = function(b: PBIO; data: Pointer; len: Integer): Integer; cdecl;
  TCryptoFree_FN    = procedure(p: Pointer; f: PAnsiChar; l: Integer); cdecl;

var
  FInitialized: Boolean = False;
  FInitOK:      Boolean = False;
  FLibHandle:   TLibHandle = 0;

  _Pkcs7Sign:        TPkcs7Sign_FN = nil;
  _Pkcs7Free:        TPkcs7Free_FN = nil;
  _I2dPkcs7:         TI2dPkcs7_FN = nil;
  _D2iPkcs7:         TD2iPkcs7_FN = nil;
  _Pkcs7Verify:      TPkcs7Verify_FN = nil;
  _BioNew:           TBioNew_FN = nil;
  _BioNewMemBuf:     TBioNewMemBuf_FN = nil;
  _BioFreeAll:       TBioFreeAll_FN = nil;
  _BioSMem:          TBioSMem_FN = nil;
  _BioWrite:         TBioWrite_FN = nil;
  _CryptoFreeP7:     TCryptoFree_FN = nil;

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

function InitPkcs7Bindings: Boolean;
begin
  if FInitialized then Exit(FInitOK);
  FInitialized := True;
  FInitOK := False;
  if not TX509Ext.Init then Exit;
  FLibHandle := CslLoadLib(LIBCRYPTO_NAME);
  if FLibHandle = 0 then Exit;

  _Pkcs7Sign     := TPkcs7Sign_FN(CslGetProc(FLibHandle, 'PKCS7_sign'));
  _Pkcs7Free     := TPkcs7Free_FN(CslGetProc(FLibHandle, 'PKCS7_free'));
  _I2dPkcs7      := TI2dPkcs7_FN(CslGetProc(FLibHandle, 'i2d_PKCS7'));
  _D2iPkcs7      := TD2iPkcs7_FN(CslGetProc(FLibHandle, 'd2i_PKCS7'));
  _Pkcs7Verify   := TPkcs7Verify_FN(CslGetProc(FLibHandle, 'PKCS7_verify'));
  _BioNew        := TBioNew_FN(CslGetProc(FLibHandle, 'BIO_new'));
  _BioNewMemBuf  := TBioNewMemBuf_FN(CslGetProc(FLibHandle, 'BIO_new_mem_buf'));
  _BioFreeAll    := TBioFreeAll_FN(CslGetProc(FLibHandle, 'BIO_free_all'));
  _BioSMem       := TBioSMem_FN(CslGetProc(FLibHandle, 'BIO_s_mem'));
  _BioWrite      := TBioWrite_FN(CslGetProc(FLibHandle, 'BIO_write'));
  _CryptoFreeP7  := TCryptoFree_FN(CslGetProc(FLibHandle, 'CRYPTO_free'));

  FInitOK :=
    Assigned(_Pkcs7Sign) and Assigned(_Pkcs7Free) and Assigned(_I2dPkcs7) and
    Assigned(_BioNewMemBuf) and Assigned(_BioFreeAll);
  Result := FInitOK;
end;

{ TPkcs7Signer }

constructor TPkcs7Signer.Create;
begin
  inherited;
end;

destructor TPkcs7Signer.Destroy;
begin
  inherited;
end;

function TPkcs7Signer.AssinarBytes(const ABytes: TBytes; ACert: PX509;
  AKey: SslPtr; AMode: TPkcs7Mode): TPkcs7SignResult;
var
  LBio: PBIO;
  LP7: SslPtr;
  LFlags: Integer;
  LBuf: PByte;
  LLen: Integer;
  LDerBytes: TBytes;
  LDerStr, LB64Str: AnsiString;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.OK := False;
  FLastError := '';

  if not InitPkcs7Bindings then
  begin
    Result.ErrorMsg := 'libcrypto-3 sem PKCS7_sign disponivel.';
    FLastError := Result.ErrorMsg;
    Exit;
  end;
  if not Assigned(ACert) or not Assigned(AKey) then
  begin
    Result.ErrorMsg := 'ACert ou AKey nil.';
    Exit;
  end;
  if Length(ABytes) = 0 then
  begin
    Result.ErrorMsg := 'ABytes vazio.';
    Exit;
  end;

  LBio := _BioNewMemBuf(@ABytes[0], Length(ABytes));
  if not Assigned(LBio) then
  begin
    Result.ErrorMsg := 'BIO_new_mem_buf falhou.';
    Exit;
  end;
  try
    LFlags := PKCS7_BINARY;
    if AMode in [psDetached, psBase64] then
      LFlags := LFlags or PKCS7_DETACHED;

    LP7 := _Pkcs7Sign(ACert, AKey, nil, LBio, LFlags);
    if not Assigned(LP7) then
    begin
      Result.ErrorMsg := 'PKCS7_sign falhou.';
      FLastError := Result.ErrorMsg;
      Exit;
    end;
    try
      LBuf := nil;
      LLen := _I2dPkcs7(LP7, @LBuf);
      if (LLen <= 0) or not Assigned(LBuf) then
      begin
        Result.ErrorMsg := 'i2d_PKCS7 falhou.';
        FLastError := Result.ErrorMsg;
        Exit;
      end;
      try
        SetLength(LDerBytes, LLen);
        Move(LBuf^, LDerBytes[0], LLen);

        case AMode of
          psBase64:
            begin
              SetString(LDerStr, PAnsiChar(@LDerBytes[0]), Length(LDerBytes));
              LB64Str := EncodeBase64(LDerStr);
              SetLength(Result.SignedBytes, Length(LB64Str));
              if Length(LB64Str) > 0 then
                Move(LB64Str[1], Result.SignedBytes[0], Length(LB64Str));
            end;
        else
          Result.SignedBytes := LDerBytes;
        end;
        Result.SizeBytes := Length(Result.SignedBytes);
        Result.OK := True;
      finally
        if Assigned(_CryptoFreeP7) then
          _CryptoFreeP7(LBuf, nil, 0);
      end;
    finally
      _Pkcs7Free(LP7);
    end;
  finally
    _BioFreeAll(LBio);
  end;
end;

function TPkcs7Signer.VerificarAssinatura(const ASigned: TBytes; AStore: SslPtr;
  const AOriginalContent: TBytes; ADetached: Boolean): Boolean;
var
  LBioSig, LBioContent: PBIO;
  LP7: SslPtr;
  LFlags: Integer;
  LSrcPtr: PByte;
  LSrcPtrPtr: PPointer;
begin
  Result := False;
  FLastError := '';
  if not InitPkcs7Bindings then Exit;
  if not Assigned(_Pkcs7Verify) or not Assigned(_D2iPkcs7) then
  begin
    FLastError := 'PKCS7_verify ou d2i_PKCS7 nao disponiveis.';
    Exit;
  end;
  if Length(ASigned) = 0 then Exit;

  LSrcPtr := @ASigned[0];
  LSrcPtrPtr := @LSrcPtr;
  LP7 := _D2iPkcs7(nil, PPointer(LSrcPtrPtr), Length(ASigned));
  if not Assigned(LP7) then
  begin
    FLastError := 'd2i_PKCS7 falhou.';
    Exit;
  end;
  try
    LFlags := PKCS7_BINARY;
    LBioContent := nil;
    if ADetached and (Length(AOriginalContent) > 0) then
      LBioContent := _BioNewMemBuf(@AOriginalContent[0], Length(AOriginalContent));
    LBioSig := nil;
    try
      Result := _Pkcs7Verify(LP7, nil, AStore, LBioContent, LBioSig, LFlags) = 1;
      if not Result then
        FLastError := 'PKCS7_verify falhou (assinatura invalida ou trust store insuficiente).';
    finally
      if Assigned(LBioContent) then _BioFreeAll(LBioContent);
    end;
  finally
    _Pkcs7Free(LP7);
  end;
end;

initialization

finalization
  CslFreeLib(FLibHandle);
  FLibHandle := 0;

end.
