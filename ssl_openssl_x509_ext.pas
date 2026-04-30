{
| Project   : Ararat Synapse                                     |  v41.4     |
|==============================================================================|
| Content: X509 extensions companion unit (cross-platform PFX/X509 reader)     |
|==============================================================================|
| Copyright (c)1999-2023, Lukas Gebauer (Synapse upstream)                     |
| Copyright (c)2026, contributors (fork extensions)                            |
| All rights reserved.                                                         |
|                                                                              |
| Redistribution and use in source and binary forms, with or without           |
| modification, are permitted provided that the following conditions are met:  |
|                                                                              |
| BSD 3-Clause License (with linking exception) - see LICENSE for full text.   |
|==============================================================================|
| The Initial Developer of the Original Code is Lukas Gebauer (Czech Republic).|
| Portions created by contributors (incl. CSL Tech Solutions) are              |
| Copyright (c) 2026.                                                          |
|==============================================================================|
| Reference: .workspace/plans/pfx-cripto-synapse_v1.0.plan.md V2.1.0           |
|==============================================================================|
}

{:@abstract(X509 extensions companion unit - cross-platform via DynLibs/Windows)

Adds OpenSSL 3.x bindings missing from ssl_openssl3_lib.pas / ssl_openssl4_lib.pas:
NotBefore/After accessors, extensions iteration, ASN1_TIME conversion, and a
managed PKCS12 wrapper. Self-loads libcrypto-3 in own handle (Windows refcount
makes multiple LoadLibrary calls safe).

Public API:
  TX509Ext.X509GetNotBefore / X509GetNotAfter   - ASN1_TIME accessors
  TX509Ext.X509ASN1TimeToDateTimeUTC            - ASN1_TIME -> TDateTime
  TX509Ext.X509GetSubjectCN / X509GetIssuerCN   - common name strings
  TX509Ext.X509GetAllExtensions                 - iterate extensions (OID + raw bytes)
  TX509Ext.PKCS12ReadFromBytes                  - PFX -> X509 + PrivKey

NOTE: this unit does not compile standalone (depends on Synapse RTL via package).
Compile as part of synapse.dpk / laz_synapse.lpk.
}
unit ssl_openssl_x509_ext;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils, Classes,
  ssl_openssl3_lib,
  {$IFDEF WINDOWS}Windows{$ELSE}DynLibs{$ENDIF};

type
  {$IFNDEF FPC}
  TLibHandle = THandle;
  {$ENDIF}

  { Single extracted X509 extension - OID em texto ("2.16.76.1.3.7") + bytes
    crus do ASN1_OCTET_STRING (consumidor decide como parsear). }
  TX509Extension = record
    OID:  AnsiString;
    Data: array of Byte;
  end;

  TX509ExtensionArray = array of TX509Extension;

  EX509ExtError = class(Exception);

  TX509Ext = class
  public
    { Initialization. Idempotente. Carrega libcrypto-3 e resolve os
      ProcAddresses. Chamado automaticamente na primeira chamada a qualquer
      helper. Devolve True se DLL+exports OK. }
    class function Init: Boolean;

    { ASN1_TIME* da validade inicial. Retorna SslPtr (nao gerencia ownership;
      e ponteiro interno do cert; nao libera). }
    class function X509GetNotBefore(cert: PX509): SslPtr;

    { Idem para validade final. }
    class function X509GetNotAfter(cert: PX509): SslPtr;

    { Converte ASN1_TIME* em TDateTime UTC. Aceita generalizedTime (15 chars)
      e utcTime (13 chars). Retorna 0 se asn1Time = nil. }
    class function X509ASN1TimeToDateTimeUTC(asn1Time: SslPtr): TDateTime;

    { Le Subject CN (CommonName). Retorna '' se ausente. }
    class function X509GetSubjectCN(cert: PX509): AnsiString;

    { Le Issuer CN. Retorna '' se ausente. }
    class function X509GetIssuerCN(cert: PX509): AnsiString;

    { Itera todas as extensoes do cert e devolve array de records (OID + bytes
      crus). Synapse base e agnostico ao significado dos OIDs - consumidor
      classifica/parseia. }
    class function X509GetAllExtensions(cert: PX509): TX509ExtensionArray;

    { Le bytes PFX, decifra com senha, devolve estruturas X509 abertas.
      ATENCAO: consumidor DEVE chamar X509Free(Certificate) e
      EvpPkeyFree(PrivateKey) apos uso. CaChain pode ser nil.
      Devolve False se PKCS12_parse falhar (senha errada, PFX corrompido). }
    class function PKCS12ReadFromBytes(const ABytes: array of Byte;
                                       const APassword: AnsiString;
                                       out APrivateKey: SslPtr;
                                       out ACertificate: PX509;
                                       out ACaChain: SslPtr): Boolean;
  end;

implementation

uses
  ssl_openssl_paths;

const
  {$IFDEF WINDOWS}
  LIBCRYPTO_NAME = 'libcrypto-3-x64.dll';
  {$ELSE}
    {$IFDEF DARWIN}
    LIBCRYPTO_NAME = 'libcrypto.3.dylib';
    {$ELSE}
    LIBCRYPTO_NAME = 'libcrypto.so.3';
    {$ENDIF}
  {$ENDIF}

  NID_commonName = 13;

type
  TX509GetNotBefore_FN = function(x: PX509): SslPtr; cdecl;
  TX509GetNotAfter_FN  = function(x: PX509): SslPtr; cdecl;
  TX509GetExtCount_FN  = function(x: PX509): Integer; cdecl;
  TX509GetExt_FN       = function(x: PX509; loc: Integer): SslPtr; cdecl;
  TX509ExtensionGetObject_FN = function(ex: SslPtr): SslPtr; cdecl;
  TX509ExtensionGetData_FN   = function(ex: SslPtr): SslPtr; cdecl;
  TObjObj2Txt_FN = function(buf: PAnsiChar; buf_len: Integer; o: SslPtr; no_name: Integer): Integer; cdecl;
  TX509NameGetTextByNID_FN = function(name: PX509_NAME; nid: Integer; buf: PAnsiChar; len: Integer): Integer; cdecl;
  TASN1StringLength_FN = function(x: SslPtr): Integer; cdecl;
  TASN1StringData_FN   = function(x: SslPtr): PByte; cdecl;
  TPkcs12_FN = function(b: PBIO; p12: SslPtr): SslPtr; cdecl;
  TPkcs12Parse_FN = function(p12: SslPtr; pass: PAnsiChar; var pkey: SslPtr;
                             var cert: PX509; var ca: SslPtr): Integer; cdecl;
  TPkcs12Free_FN = procedure(p12: SslPtr); cdecl;
  TBioNewMemBuf_FN = function(buf: Pointer; len: Integer): PBIO; cdecl;
  TBioFreeAll_FN   = procedure(b: PBIO); cdecl;

var
  FInitialized: Boolean = False;
  FInitOK:      Boolean = False;
  FLibHandle:   TLibHandle = 0;

  _X509GetNotBefore:        TX509GetNotBefore_FN = nil;
  _X509GetNotAfter:         TX509GetNotAfter_FN  = nil;
  _X509GetExtCount:         TX509GetExtCount_FN  = nil;
  _X509GetExt:              TX509GetExt_FN       = nil;
  _X509ExtensionGetObject:  TX509ExtensionGetObject_FN = nil;
  _X509ExtensionGetData:    TX509ExtensionGetData_FN   = nil;
  _ObjObj2Txt:              TObjObj2Txt_FN = nil;
  _X509NameGetTextByNID:    TX509NameGetTextByNID_FN = nil;
  _ASN1StringLength:        TASN1StringLength_FN = nil;
  _ASN1StringData:          TASN1StringData_FN   = nil;
  _D2iPKCS12Bio:            TPkcs12_FN = nil;
  _PKCS12Parse:             TPkcs12Parse_FN = nil;
  _PKCS12Free:              TPkcs12Free_FN = nil;
  _BioNewMemBuf:            TBioNewMemBuf_FN = nil;
  _BioFreeAll:              TBioFreeAll_FN = nil;

{ Cross-platform LoadLibrary wrapper. }
function CslLoadLib(const AName: string): TLibHandle;
begin
  {$IFDEF FPC}
  Result := SafeLoadLibrary(AName);
  {$ELSE}
  Result := LoadLibrary(PChar(AName));
  {$ENDIF}
end;

{ Cross-platform GetProcAddress wrapper. }
function CslGetProc(AHandle: TLibHandle; const AName: AnsiString): Pointer;
begin
  {$IFDEF FPC}
  Result := DynLibs.GetProcAddress(AHandle, AName);
  {$ELSE}
  Result := Windows.GetProcAddress(AHandle, PAnsiChar(AName));
  {$ENDIF}
end;

{ Cross-platform FreeLibrary wrapper. }
procedure CslFreeLib(AHandle: TLibHandle);
begin
  {$IFDEF FPC}
  if AHandle <> 0 then UnloadLibrary(AHandle);
  {$ELSE}
  if AHandle <> 0 then FreeLibrary(AHandle);
  {$ENDIF}
end;

{ TX509Ext }

class function TX509Ext.Init: Boolean;
begin
  if FInitialized then
    Exit(FInitOK);

  FInitialized := True;
  FInitOK := False;

  try
    TOpenSSLPaths.Apply(3);
  except
    { TOpenSSLPaths.Apply pode nao estar disponivel em todos os hosts. }
  end;

  FLibHandle := CslLoadLib(LIBCRYPTO_NAME);
  if FLibHandle = 0 then
    Exit(False);

  _X509GetNotBefore := TX509GetNotBefore_FN(CslGetProc(FLibHandle, 'X509_get0_notBefore'));
  if not Assigned(_X509GetNotBefore) then
    _X509GetNotBefore := TX509GetNotBefore_FN(CslGetProc(FLibHandle, 'X509_getm_notBefore'));

  _X509GetNotAfter := TX509GetNotAfter_FN(CslGetProc(FLibHandle, 'X509_get0_notAfter'));
  if not Assigned(_X509GetNotAfter) then
    _X509GetNotAfter := TX509GetNotAfter_FN(CslGetProc(FLibHandle, 'X509_getm_notAfter'));

  _X509GetExtCount        := TX509GetExtCount_FN(CslGetProc(FLibHandle, 'X509_get_ext_count'));
  _X509GetExt             := TX509GetExt_FN(CslGetProc(FLibHandle, 'X509_get_ext'));
  _X509ExtensionGetObject := TX509ExtensionGetObject_FN(CslGetProc(FLibHandle, 'X509_EXTENSION_get_object'));
  _X509ExtensionGetData   := TX509ExtensionGetData_FN(CslGetProc(FLibHandle, 'X509_EXTENSION_get_data'));

  _ObjObj2Txt := TObjObj2Txt_FN(CslGetProc(FLibHandle, 'OBJ_obj2txt'));
  _X509NameGetTextByNID := TX509NameGetTextByNID_FN(CslGetProc(FLibHandle, 'X509_NAME_get_text_by_NID'));

  _ASN1StringLength := TASN1StringLength_FN(CslGetProc(FLibHandle, 'ASN1_STRING_length'));
  _ASN1StringData   := TASN1StringData_FN(CslGetProc(FLibHandle, 'ASN1_STRING_get0_data'));
  if not Assigned(_ASN1StringData) then
    _ASN1StringData := TASN1StringData_FN(CslGetProc(FLibHandle, 'ASN1_STRING_data'));

  _D2iPKCS12Bio := TPkcs12_FN(CslGetProc(FLibHandle, 'd2i_PKCS12_bio'));
  _PKCS12Parse  := TPkcs12Parse_FN(CslGetProc(FLibHandle, 'PKCS12_parse'));
  _PKCS12Free   := TPkcs12Free_FN(CslGetProc(FLibHandle, 'PKCS12_free'));

  _BioNewMemBuf := TBioNewMemBuf_FN(CslGetProc(FLibHandle, 'BIO_new_mem_buf'));
  _BioFreeAll   := TBioFreeAll_FN(CslGetProc(FLibHandle, 'BIO_free_all'));

  FInitOK :=
    Assigned(_X509GetNotBefore) and Assigned(_X509GetNotAfter) and
    Assigned(_X509GetExtCount)  and Assigned(_X509GetExt) and
    Assigned(_X509ExtensionGetObject) and Assigned(_X509ExtensionGetData) and
    Assigned(_ObjObj2Txt) and Assigned(_X509NameGetTextByNID) and
    Assigned(_ASN1StringLength) and Assigned(_ASN1StringData) and
    Assigned(_D2iPKCS12Bio) and Assigned(_PKCS12Parse) and Assigned(_PKCS12Free) and
    Assigned(_BioNewMemBuf) and Assigned(_BioFreeAll);

  Result := FInitOK;
end;

class function TX509Ext.X509GetNotBefore(cert: PX509): SslPtr;
begin
  if Init and Assigned(_X509GetNotBefore) and Assigned(cert) then
    Result := _X509GetNotBefore(cert)
  else
    Result := nil;
end;

class function TX509Ext.X509GetNotAfter(cert: PX509): SslPtr;
begin
  if Init and Assigned(_X509GetNotAfter) and Assigned(cert) then
    Result := _X509GetNotAfter(cert)
  else
    Result := nil;
end;

class function TX509Ext.X509ASN1TimeToDateTimeUTC(asn1Time: SslPtr): TDateTime;
var
  LLen:    Integer;
  LData:   PByte;
  LStr:    AnsiString;
  LYear, LMonth, LDay, LHour, LMin, LSec: Word;

  function Two(idx: Integer): Word;
  begin
    Result := StrToIntDef(string(Copy(LStr, idx, 2)), 0);
  end;

  function Four(idx: Integer): Word;
  begin
    Result := StrToIntDef(string(Copy(LStr, idx, 4)), 0);
  end;
begin
  Result := 0;
  if not Init or not Assigned(asn1Time) then Exit;
  if not Assigned(_ASN1StringLength) or not Assigned(_ASN1StringData) then Exit;

  LLen := _ASN1StringLength(asn1Time);
  if LLen <= 0 then Exit;

  LData := _ASN1StringData(asn1Time);
  if LData = nil then Exit;

  SetString(LStr, PAnsiChar(LData), LLen);

  if LLen >= 15 then
  begin
    LYear  := Four(1);
    LMonth := Two(5);
    LDay   := Two(7);
    LHour  := Two(9);
    LMin   := Two(11);
    LSec   := Two(13);
  end
  else if LLen >= 13 then
  begin
    LYear  := Two(1);
    if LYear < 50 then Inc(LYear, 2000) else Inc(LYear, 1900);
    LMonth := Two(3);
    LDay   := Two(5);
    LHour  := Two(7);
    LMin   := Two(9);
    LSec   := Two(11);
  end
  else
    Exit;

  if (LMonth in [1..12]) and (LDay in [1..31]) then
    try
      Result := EncodeDate(LYear, LMonth, LDay) + EncodeTime(LHour, LMin, LSec, 0);
    except
      Result := 0;
    end;
end;

class function TX509Ext.X509GetSubjectCN(cert: PX509): AnsiString;
var
  LName: PX509_NAME;
  LBuf:  array[0..511] of AnsiChar;
  LLen:  Integer;
begin
  Result := '';
  if not Init or not Assigned(cert) then Exit;
  if not Assigned(_X509NameGetTextByNID) then Exit;

  LName := X509GetSubjectName(cert);
  if not Assigned(LName) then Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  LLen := _X509NameGetTextByNID(LName, NID_commonName, @LBuf[0], SizeOf(LBuf));
  if LLen > 0 then
    SetString(Result, PAnsiChar(@LBuf[0]), LLen);
end;

class function TX509Ext.X509GetIssuerCN(cert: PX509): AnsiString;
var
  LName: PX509_NAME;
  LBuf:  array[0..511] of AnsiChar;
  LLen:  Integer;
begin
  Result := '';
  if not Init or not Assigned(cert) then Exit;
  if not Assigned(_X509NameGetTextByNID) then Exit;

  LName := X509GetIssuerName(cert);
  if not Assigned(LName) then Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  LLen := _X509NameGetTextByNID(LName, NID_commonName, @LBuf[0], SizeOf(LBuf));
  if LLen > 0 then
    SetString(Result, PAnsiChar(@LBuf[0]), LLen);
end;

class function TX509Ext.X509GetAllExtensions(cert: PX509): TX509ExtensionArray;
var
  LCount, I, LDataLen: Integer;
  LExt:    SslPtr;
  LObj:    SslPtr;
  LStr:    SslPtr;
  LBufOID: array[0..127] of AnsiChar;
  LDataPtr: PByte;
  LBytes:  array of Byte;
begin
  SetLength(Result, 0);
  if not Init or not Assigned(cert) then Exit;
  if not Assigned(_X509GetExtCount) or not Assigned(_X509GetExt) or
     not Assigned(_X509ExtensionGetObject) or not Assigned(_X509ExtensionGetData) or
     not Assigned(_ObjObj2Txt) or
     not Assigned(_ASN1StringLength) or not Assigned(_ASN1StringData) then Exit;

  LCount := _X509GetExtCount(cert);
  if LCount <= 0 then Exit;

  SetLength(Result, LCount);
  for I := 0 to LCount - 1 do
  begin
    LExt := _X509GetExt(cert, I);
    if not Assigned(LExt) then Continue;

    LObj := _X509ExtensionGetObject(LExt);
    if Assigned(LObj) then
    begin
      FillChar(LBufOID, SizeOf(LBufOID), 0);
      _ObjObj2Txt(@LBufOID[0], SizeOf(LBufOID), LObj, 1);
      SetString(Result[I].OID, PAnsiChar(@LBufOID[0]), Length(PAnsiChar(@LBufOID[0])));
    end;

    LStr := _X509ExtensionGetData(LExt);
    if Assigned(LStr) then
    begin
      LDataLen := _ASN1StringLength(LStr);
      LDataPtr := _ASN1StringData(LStr);
      if (LDataLen > 0) and Assigned(LDataPtr) then
      begin
        SetLength(LBytes, LDataLen);
        Move(LDataPtr^, LBytes[0], LDataLen);
        Result[I].Data := LBytes;
      end;
    end;
  end;
end;

class function TX509Ext.PKCS12ReadFromBytes(const ABytes: array of Byte;
  const APassword: AnsiString; out APrivateKey: SslPtr;
  out ACertificate: PX509; out ACaChain: SslPtr): Boolean;
var
  LBio: PBIO;
  LP12: SslPtr;
  LRc:  Integer;
  LPassPtr: PAnsiChar;
begin
  Result := False;
  APrivateKey := nil;
  ACertificate := nil;
  ACaChain := nil;

  if not Init then Exit;
  if Length(ABytes) = 0 then Exit;
  if not Assigned(_BioNewMemBuf) or not Assigned(_D2iPKCS12Bio) or
     not Assigned(_PKCS12Parse) or not Assigned(_PKCS12Free) or
     not Assigned(_BioFreeAll) then Exit;

  LBio := _BioNewMemBuf(@ABytes[0], Length(ABytes));
  if not Assigned(LBio) then Exit;
  try
    LP12 := _D2iPKCS12Bio(LBio, nil);
    if not Assigned(LP12) then Exit;
    try
      if APassword = '' then
        LPassPtr := nil
      else
        LPassPtr := PAnsiChar(APassword);
      LRc := _PKCS12Parse(LP12, LPassPtr, APrivateKey, ACertificate, ACaChain);
      Result := LRc = 1;
    finally
      _PKCS12Free(LP12);
    end;
  finally
    _BioFreeAll(LBio);
  end;
end;

initialization
  { Lazy init - primeira chamada a qualquer helper aciona Init. }

finalization
  CslFreeLib(FLibHandle);
  FLibHandle := 0;

end.
