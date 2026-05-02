{==============================================================================|
| Project : Ararat Synapse                                       | 001.001.000 |
|==============================================================================|
| Content: X509 extensions companion unit (cross-platform PFX/X509 reader)     |
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
|==============================================================================|
| History: see HISTORY.HTM from distribution package                           |
|          (Found at URL: http://www.ararat.cz/synapse/)                       |
|==============================================================================}

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
  {$IFDEF MSWINDOWS}Windows{$ELSE}DynLibs{$ENDIF};

type
  {$IFNDEF FPC}
  TLibHandle = THandle;
  {$ENDIF}

  { Bytes brutos extraidos de ASN1_OCTET_STRING. Tipo nomeado para evitar
    incompatibilidade com array of Byte local em atribuicoes. }
  TX509RawBytes = array of Byte;

  { Single extracted X509 extension - OID em texto ("2.16.76.1.3.7") + bytes
    crus do ASN1_OCTET_STRING (consumidor decide como parsear). }
  TX509Extension = record
    OID:  AnsiString;
    Data: TX509RawBytes;
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

    { Le Subject O (organizationName, NID=17). '' se ausente. }
    class function X509GetSubjectO(cert: PX509): AnsiString;

    { Le Issuer O (organizationName, NID=17). '' se ausente. Util para
      identificar a Certificadora (AC) emissora em ICP-Brasil. }
    class function X509GetIssuerO(cert: PX509): AnsiString;

    { Numero de serie em decimal (string). '' se cert nil ou erro. }
    class function X509GetSerialNumberDec(cert: PX509): string;

    { Numero de serie em hexadecimal uppercase, sem separadores. '' em erro. }
    class function X509GetSerialNumberHex(cert: PX509): string;

    { Thumbprint SHA1 do DER em hexadecimal uppercase. '' em erro. }
    class function X509GetThumbprintSHA1(cert: PX509): string;

    { Thumbprint SHA256 do DER em hexadecimal uppercase. '' em erro. }
    class function X509GetThumbprintSHA256(cert: PX509): string;

    { Cert em DER (binario) bytes. Vazio em erro. }
    class function X509GetDERBytes(cert: PX509): TX509RawBytes;

    { Cert em DER codificado em Base64 (sem newlines, sem PEM headers). }
    class function X509GetDERBase64(cert: PX509): string;

    { Versao X509 (X509_get_version retorna long: 0=v1, 1=v2, 2=v3). }
    class function X509GetVersion(cert: PX509): Integer;
  end;

implementation

uses
  ssl_openssl_paths,
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

  NID_commonName       = 13;
  NID_organizationName = 17;

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
  TX509GetSerialNumber_FN = function(x: PX509): SslPtr; cdecl;
  { OpenSSL X509_get_version returns C long. On Windows even x64 long is 32-bit
    (LLP64); on Linux/macOS x64 long is 64-bit (LP64). X509 version values are
    0..2 in practice so reading low 32 bits via NativeInt is sufficient and
    works on both ABIs. }
  TX509GetVersion_FN      = function(x: PX509): NativeInt; cdecl;
  TX509Digest_FN          = function(data: PX509; md_type: SslPtr;
                                     md: PByte; var md_len: Cardinal): Integer; cdecl;
  TEvpGetDigestByName_FN  = function(name: PAnsiChar): SslPtr; cdecl;
  TI2dX509_FN             = function(x: PX509; out_buf: PPointer): Integer; cdecl;
  TI2dAsn1Integer_FN      = function(a: SslPtr; out_buf: PPointer): Integer; cdecl;
  TBnBin2Bn_FN            = function(s: PByte; len: Integer; ret: SslPtr): SslPtr; cdecl;
  TBnBn2Dec_FN            = function(a: SslPtr): PAnsiChar; cdecl;
  TBnBn2Hex_FN            = function(a: SslPtr): PAnsiChar; cdecl;
  TBnFree_FN              = procedure(a: SslPtr); cdecl;
  TCryptoFree_FN          = procedure(addr: Pointer; file_: PAnsiChar; line: Integer); cdecl;
  TAsn1IntegerToBn_FN     = function(ai: SslPtr; bn: SslPtr): SslPtr; cdecl;
  TEvpMdNullary_FN        = function: SslPtr; cdecl;

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
  _X509GetSerialNumber:     TX509GetSerialNumber_FN = nil;
  _X509GetVersion:          TX509GetVersion_FN = nil;
  _X509Digest:              TX509Digest_FN = nil;
  _EvpSha1:                 TEvpMdNullary_FN = nil;
  _EvpSha256:               TEvpMdNullary_FN = nil;
  _I2dX509:                 TI2dX509_FN = nil;
  _Asn1IntegerToBn:         TAsn1IntegerToBn_FN = nil;
  _BnBn2Dec:                TBnBn2Dec_FN = nil;
  _BnBn2Hex:                TBnBn2Hex_FN = nil;
  _BnFree:                  TBnFree_FN = nil;
  _CryptoFree:              TCryptoFree_FN = nil;

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
  {$IFDEF MSWINDOWS}
  Result := Windows.GetProcAddress(AHandle, PAnsiChar(AName));
  {$ELSE}
  Result := DynLibs.GetProcAddress(AHandle, AName);
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

  { Optional new bindings — only fail Init if essentials missing.
    These power Serial/Thumbprint/DER/Version helpers but are not
    required for basic LerDoPfx flow. }
  _X509GetSerialNumber := TX509GetSerialNumber_FN(CslGetProc(FLibHandle, 'X509_get_serialNumber'));
  _X509GetVersion      := TX509GetVersion_FN(CslGetProc(FLibHandle, 'X509_get_version'));
  _X509Digest          := TX509Digest_FN(CslGetProc(FLibHandle, 'X509_digest'));
  _EvpSha1             := TEvpMdNullary_FN(CslGetProc(FLibHandle, 'EVP_sha1'));
  _EvpSha256           := TEvpMdNullary_FN(CslGetProc(FLibHandle, 'EVP_sha256'));
  _I2dX509             := TI2dX509_FN(CslGetProc(FLibHandle, 'i2d_X509'));
  _Asn1IntegerToBn     := TAsn1IntegerToBn_FN(CslGetProc(FLibHandle, 'ASN1_INTEGER_to_BN'));
  _BnBn2Dec            := TBnBn2Dec_FN(CslGetProc(FLibHandle, 'BN_bn2dec'));
  _BnBn2Hex            := TBnBn2Hex_FN(CslGetProc(FLibHandle, 'BN_bn2hex'));
  _BnFree              := TBnFree_FN(CslGetProc(FLibHandle, 'BN_free'));
  _CryptoFree          := TCryptoFree_FN(CslGetProc(FLibHandle, 'CRYPTO_free'));

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
  LBytes:  TX509RawBytes;
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

function _X509GetNameTextByNID(cert: PX509; AIsIssuer: Boolean;
  ANID: Integer): AnsiString;
var
  LName: PX509_NAME;
  LBuf:  array[0..511] of AnsiChar;
  LLen:  Integer;
begin
  Result := '';
  if not Assigned(cert) then Exit;
  if not Assigned(_X509NameGetTextByNID) then Exit;

  if AIsIssuer then
    LName := X509GetIssuerName(cert)
  else
    LName := X509GetSubjectName(cert);
  if not Assigned(LName) then Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  LLen := _X509NameGetTextByNID(LName, ANID, @LBuf[0], SizeOf(LBuf));
  if LLen > 0 then
    SetString(Result, PAnsiChar(@LBuf[0]), LLen);
end;

class function TX509Ext.X509GetSubjectO(cert: PX509): AnsiString;
begin
  if not Init then
    Exit('');
  Result := _X509GetNameTextByNID(cert, False, NID_organizationName);
end;

class function TX509Ext.X509GetIssuerO(cert: PX509): AnsiString;
begin
  if not Init then
    Exit('');
  Result := _X509GetNameTextByNID(cert, True, NID_organizationName);
end;

function _SerialToBN(cert: PX509): SslPtr;
var
  LSerial: SslPtr;
begin
  Result := nil;
  if not Assigned(_X509GetSerialNumber) or not Assigned(_Asn1IntegerToBn) then
    Exit;
  LSerial := _X509GetSerialNumber(cert);
  if not Assigned(LSerial) then Exit;
  Result := _Asn1IntegerToBn(LSerial, nil);
end;

function _CopyAndFreeOpenSSLString(P: PAnsiChar): string;
begin
  Result := '';
  if P = nil then Exit;
  Result := string(AnsiString(P));
  if Assigned(_CryptoFree) then
    _CryptoFree(P, nil, 0);
end;

class function TX509Ext.X509GetSerialNumberDec(cert: PX509): string;
var
  LBN: SslPtr;
  LStr: PAnsiChar;
begin
  Result := '';
  if not Init or not Assigned(cert) then Exit;
  if not Assigned(_BnBn2Dec) or not Assigned(_BnFree) then Exit;

  LBN := _SerialToBN(cert);
  if not Assigned(LBN) then Exit;
  try
    LStr := _BnBn2Dec(LBN);
    Result := _CopyAndFreeOpenSSLString(LStr);
  finally
    _BnFree(LBN);
  end;
end;

class function TX509Ext.X509GetSerialNumberHex(cert: PX509): string;
var
  LBN: SslPtr;
  LStr: PAnsiChar;
begin
  Result := '';
  if not Init or not Assigned(cert) then Exit;
  if not Assigned(_BnBn2Hex) or not Assigned(_BnFree) then Exit;

  LBN := _SerialToBN(cert);
  if not Assigned(LBN) then Exit;
  try
    LStr := _BnBn2Hex(LBN);
    Result := UpperCase(_CopyAndFreeOpenSSLString(LStr));
  finally
    _BnFree(LBN);
  end;
end;

function _BytesToHexUpper(const ABytes: array of Byte; ALen: Integer): string;
const
  HEXCHARS: array[0..15] of Char =
    ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
var
  I: Integer;
  S: string;
begin
  SetLength(S, ALen * 2);
  for I := 0 to ALen - 1 do
  begin
    S[I * 2 + 1] := HEXCHARS[(ABytes[I] shr 4) and $F];
    S[I * 2 + 2] := HEXCHARS[ABytes[I] and $F];
  end;
  Result := S;
end;

function _DigestX509(cert: PX509; AMd: SslPtr): string;
var
  LBuf: array[0..63] of Byte;
  LLen: Cardinal;
begin
  Result := '';
  if not Assigned(_X509Digest) or not Assigned(AMd) or not Assigned(cert) then
    Exit;
  FillChar(LBuf, SizeOf(LBuf), 0);
  LLen := SizeOf(LBuf);
  if _X509Digest(cert, AMd, @LBuf[0], LLen) <> 1 then Exit;
  if LLen = 0 then Exit;
  Result := _BytesToHexUpper(LBuf, Integer(LLen));
end;

class function TX509Ext.X509GetThumbprintSHA1(cert: PX509): string;
begin
  Result := '';
  if not Init then Exit;
  if not Assigned(_EvpSha1) then Exit;
  Result := _DigestX509(cert, _EvpSha1());
end;

class function TX509Ext.X509GetThumbprintSHA256(cert: PX509): string;
begin
  Result := '';
  if not Init then Exit;
  if not Assigned(_EvpSha256) then Exit;
  Result := _DigestX509(cert, _EvpSha256());
end;

class function TX509Ext.X509GetDERBytes(cert: PX509): TX509RawBytes;
var
  LLen: Integer;
  LBuf: PByte;
  LBufStart: PByte;
begin
  SetLength(Result, 0);
  if not Init or not Assigned(cert) then Exit;
  if not Assigned(_I2dX509) or not Assigned(_CryptoFree) then Exit;

  LBuf := nil;
  LLen := _I2dX509(cert, @LBuf);
  if (LLen <= 0) or not Assigned(LBuf) then Exit;
  LBufStart := LBuf;
  try
    SetLength(Result, LLen);
    Move(LBufStart^, Result[0], LLen);
  finally
    _CryptoFree(LBufStart, nil, 0);
  end;
end;

class function TX509Ext.X509GetDERBase64(cert: PX509): string;
var
  LBytes: TX509RawBytes;
  LRaw: AnsiString;
begin
  Result := '';
  LBytes := X509GetDERBytes(cert);
  if Length(LBytes) = 0 then Exit;
  SetString(LRaw, PAnsiChar(@LBytes[0]), Length(LBytes));
  Result := string(synacode.EncodeBase64(LRaw));
end;

class function TX509Ext.X509GetVersion(cert: PX509): Integer;
begin
  Result := 0;
  if not Init or not Assigned(cert) then Exit;
  if not Assigned(_X509GetVersion) then Exit;
  Result := Integer(_X509GetVersion(cert));
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
