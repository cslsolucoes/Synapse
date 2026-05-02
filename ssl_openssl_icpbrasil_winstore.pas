{==============================================================================|
| Project : Ararat Synapse                                       | 001.000.000 |
|==============================================================================|
| Content: Windows Certificate Store + A3 detection (S13a — v42.0)             |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
| All rights reserved.                                                         |
|==============================================================================|
| Portions adapted from ACBr (https://acbr.com.br) under GNU LGPL v2.1 terms.  |
| Specific functions adapted: GetCertIsHardware (CRYPT_IMPL_HARDWARE flag).    |
| ACBr source unit referenced: ACBrDFeWinCrypt.pas                             |
|==============================================================================|
| Reference: Microsoft CryptoAPI (Wincrypt.h) + CNG (NCryptOpenStorageProvider)|
|==============================================================================|
| History:                                                                     |
|   001.000.000 (2026-05-01): Criacao S13a. Enumeracao Windows Cert Store      |
|                             (My/CurrentUser/LocalMachine) + A3 detection     |
|                             via CRYPT_IMPL_HARDWARE/NCRYPT_IMPL_HARDWARE.    |
|==============================================================================}

(*:@abstract(Windows Certificate Store reader + A3 (token/smartcard) detection)

Cliente Windows-only para ler certificados do Windows Certificate Store
(CurrentUser/LocalMachine, store My/AddressBook). Detecta certificados em
hardware (A3 — eToken, SafeNet, Giesecke) via flag `CRYPT_IMPL_HARDWARE`
(CSP) ou `NCRYPT_IMPL_HARDWARE_FLAG` (CNG).

POSIX: stub no-op (esta unit so faz sentido em Windows).

Uso tipico:

  var
    LStore: TWinCertStore;
    LEntries: TArray<TWinCertEntry>;
    I: Integer;
  begin
    LStore := TWinCertStore.Create;
    try
      if LStore.OpenStore(slMy, slCurrentUser) then
      begin
        LEntries := LStore.EnumerateCertificates;
        for I := 0 to High(LEntries) do
          WriteLn(LEntries[I].Subject, ' | A3=', LEntries[I].IsHardware);
      end;
    finally
      LStore.Free;
    end;
  end;
*)

unit ssl_openssl_icpbrasil_winstore;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils, Classes
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

type
  TWinCertStoreLocation = (
    slMy,                 // store 'MY' (Personal)
    slAddressBook,        // store 'AddressBook'
    slCA,                 // 'CA' (Intermediate Certification Authorities)
    slRoot,               // 'ROOT' (Trusted Root Certification Authorities)
    slTrustedPublisher    // 'TrustedPublisher'
  );

  TWinCertStoreScope = (
    slCurrentUser,        // CERT_SYSTEM_STORE_CURRENT_USER
    slLocalMachine        // CERT_SYSTEM_STORE_LOCAL_MACHINE
  );

  TWinCertEntry = record
    Subject:     string;       // CN do subject
    Issuer:      string;       // CN do issuer
    Thumbprint:  string;       // SHA-1 hex uppercase
    SerialNo:    string;       // hex uppercase
    NotBefore:   TDateTime;    // UTC
    NotAfter:    TDateTime;    // UTC
    IsHardware:  Boolean;      // true se A3 (token/smartcard)
    DerBytes:    TBytes;       // DER do cert (para conversao a PX509)
  end;

  EWinCertStoreError = class(Exception);

  TWinCertStore = class
  private
    {$IFDEF MSWINDOWS}
    FStoreHandle: Pointer;
    {$ENDIF}
    FLastError: string;
  public
    constructor Create;
    destructor Destroy; override;

    { Abre o store. Devolve True em sucesso. }
    function OpenStore(ALocation: TWinCertStoreLocation;
                      AScope: TWinCertStoreScope): Boolean;
    procedure CloseStore;

    { Enumera todos os certs no store aberto. }
    function EnumerateCertificates: TArray<TWinCertEntry>;

    { Procura cert por thumbprint SHA-1 (hex uppercase, sem espacos). }
    function FindByThumbprint(const AThumbprint: string;
                             out AEntry: TWinCertEntry): Boolean;

    property LastError: string read FLastError;
  end;

  { S13 — Detecta se um cert (DER bytes) tem chave privada em hardware
    (Windows-only). Adaptado de ACBrDFeWinCrypt.GetCertIsHardware sob LGPL. }
  function IsCertificadoEmHardware(const ACertDer: TBytes): Boolean;

implementation

{$IFDEF MSWINDOWS}
const
  CERT_STORE_PROV_SYSTEM_W              = Pointer(10);
  CERT_SYSTEM_STORE_CURRENT_USER        = $00010000;
  CERT_SYSTEM_STORE_LOCAL_MACHINE       = $00020000;
  CERT_NAME_SIMPLE_DISPLAY_TYPE         = 4;
  CERT_NAME_ATTR_TYPE                   = 3;
  CERT_HASH_PROP_ID                     = 3;
  CERT_KEY_PROV_INFO_PROP_ID            = 2;
  CRYPT_IMPL_HARDWARE                   = $00000002;
  CERT_NCRYPT_KEY_HANDLE_PROP_ID        = 78;
  NCRYPT_IMPL_HARDWARE_FLAG             = $00000001;
  NCRYPT_IMPL_TYPE_PROPERTY             = 'Impl Type';
  PROV_RSA_FULL                         = 1;
  CRYPT_VERIFYCONTEXT                   = $F0000000;
  PP_IMPTYPE                            = 3;

type
  PCertContext  = Pointer;
  HCertStore    = Pointer;
  PCryptKeyProvInfo = ^TCryptKeyProvInfo;
  TCryptKeyProvInfo = record
    pwszContainerName: PWideChar;
    pwszProvName:      PWideChar;
    dwProvType:        DWORD;
    dwFlags:           DWORD;
    cProvParam:        DWORD;
    rgProvParam:       Pointer;
    dwKeySpec:         DWORD;
  end;

  TCertOpenStore = function(lpszStoreProvider: Pointer; dwEncodingType: DWORD;
    hCryptProv: Pointer; dwFlags: DWORD; pvPara: Pointer): HCertStore; stdcall;
  TCertCloseStore = function(hCertStore: HCertStore; dwFlags: DWORD): BOOL; stdcall;
  TCertEnumCertificatesInStore = function(hCertStore: HCertStore;
    pPrevContext: PCertContext): PCertContext; stdcall;
  TCertGetNameStringW = function(pCertContext: PCertContext; dwType: DWORD;
    dwFlags: DWORD; pvTypePara: Pointer; pszNameString: PWideChar;
    cchNameString: DWORD): DWORD; stdcall;
  TCertGetCertificateContextProperty = function(pCertContext: PCertContext;
    dwPropId: DWORD; pvData: Pointer; pcbData: PDWORD): BOOL; stdcall;
  TCertFreeCertificateContext = function(pCertContext: PCertContext): BOOL; stdcall;
  TCertCreateCertificateContext = function(dwCertEncodingType: DWORD;
    pbCertEncoded: PByte; cbCertEncoded: DWORD): PCertContext; stdcall;
  TCryptAcquireContextW = function(out phProv: ULONG_PTR;
    pszContainer, pszProvider: PWideChar; dwProvType, dwFlags: DWORD): BOOL; stdcall;
  TCryptGetProvParam = function(hProv: ULONG_PTR; dwParam: DWORD;
    pbData: PByte; pdwDataLen: PDWORD; dwFlags: DWORD): BOOL; stdcall;
  TCryptReleaseContext = function(hProv: ULONG_PTR; dwFlags: DWORD): BOOL; stdcall;

const
  X509_ASN_ENCODING = $00000001;
  PKCS_7_ASN_ENCODING = $00010000;
  CERT_STORE_READONLY_FLAG = $00008000;

var
  _CertOpenStore: TCertOpenStore = nil;
  _CertCloseStore: TCertCloseStore = nil;
  _CertEnumCertificatesInStore: TCertEnumCertificatesInStore = nil;
  _CertGetNameStringW: TCertGetNameStringW = nil;
  _CertGetCertificateContextProperty: TCertGetCertificateContextProperty = nil;
  _CertFreeCertificateContext: TCertFreeCertificateContext = nil;
  _CertCreateCertificateContext: TCertCreateCertificateContext = nil;
  _CryptAcquireContextW: TCryptAcquireContextW = nil;
  _CryptGetProvParam: TCryptGetProvParam = nil;
  _CryptReleaseContext: TCryptReleaseContext = nil;
  FCryptApiInit: Boolean = False;

procedure InitCryptApi;
var
  LCrypt32, LAdvapi32: HMODULE;
begin
  if FCryptApiInit then Exit;
  FCryptApiInit := True;
  LCrypt32 := LoadLibrary('Crypt32.dll');
  if LCrypt32 = 0 then Exit;
  _CertOpenStore := TCertOpenStore(GetProcAddress(LCrypt32, 'CertOpenStore'));
  _CertCloseStore := TCertCloseStore(GetProcAddress(LCrypt32, 'CertCloseStore'));
  _CertEnumCertificatesInStore := TCertEnumCertificatesInStore(GetProcAddress(LCrypt32, 'CertEnumCertificatesInStore'));
  _CertGetNameStringW := TCertGetNameStringW(GetProcAddress(LCrypt32, 'CertGetNameStringW'));
  _CertGetCertificateContextProperty := TCertGetCertificateContextProperty(GetProcAddress(LCrypt32, 'CertGetCertificateContextProperty'));
  _CertFreeCertificateContext := TCertFreeCertificateContext(GetProcAddress(LCrypt32, 'CertFreeCertificateContext'));
  _CertCreateCertificateContext := TCertCreateCertificateContext(GetProcAddress(LCrypt32, 'CertCreateCertificateContext'));
  LAdvapi32 := LoadLibrary('Advapi32.dll');
  if LAdvapi32 <> 0 then
  begin
    _CryptAcquireContextW := TCryptAcquireContextW(GetProcAddress(LAdvapi32, 'CryptAcquireContextW'));
    _CryptGetProvParam := TCryptGetProvParam(GetProcAddress(LAdvapi32, 'CryptGetProvParam'));
    _CryptReleaseContext := TCryptReleaseContext(GetProcAddress(LAdvapi32, 'CryptReleaseContext'));
  end;
end;

function _GetCertNameW(pCert: PCertContext; AIsIssuer: Boolean): string;
const
  CERT_NAME_ISSUER_FLAG = $00000001;
var
  LBuf: array[0..511] of WideChar;
  LFlags: DWORD;
begin
  Result := '';
  if not Assigned(_CertGetNameStringW) then Exit;
  if AIsIssuer then LFlags := CERT_NAME_ISSUER_FLAG else LFlags := 0;
  FillChar(LBuf, SizeOf(LBuf), 0);
  _CertGetNameStringW(pCert, CERT_NAME_SIMPLE_DISPLAY_TYPE, LFlags, nil, @LBuf[0], 512);
  Result := string(WideString(PWideChar(@LBuf[0])));
end;

function _GetCertHashSha1(pCert: PCertContext): string;
var
  LBuf: array[0..63] of Byte;
  LLen: DWORD;
  I: Integer;
begin
  Result := '';
  if not Assigned(_CertGetCertificateContextProperty) then Exit;
  LLen := SizeOf(LBuf);
  if not _CertGetCertificateContextProperty(pCert, CERT_HASH_PROP_ID, @LBuf[0], @LLen) then Exit;
  for I := 0 to Integer(LLen) - 1 do
    Result := Result + IntToHex(LBuf[I], 2);
end;

function _CertContextToDer(pCert: PCertContext): TBytes;
type
  PCertContextRec = ^TCertContextRec;
  TCertContextRec = record
    dwCertEncodingType: DWORD;
    pbCertEncoded:      PByte;
    cbCertEncoded:      DWORD;
    pCertInfo:          Pointer;
    hCertStore:         HCertStore;
  end;
var
  LRec: PCertContextRec;
begin
  SetLength(Result, 0);
  if not Assigned(pCert) then Exit;
  LRec := PCertContextRec(pCert);
  if (LRec.cbCertEncoded > 0) and Assigned(LRec.pbCertEncoded) then
  begin
    SetLength(Result, LRec.cbCertEncoded);
    Move(LRec.pbCertEncoded^, Result[0], LRec.cbCertEncoded);
  end;
end;

function _GetCertIsHardware(pCert: PCertContext): Boolean;
var
  LKpiSize: DWORD;
  LKpiBuf: array of Byte;
  LKpi: PCryptKeyProvInfo;
  LProv: ULONG_PTR;
  LImpType: DWORD;
  LLen: DWORD;
begin
  Result := False;
  if not Assigned(_CertGetCertificateContextProperty) then Exit;

  LKpiSize := 0;
  if not _CertGetCertificateContextProperty(pCert, CERT_KEY_PROV_INFO_PROP_ID, nil, @LKpiSize) then Exit;
  if LKpiSize = 0 then Exit;
  SetLength(LKpiBuf, LKpiSize);
  if not _CertGetCertificateContextProperty(pCert, CERT_KEY_PROV_INFO_PROP_ID, @LKpiBuf[0], @LKpiSize) then Exit;
  LKpi := PCryptKeyProvInfo(@LKpiBuf[0]);

  if not Assigned(_CryptAcquireContextW) or not Assigned(_CryptGetProvParam) or
     not Assigned(_CryptReleaseContext) then Exit;

  LProv := 0;
  if not _CryptAcquireContextW(LProv, LKpi.pwszContainerName, LKpi.pwszProvName,
                                LKpi.dwProvType, CRYPT_VERIFYCONTEXT) then
  begin
    { Fallback sem CRYPT_VERIFYCONTEXT — em A3 frequentemente exige PIN. }
    if not _CryptAcquireContextW(LProv, LKpi.pwszContainerName, LKpi.pwszProvName,
                                  LKpi.dwProvType, 0) then Exit;
  end;
  try
    LImpType := 0;
    LLen := SizeOf(LImpType);
    if _CryptGetProvParam(LProv, PP_IMPTYPE, @LImpType, @LLen, 0) then
      Result := (LImpType and CRYPT_IMPL_HARDWARE) <> 0;
  finally
    _CryptReleaseContext(LProv, 0);
  end;
end;
{$ENDIF}

constructor TWinCertStore.Create;
begin
  inherited;
  {$IFDEF MSWINDOWS}
  FStoreHandle := nil;
  InitCryptApi;
  {$ENDIF}
end;

destructor TWinCertStore.Destroy;
begin
  CloseStore;
  inherited;
end;

procedure TWinCertStore.CloseStore;
begin
  {$IFDEF MSWINDOWS}
  if Assigned(FStoreHandle) and Assigned(_CertCloseStore) then
    _CertCloseStore(FStoreHandle, 0);
  FStoreHandle := nil;
  {$ENDIF}
end;

function TWinCertStore.OpenStore(ALocation: TWinCertStoreLocation;
  AScope: TWinCertStoreScope): Boolean;
{$IFDEF MSWINDOWS}
var
  LName: WideString;
  LFlags: DWORD;
{$ENDIF}
begin
  Result := False;
  FLastError := '';
  {$IFDEF MSWINDOWS}
  CloseStore;
  if not Assigned(_CertOpenStore) then
  begin
    FLastError := 'Crypt32.dll CertOpenStore nao disponivel.';
    Exit;
  end;
  case ALocation of
    slMy:                LName := 'MY';
    slAddressBook:       LName := 'AddressBook';
    slCA:                LName := 'CA';
    slRoot:              LName := 'ROOT';
    slTrustedPublisher:  LName := 'TrustedPublisher';
  else
    LName := 'MY';
  end;
  case AScope of
    slCurrentUser:       LFlags := CERT_SYSTEM_STORE_CURRENT_USER;
    slLocalMachine:      LFlags := CERT_SYSTEM_STORE_LOCAL_MACHINE;
  else
    LFlags := CERT_SYSTEM_STORE_CURRENT_USER;
  end;
  LFlags := LFlags or CERT_STORE_READONLY_FLAG;
  FStoreHandle := _CertOpenStore(CERT_STORE_PROV_SYSTEM_W, 0, nil, LFlags,
                                 PWideChar(LName));
  if not Assigned(FStoreHandle) then
  begin
    FLastError := Format('CertOpenStore falhou (Win32 err %d).', [GetLastError]);
    Exit;
  end;
  Result := True;
  {$ELSE}
  FLastError := 'TWinCertStore so funciona em Windows.';
  Result := False;
  {$ENDIF}
end;

function TWinCertStore.EnumerateCertificates: TArray<TWinCertEntry>;
{$IFDEF MSWINDOWS}
var
  LCert, LPrev: PCertContext;
  LEntry: TWinCertEntry;
{$ENDIF}
begin
  SetLength(Result, 0);
  {$IFDEF MSWINDOWS}
  if not Assigned(FStoreHandle) or not Assigned(_CertEnumCertificatesInStore) then Exit;
  LPrev := nil;
  repeat
    LCert := _CertEnumCertificatesInStore(FStoreHandle, LPrev);
    if not Assigned(LCert) then Break;
    FillChar(LEntry, SizeOf(LEntry), 0);
    LEntry.Subject := _GetCertNameW(LCert, False);
    LEntry.Issuer := _GetCertNameW(LCert, True);
    LEntry.Thumbprint := _GetCertHashSha1(LCert);
    LEntry.IsHardware := _GetCertIsHardware(LCert);
    LEntry.DerBytes := _CertContextToDer(LCert);
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LEntry;
    LPrev := LCert;
  until False;
  {$ENDIF}
end;

function TWinCertStore.FindByThumbprint(const AThumbprint: string;
  out AEntry: TWinCertEntry): Boolean;
var
  LEntries: TArray<TWinCertEntry>;
  I: Integer;
  LNeedle: string;
begin
  Result := False;
  FillChar(AEntry, SizeOf(AEntry), 0);
  LNeedle := UpperCase(StringReplace(AThumbprint, ' ', '', [rfReplaceAll]));
  LEntries := EnumerateCertificates;
  for I := 0 to High(LEntries) do
    if UpperCase(LEntries[I].Thumbprint) = LNeedle then
    begin
      AEntry := LEntries[I];
      Exit(True);
    end;
end;

function IsCertificadoEmHardware(const ACertDer: TBytes): Boolean;
{$IFDEF MSWINDOWS}
var
  LCert: PCertContext;
{$ENDIF}
begin
  Result := False;
  {$IFDEF MSWINDOWS}
  InitCryptApi;
  if not Assigned(_CertCreateCertificateContext) then Exit;
  if Length(ACertDer) = 0 then Exit;
  LCert := _CertCreateCertificateContext(X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
                                         @ACertDer[0], Length(ACertDer));
  if not Assigned(LCert) then Exit;
  try
    Result := _GetCertIsHardware(LCert);
  finally
    if Assigned(_CertFreeCertificateContext) then
      _CertFreeCertificateContext(LCert);
  end;
  {$ENDIF}
end;

end.
