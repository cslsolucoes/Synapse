{==============================================================================|
| Project : Ararat Synapse                                       | 001.000.000 |
|==============================================================================|
| Content: PKCS#11 (Cryptoki v3) cross-platform loader (S13b — v42.0)          |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
| All rights reserved.                                                         |
|==============================================================================|
| Reference: PKCS #11 Cryptographic Token Interface Standard v3.0 (OASIS)      |
|==============================================================================|
| History:                                                                     |
|   001.000.000 (2026-05-01): Criacao S13b. Loader PKCS#11 cross-platform com  |
|                             auto-deteccao de drivers comuns (SoftHSM2,       |
|                             eToken, SafeNet). Enumeracao de slots, sessoes,  |
|                             objetos. Bridge para PX509 OpenSSL.              |
|==============================================================================}

(*:@abstract(PKCS#11 cross-platform loader — Cryptoki v3 standard)

Cliente PKCS#11 standalone para Linux/Windows/macOS. Carrega modulo via
dlopen/LoadLibrary, resolve `C_GetFunctionList`, expoe API tipada para
enumerar slots, abrir sessoes, listar certificados em token e ler bytes
DER (que podem ser convertidos para PX509 OpenSSL para uso pelo leitor
ICP-Brasil).

Path auto-detection (Linux):
  /usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so
  /usr/lib/softhsm/libsofthsm2.so
  /usr/lib64/libeToken.so
  /usr/lib/pkcs11/libsofthsm2.so

Path auto-detection (Windows):
  C:\Windows\SysWOW64\eTPKCS11.dll
  C:\Program Files\SafeNet\Authentication\SAC\x64\eTPKCS11.dll
  C:\Windows\System32\eTPKCS11.dll

Path auto-detection (macOS):
  /usr/local/lib/softhsm/libsofthsm2.so
  /usr/local/lib/pkcs11/

Uso tipico:

  var
    LP11: TPkcs11Loader;
    LSlots: TArray<TP11SlotInfo>;
    LCerts: TArray<TP11CertInfo>;
  begin
    LP11 := TPkcs11Loader.Create;
    try
      if LP11.AutoDetectAndLoad then
      begin
        LSlots := LP11.EnumerateSlots(True);
        if Length(LSlots) > 0 then
        begin
          LP11.OpenSession(LSlots[0].SlotId, '1234');  // PIN
          LCerts := LP11.EnumerateCertificates;
          // LCerts[I].DerBytes podem ser usados via TX509Ext / leitor
        end;
      end;
    finally
      LP11.Free;
    end;
  end;

NOTA: este modulo so faz **leitura** do cert. Assinatura via PKCS#11 (signing
remoto no token) requer integracao OpenSSL engine — deferred para S13b+.
Atual S13b cobre o caso de uso "ler cert do token e validar offline".
*)

unit ssl_openssl_icpbrasil_pkcs11;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils, Classes,
  {$IFDEF MSWINDOWS}Windows{$ELSE}DynLibs{$ENDIF};

type
  {$IFNDEF FPC}
  TLibHandle = THandle;
  {$ENDIF}

  CK_BYTE = Byte;
  CK_ULONG = NativeUInt;
  CK_RV = NativeUInt;
  CK_SLOT_ID = NativeUInt;
  CK_SESSION_HANDLE = NativeUInt;
  CK_OBJECT_HANDLE = NativeUInt;
  CK_FLAGS = NativeUInt;

  PCKVoid = Pointer;
  PCK_BYTE = ^CK_BYTE;
  PCK_ULONG = ^CK_ULONG;

  CK_ATTRIBUTE = record
    AttrType: CK_ULONG;
    pValue:   Pointer;
    ulValueLen: CK_ULONG;
  end;
  PCK_ATTRIBUTE = ^CK_ATTRIBUTE;

  TP11SlotInfo = record
    SlotId:           CK_SLOT_ID;
    Description:      string;
    Manufacturer:     string;
    HasToken:         Boolean;
    TokenLabel:       string;
    TokenSerial:      string;
    TokenManufacturer: string;
    TokenModel:       string;
  end;

  TP11CertInfo = record
    Handle:     CK_OBJECT_HANDLE;
    LabelStr:   string;
    DerBytes:   TBytes;
    SubjectRaw: TBytes;
    IdRaw:      TBytes;
  end;

  EPkcs11Error = class(Exception);

  TPkcs11Loader = class
  private
    FLibHandle:    TLibHandle;
    FFunctionList: PCKVoid;
    FInitialized:  Boolean;
    FSessionHandle: CK_SESSION_HANDLE;
    FLastError:    string;
    FModulePath:   string;

    function CallFunction(AFnIdx: Integer; const AParams: array of Pointer): CK_RV;
  public
    constructor Create;
    destructor Destroy; override;

    { Carrega modulo PKCS#11 do path. Devolve True em sucesso. }
    function LoadModule(const APath: string): Boolean;

    { Tenta auto-detectar driver instalado em paths conhecidos por SO. }
    function AutoDetectAndLoad: Boolean;

    { Inicializa Cryptoki + lista slots. AOnlyWithToken filtra slots vazios. }
    function EnumerateSlots(AOnlyWithToken: Boolean): TArray<TP11SlotInfo>;

    { Abre sessao no slot ASlotId com PIN APin (string vazia = sem login). }
    function OpenSession(ASlotId: CK_SLOT_ID; const APin: string): Boolean;

    procedure CloseSession;

    { Enumera certificados (CKO_CERTIFICATE) na sessao aberta. }
    function EnumerateCertificates: TArray<TP11CertInfo>;

    { Termina Cryptoki + descarrega modulo. }
    procedure Unload;

    property ModulePath: string read FModulePath;
    property LastError: string read FLastError;
  end;

implementation

const
  CKR_OK = $00000000;
  CKR_FUNCTION_NOT_SUPPORTED = $00000054;

  CKF_TOKEN_PRESENT = $00000001;

  CKO_CERTIFICATE = $00000001;
  CKA_CLASS = $00000000;
  CKA_LABEL = $00000003;
  CKA_VALUE = $00000011;
  CKA_SUBJECT = $00000101;
  CKA_ID = $00000102;

  CK_FN_C_INITIALIZE         = 0;
  CK_FN_C_FINALIZE           = 1;
  CK_FN_C_GET_INFO           = 2;
  CK_FN_C_GET_FUNCTION_LIST  = 3;
  CK_FN_C_GET_SLOT_LIST      = 4;
  CK_FN_C_GET_SLOT_INFO      = 5;
  CK_FN_C_GET_TOKEN_INFO     = 6;
  CK_FN_C_OPEN_SESSION       = 9;
  CK_FN_C_CLOSE_SESSION      = 10;
  CK_FN_C_LOGIN              = 12;
  CK_FN_C_LOGOUT             = 13;
  CK_FN_C_FIND_OBJECTS_INIT  = 28;
  CK_FN_C_FIND_OBJECTS       = 29;
  CK_FN_C_FIND_OBJECTS_FINAL = 30;
  CK_FN_C_GET_ATTRIBUTE_VALUE = 27;

type
  TC_GetFunctionList = function(out ppFunctionList: PCKVoid): CK_RV; cdecl;
  TC_Initialize = function(pInitArgs: Pointer): CK_RV; cdecl;
  TC_Finalize = function(pReserved: Pointer): CK_RV; cdecl;
  TC_GetSlotList = function(tokenPresent: ByteBool; pSlotList: Pointer;
                            pulCount: PCK_ULONG): CK_RV; cdecl;
  TC_GetSlotInfo = function(slotID: CK_SLOT_ID; pInfo: Pointer): CK_RV; cdecl;
  TC_GetTokenInfo = function(slotID: CK_SLOT_ID; pInfo: Pointer): CK_RV; cdecl;
  TC_OpenSession = function(slotID: CK_SLOT_ID; flags: CK_FLAGS;
                            pApp, Notify: Pointer; out phSession: CK_SESSION_HANDLE): CK_RV; cdecl;
  TC_CloseSession = function(hSession: CK_SESSION_HANDLE): CK_RV; cdecl;
  TC_Login = function(hSession: CK_SESSION_HANDLE; userType: CK_ULONG;
                      pPin: PAnsiChar; ulPinLen: CK_ULONG): CK_RV; cdecl;
  TC_Logout = function(hSession: CK_SESSION_HANDLE): CK_RV; cdecl;
  TC_FindObjectsInit = function(hSession: CK_SESSION_HANDLE;
                                pTemplate: PCK_ATTRIBUTE; ulCount: CK_ULONG): CK_RV; cdecl;
  TC_FindObjects = function(hSession: CK_SESSION_HANDLE; phObject: Pointer;
                            ulMaxCount: CK_ULONG; pulCount: PCK_ULONG): CK_RV; cdecl;
  TC_FindObjectsFinal = function(hSession: CK_SESSION_HANDLE): CK_RV; cdecl;
  TC_GetAttributeValue = function(hSession: CK_SESSION_HANDLE;
                                  hObject: CK_OBJECT_HANDLE;
                                  pTemplate: PCK_ATTRIBUTE; ulCount: CK_ULONG): CK_RV; cdecl;

  PCK_FUNCTION_LIST = ^TCK_FUNCTION_LIST_3_0;
  TCK_FUNCTION_LIST_3_0 = record
    version: array[0..1] of Byte;
    C_Initialize:         TC_Initialize;
    C_Finalize:           TC_Finalize;
    C_GetInfo:            Pointer;
    C_GetFunctionList:    Pointer;
    C_GetSlotList:        TC_GetSlotList;
    C_GetSlotInfo:        TC_GetSlotInfo;
    C_GetTokenInfo:       TC_GetTokenInfo;
    C_GetMechanismList:   Pointer;
    C_GetMechanismInfo:   Pointer;
    C_InitToken:          Pointer;
    C_InitPIN:            Pointer;
    C_SetPIN:             Pointer;
    C_OpenSession:        TC_OpenSession;
    C_CloseSession:       TC_CloseSession;
    C_CloseAllSessions:   Pointer;
    C_GetSessionInfo:     Pointer;
    C_GetOperationState:  Pointer;
    C_SetOperationState:  Pointer;
    C_Login:              TC_Login;
    C_Logout:             TC_Logout;
    C_CreateObject:       Pointer;
    C_CopyObject:         Pointer;
    C_DestroyObject:      Pointer;
    C_GetObjectSize:      Pointer;
    C_GetAttributeValue:  TC_GetAttributeValue;
    C_SetAttributeValue:  Pointer;
    C_FindObjectsInit:    TC_FindObjectsInit;
    C_FindObjects:        TC_FindObjects;
    C_FindObjectsFinal:   TC_FindObjectsFinal;
    { ... resto da struct ignorado para esta versao }
  end;

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

constructor TPkcs11Loader.Create;
begin
  inherited;
  FLibHandle := 0;
  FFunctionList := nil;
  FInitialized := False;
  FSessionHandle := 0;
end;

destructor TPkcs11Loader.Destroy;
begin
  Unload;
  inherited;
end;

function TPkcs11Loader.CallFunction(AFnIdx: Integer;
  const AParams: array of Pointer): CK_RV;
begin
  Result := CKR_FUNCTION_NOT_SUPPORTED;
  { Helper nao usado — chamada directa nas funcoes especializadas. }
end;

procedure TPkcs11Loader.Unload;
var
  LFnList: PCK_FUNCTION_LIST;
begin
  CloseSession;
  if FInitialized and Assigned(FFunctionList) then
  begin
    LFnList := PCK_FUNCTION_LIST(FFunctionList);
    if Assigned(LFnList^.C_Finalize) then
      LFnList^.C_Finalize(nil);
    FInitialized := False;
  end;
  if FLibHandle <> 0 then
    CslFreeLib(FLibHandle);
  FLibHandle := 0;
  FFunctionList := nil;
end;

function TPkcs11Loader.LoadModule(const APath: string): Boolean;
var
  LGetFnList: TC_GetFunctionList;
  LFnList: PCK_FUNCTION_LIST;
  LRv: CK_RV;
begin
  Result := False;
  Unload;
  FLastError := '';
  FModulePath := '';

  FLibHandle := CslLoadLib(APath);
  if FLibHandle = 0 then
  begin
    FLastError := 'LoadLibrary falhou: ' + APath;
    Exit;
  end;

  LGetFnList := TC_GetFunctionList(CslGetProc(FLibHandle, 'C_GetFunctionList'));
  if not Assigned(LGetFnList) then
  begin
    FLastError := 'C_GetFunctionList nao encontrado em ' + APath;
    CslFreeLib(FLibHandle);
    FLibHandle := 0;
    Exit;
  end;

  LRv := LGetFnList(FFunctionList);
  if (LRv <> CKR_OK) or not Assigned(FFunctionList) then
  begin
    FLastError := Format('C_GetFunctionList retornou CKR=%x.', [LRv]);
    CslFreeLib(FLibHandle);
    FLibHandle := 0;
    Exit;
  end;

  LFnList := PCK_FUNCTION_LIST(FFunctionList);
  LRv := LFnList^.C_Initialize(nil);
  if LRv <> CKR_OK then
  begin
    FLastError := Format('C_Initialize retornou CKR=%x.', [LRv]);
    CslFreeLib(FLibHandle);
    FLibHandle := 0;
    FFunctionList := nil;
    Exit;
  end;
  FInitialized := True;
  FModulePath := APath;
  Result := True;
end;

function TPkcs11Loader.AutoDetectAndLoad: Boolean;
const
  {$IFDEF MSWINDOWS}
  PATHS: array[0..3] of string = (
    'C:\Windows\SysWOW64\eTPKCS11.dll',
    'C:\Windows\System32\eTPKCS11.dll',
    'C:\Program Files\SafeNet\Authentication\SAC\x64\eTPKCS11.dll',
    'C:\Program Files (x86)\SafeNet\Authentication\SAC\Win32\eTPKCS11.dll'
  );
  {$ELSE}
    {$IFDEF DARWIN}
    PATHS: array[0..2] of string = (
      '/usr/local/lib/softhsm/libsofthsm2.so',
      '/Library/Frameworks/eToken.framework/Versions/Current/libeToken.dylib',
      '/usr/local/lib/pkcs11/libsofthsm2.dylib'
    );
    {$ELSE}
    PATHS: array[0..3] of string = (
      '/usr/lib/softhsm/libsofthsm2.so',
      '/usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so',
      '/usr/lib64/libeToken.so',
      '/usr/lib/pkcs11/libsofthsm2.so'
    );
    {$ENDIF}
  {$ENDIF}
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(PATHS) do
    if FileExists(PATHS[I]) then
      if LoadModule(PATHS[I]) then
        Exit(True);
  FLastError := 'Nenhum modulo PKCS#11 encontrado nos paths conhecidos.';
end;

function _TrimSpace32(const ASrc: AnsiString): string;
begin
  Result := Trim(string(ASrc));
end;

function TPkcs11Loader.EnumerateSlots(AOnlyWithToken: Boolean): TArray<TP11SlotInfo>;
var
  LFnList: PCK_FUNCTION_LIST;
  LRv: CK_RV;
  LCount: CK_ULONG;
  LSlots: array of CK_SLOT_ID;
  I: Integer;
  LSlotInfo: array[0..127] of Byte;
  LTokenInfo: array[0..255] of Byte;
  LEntry: TP11SlotInfo;
  LDescStr, LMfgStr, LLabelStr, LSerialStr, LModelStr: AnsiString;
  LSlotMfgStr: AnsiString;
begin
  SetLength(Result, 0);
  if not FInitialized then Exit;
  LFnList := PCK_FUNCTION_LIST(FFunctionList);
  if not Assigned(LFnList^.C_GetSlotList) then Exit;

  LCount := 0;
  LRv := LFnList^.C_GetSlotList(AOnlyWithToken, nil, @LCount);
  if (LRv <> CKR_OK) or (LCount = 0) then Exit;
  SetLength(LSlots, LCount);
  LRv := LFnList^.C_GetSlotList(AOnlyWithToken, @LSlots[0], @LCount);
  if LRv <> CKR_OK then Exit;

  SetLength(Result, LCount);
  for I := 0 to LCount - 1 do
  begin
    FillChar(LEntry, SizeOf(LEntry), 0);
    LEntry.SlotId := LSlots[I];

    if Assigned(LFnList^.C_GetSlotInfo) then
    begin
      FillChar(LSlotInfo, SizeOf(LSlotInfo), 0);
      if LFnList^.C_GetSlotInfo(LSlots[I], @LSlotInfo[0]) = CKR_OK then
      begin
        SetString(LDescStr, PAnsiChar(@LSlotInfo[0]), 64);
        SetString(LSlotMfgStr, PAnsiChar(@LSlotInfo[64]), 32);
        LEntry.Description := _TrimSpace32(LDescStr);
        LEntry.Manufacturer := _TrimSpace32(LSlotMfgStr);
        LEntry.HasToken := (PCardinal(@LSlotInfo[96])^ and CKF_TOKEN_PRESENT) <> 0;
      end;
    end;

    if LEntry.HasToken and Assigned(LFnList^.C_GetTokenInfo) then
    begin
      FillChar(LTokenInfo, SizeOf(LTokenInfo), 0);
      if LFnList^.C_GetTokenInfo(LSlots[I], @LTokenInfo[0]) = CKR_OK then
      begin
        SetString(LLabelStr, PAnsiChar(@LTokenInfo[0]), 32);
        SetString(LMfgStr, PAnsiChar(@LTokenInfo[32]), 32);
        SetString(LModelStr, PAnsiChar(@LTokenInfo[64]), 16);
        SetString(LSerialStr, PAnsiChar(@LTokenInfo[80]), 16);
        LEntry.TokenLabel := _TrimSpace32(LLabelStr);
        LEntry.TokenManufacturer := _TrimSpace32(LMfgStr);
        LEntry.TokenModel := _TrimSpace32(LModelStr);
        LEntry.TokenSerial := _TrimSpace32(LSerialStr);
      end;
    end;

    Result[I] := LEntry;
  end;
end;

function TPkcs11Loader.OpenSession(ASlotId: CK_SLOT_ID;
  const APin: string): Boolean;
const
  CKF_SERIAL_SESSION = $00000004;
  CKU_USER = 1;
var
  LFnList: PCK_FUNCTION_LIST;
  LRv: CK_RV;
  LPinAnsi: AnsiString;
begin
  Result := False;
  FLastError := '';
  CloseSession;
  if not FInitialized then Exit;
  LFnList := PCK_FUNCTION_LIST(FFunctionList);
  if not Assigned(LFnList^.C_OpenSession) then Exit;

  LRv := LFnList^.C_OpenSession(ASlotId, CKF_SERIAL_SESSION, nil, nil, FSessionHandle);
  if LRv <> CKR_OK then
  begin
    FLastError := Format('C_OpenSession CKR=%x', [LRv]);
    Exit;
  end;

  if (APin <> '') and Assigned(LFnList^.C_Login) then
  begin
    LPinAnsi := AnsiString(APin);
    LRv := LFnList^.C_Login(FSessionHandle, CKU_USER, PAnsiChar(LPinAnsi),
                            CK_ULONG(Length(LPinAnsi)));
    if LRv <> CKR_OK then
    begin
      FLastError := Format('C_Login CKR=%x', [LRv]);
      LFnList^.C_CloseSession(FSessionHandle);
      FSessionHandle := 0;
      Exit;
    end;
  end;
  Result := True;
end;

procedure TPkcs11Loader.CloseSession;
var
  LFnList: PCK_FUNCTION_LIST;
begin
  if FSessionHandle = 0 then Exit;
  if FInitialized and Assigned(FFunctionList) then
  begin
    LFnList := PCK_FUNCTION_LIST(FFunctionList);
    if Assigned(LFnList^.C_Logout) then
      LFnList^.C_Logout(FSessionHandle);
    if Assigned(LFnList^.C_CloseSession) then
      LFnList^.C_CloseSession(FSessionHandle);
  end;
  FSessionHandle := 0;
end;

function _GetAttribute(LFnList: PCK_FUNCTION_LIST; ASession: CK_SESSION_HANDLE;
  AObject: CK_OBJECT_HANDLE; AAttrType: CK_ULONG; out AValue: TBytes): Boolean;
var
  LAttr: CK_ATTRIBUTE;
  LRv: CK_RV;
begin
  Result := False;
  SetLength(AValue, 0);
  if not Assigned(LFnList^.C_GetAttributeValue) then Exit;

  LAttr.AttrType := AAttrType;
  LAttr.pValue := nil;
  LAttr.ulValueLen := 0;
  LRv := LFnList^.C_GetAttributeValue(ASession, AObject, @LAttr, 1);
  if (LRv <> CKR_OK) or (LAttr.ulValueLen = 0) then Exit;
  SetLength(AValue, LAttr.ulValueLen);
  LAttr.pValue := @AValue[0];
  LRv := LFnList^.C_GetAttributeValue(ASession, AObject, @LAttr, 1);
  Result := LRv = CKR_OK;
end;

function _BytesToString(const ABytes: TBytes): string;
var
  S: AnsiString;
begin
  Result := '';
  if Length(ABytes) = 0 then Exit;
  SetString(S, PAnsiChar(@ABytes[0]), Length(ABytes));
  Result := string(S);
end;

function TPkcs11Loader.EnumerateCertificates: TArray<TP11CertInfo>;
var
  LFnList: PCK_FUNCTION_LIST;
  LRv: CK_RV;
  LTemplate: array[0..0] of CK_ATTRIBUTE;
  LObjClass: CK_ULONG;
  LObjects: array[0..63] of CK_OBJECT_HANDLE;
  LFoundCount: CK_ULONG;
  I: Integer;
  LEntry: TP11CertInfo;
  LValueBytes, LLabelBytes: TBytes;
begin
  SetLength(Result, 0);
  if (FSessionHandle = 0) or not FInitialized then Exit;
  LFnList := PCK_FUNCTION_LIST(FFunctionList);
  if not Assigned(LFnList^.C_FindObjectsInit) or
     not Assigned(LFnList^.C_FindObjects) or
     not Assigned(LFnList^.C_FindObjectsFinal) then Exit;

  LObjClass := CKO_CERTIFICATE;
  LTemplate[0].AttrType := CKA_CLASS;
  LTemplate[0].pValue := @LObjClass;
  LTemplate[0].ulValueLen := SizeOf(LObjClass);

  LRv := LFnList^.C_FindObjectsInit(FSessionHandle, @LTemplate[0], 1);
  if LRv <> CKR_OK then Exit;
  try
    LFoundCount := 0;
    LRv := LFnList^.C_FindObjects(FSessionHandle, @LObjects[0], 64, @LFoundCount);
    if LRv <> CKR_OK then Exit;
    SetLength(Result, LFoundCount);
    for I := 0 to LFoundCount - 1 do
    begin
      FillChar(LEntry, SizeOf(LEntry), 0);
      LEntry.Handle := LObjects[I];
      if _GetAttribute(LFnList, FSessionHandle, LObjects[I], CKA_VALUE, LValueBytes) then
        LEntry.DerBytes := LValueBytes;
      if _GetAttribute(LFnList, FSessionHandle, LObjects[I], CKA_LABEL, LLabelBytes) then
        LEntry.LabelStr := _BytesToString(LLabelBytes);
      _GetAttribute(LFnList, FSessionHandle, LObjects[I], CKA_SUBJECT, LEntry.SubjectRaw);
      _GetAttribute(LFnList, FSessionHandle, LObjects[I], CKA_ID, LEntry.IdRaw);
      Result[I] := LEntry;
    end;
  finally
    LFnList^.C_FindObjectsFinal(FSessionHandle);
  end;
end;

end.
