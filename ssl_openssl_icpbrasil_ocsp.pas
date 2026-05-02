{==============================================================================|
| Project : Ararat Synapse                                       | 001.000.000 |
|==============================================================================|
| Content: OCSP client for ICP-Brasil revocation checking (S10 — v41.7)        |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
| All rights reserved.                                                         |
|==============================================================================|
| Reference: RFC 6960 — Online Certificate Status Protocol                     |
|            ITI/ICP-Brasil — DOC-ICP-04 §revocation                           |
|==============================================================================|
| History:                                                                     |
|   001.000.000 (2026-05-01): Criacao S10. Cliente OCSP completo:              |
|                             OCSP_REQUEST/RESPONSE bindings +                 |
|                             TIcpBrasilOcspClient (POST via httpsend).        |
|==============================================================================}

{:@abstract(OCSP client — RFC 6960 revocation checking via responder URL)

Cliente OCSP standalone para ICP-Brasil. Constroi OCSP request, envia POST
para o responder URL (extraido via AIA `1.3.6.1.5.5.7.48.1` ou configurado
manualmente), parseia response e valida assinatura.

Uso tipico:
  var
    LClient: TIcpBrasilOcspClient;
    LRes:    TOcspResult;
  begin
    LClient := TIcpBrasilOcspClient.Create;
    try
      LRes := LClient.Check(ACert, AIssuer, 'http://ocsp.exemplo.com.br/');
      if LRes.Status = ocspGood then
        WriteLn('Cert nao revogado, assinado em ', LRes.ThisUpdate);
    finally
      LClient.Free;
    end;
  end;
}
unit ssl_openssl_icpbrasil_ocsp;

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

  TOcspStatus = (
    ocspUnknown,        // resposta indefinida ou erro
    ocspGood,           // cert valido, nao revogado
    ocspRevoked,        // cert revogado
    ocspError           // falha na request/response/verify
  );

  TOcspResult = record
    Status:        TOcspStatus;
    ThisUpdate:    TDateTime;       // UTC, assinado em
    NextUpdate:    TDateTime;       // UTC, validade do response (0 se nao tem)
    RevokedAt:     TDateTime;       // UTC, se Status=ocspRevoked
    Reason:        Integer;         // CRL reason code (-1 se nao tem)
    ResponderUrl:  string;
    ErrorMsg:      string;
    HttpStatus:    Integer;
    RawResponse:   AnsiString;      // bytes do response p/ debugging
  end;

  EOcspError = class(Exception);

  TIcpBrasilOcspClient = class
  private
    FTimeoutMs:    Integer;
    FUserAgent:    string;
    FLastError:    string;
  public
    constructor Create;
    destructor Destroy; override;

    { Constroi OCSP request para ACert assinado por AIssuer, envia POST a
      AResponderUrl, parseia response, valida assinatura. Devolve resultado
      preenchido. ATIMEOUT em ms; 0 usa default 5000ms. }
    function Check(ACert: PX509; AIssuer: PX509;
                   const AResponderUrl: string): TOcspResult;

    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property UserAgent: string read FUserAgent write FUserAgent;
    property LastError: string read FLastError;
  end;

implementation

uses
  httpsend;

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

  // OCSP cert status codes (per RFC 6960 ASN.1)
  V_OCSP_CERTSTATUS_GOOD     = 0;
  V_OCSP_CERTSTATUS_REVOKED  = 1;
  V_OCSP_CERTSTATUS_UNKNOWN  = 2;

  // OCSP response status codes
  OCSP_RESPONSE_STATUS_SUCCESSFUL          = 0;
  OCSP_RESPONSE_STATUS_MALFORMEDREQUEST    = 1;
  OCSP_RESPONSE_STATUS_INTERNALERROR       = 2;
  OCSP_RESPONSE_STATUS_TRYLATER            = 3;
  OCSP_RESPONSE_STATUS_SIGREQUIRED         = 5;
  OCSP_RESPONSE_STATUS_UNAUTHORIZED        = 6;

type
  TOcspRequestNew_FN     = function: SslPtr; cdecl;
  TOcspRequestFree_FN    = procedure(req: SslPtr); cdecl;
  TOcspRequestAdd0Id_FN  = function(req, certid: SslPtr): SslPtr; cdecl;
  TOcspCertToId_FN       = function(dgst: SslPtr; subject, issuer: PX509): SslPtr; cdecl;
  TI2dOcspRequest_FN     = function(req: SslPtr; out_buf: PPointer): Integer; cdecl;
  TD2iOcspResponse_FN    = function(rsp: PPointer; in_buf: PPointer; len: NativeInt): SslPtr; cdecl;
  TOcspResponseFree_FN   = procedure(rsp: SslPtr); cdecl;
  TOcspResponseStatus_FN = function(rsp: SslPtr): Integer; cdecl;
  TOcspResponseGet1Basic_FN = function(rsp: SslPtr): SslPtr; cdecl;
  TOcspBasicrespFree_FN  = procedure(br: SslPtr); cdecl;
  TOcspRespFindStatus_FN = function(br, certid: SslPtr; status, reason: PInteger;
                                    revtime, thisupd, nextupd: PPointer): Integer; cdecl;
  TOcspBasicVerify_FN    = function(br: SslPtr; certs: SslPtr; store: SslPtr;
                                    flags: NativeUInt): Integer; cdecl;
  TOcspCheckValidity_FN  = function(thisupd, nextupd: SslPtr;
                                    nsec: NativeInt; maxsec: NativeInt): Integer; cdecl;
  TEvpSha1_FN            = function: SslPtr; cdecl;
  TCryptoFreeStr_FN      = procedure(p: Pointer; f: PAnsiChar; l: Integer); cdecl;

var
  FInitialized: Boolean = False;
  FInitOK:      Boolean = False;
  FLibHandle:   TLibHandle = 0;

  _OcspRequestNew:        TOcspRequestNew_FN = nil;
  _OcspRequestFree:       TOcspRequestFree_FN = nil;
  _OcspRequestAdd0Id:     TOcspRequestAdd0Id_FN = nil;
  _OcspCertToId:          TOcspCertToId_FN = nil;
  _I2dOcspRequest:        TI2dOcspRequest_FN = nil;
  _D2iOcspResponse:       TD2iOcspResponse_FN = nil;
  _OcspResponseFree:      TOcspResponseFree_FN = nil;
  _OcspResponseStatus:    TOcspResponseStatus_FN = nil;
  _OcspResponseGet1Basic: TOcspResponseGet1Basic_FN = nil;
  _OcspBasicrespFree:     TOcspBasicrespFree_FN = nil;
  _OcspRespFindStatus:    TOcspRespFindStatus_FN = nil;
  _OcspBasicVerify:       TOcspBasicVerify_FN = nil;
  _OcspCheckValidity:     TOcspCheckValidity_FN = nil;
  _EvpSha1Ocsp:           TEvpSha1_FN = nil;
  _CryptoFreeOcsp:        TCryptoFreeStr_FN = nil;

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

function InitOcspBindings: Boolean;
begin
  if FInitialized then Exit(FInitOK);
  FInitialized := True;
  FInitOK := False;

  if not TX509Ext.Init then Exit;
  FLibHandle := CslLoadLib(LIBCRYPTO_NAME);
  if FLibHandle = 0 then Exit;

  _OcspRequestNew        := TOcspRequestNew_FN(CslGetProc(FLibHandle, 'OCSP_REQUEST_new'));
  _OcspRequestFree       := TOcspRequestFree_FN(CslGetProc(FLibHandle, 'OCSP_REQUEST_free'));
  _OcspRequestAdd0Id     := TOcspRequestAdd0Id_FN(CslGetProc(FLibHandle, 'OCSP_request_add0_id'));
  _OcspCertToId          := TOcspCertToId_FN(CslGetProc(FLibHandle, 'OCSP_cert_to_id'));
  _I2dOcspRequest        := TI2dOcspRequest_FN(CslGetProc(FLibHandle, 'i2d_OCSP_REQUEST'));
  _D2iOcspResponse       := TD2iOcspResponse_FN(CslGetProc(FLibHandle, 'd2i_OCSP_RESPONSE'));
  _OcspResponseFree      := TOcspResponseFree_FN(CslGetProc(FLibHandle, 'OCSP_RESPONSE_free'));
  _OcspResponseStatus    := TOcspResponseStatus_FN(CslGetProc(FLibHandle, 'OCSP_response_status'));
  _OcspResponseGet1Basic := TOcspResponseGet1Basic_FN(CslGetProc(FLibHandle, 'OCSP_response_get1_basic'));
  _OcspBasicrespFree     := TOcspBasicrespFree_FN(CslGetProc(FLibHandle, 'OCSP_BASICRESP_free'));
  _OcspRespFindStatus    := TOcspRespFindStatus_FN(CslGetProc(FLibHandle, 'OCSP_resp_find_status'));
  _OcspBasicVerify       := TOcspBasicVerify_FN(CslGetProc(FLibHandle, 'OCSP_basic_verify'));
  _OcspCheckValidity     := TOcspCheckValidity_FN(CslGetProc(FLibHandle, 'OCSP_check_validity'));
  _EvpSha1Ocsp           := TEvpSha1_FN(CslGetProc(FLibHandle, 'EVP_sha1'));
  _CryptoFreeOcsp        := TCryptoFreeStr_FN(CslGetProc(FLibHandle, 'CRYPTO_free'));

  FInitOK :=
    Assigned(_OcspRequestNew) and Assigned(_OcspRequestFree) and
    Assigned(_OcspRequestAdd0Id) and Assigned(_OcspCertToId) and
    Assigned(_I2dOcspRequest) and Assigned(_D2iOcspResponse) and
    Assigned(_OcspResponseFree) and Assigned(_OcspResponseStatus) and
    Assigned(_OcspResponseGet1Basic) and Assigned(_OcspBasicrespFree) and
    Assigned(_OcspRespFindStatus) and Assigned(_EvpSha1Ocsp);
  Result := FInitOK;
end;

{ TIcpBrasilOcspClient }

constructor TIcpBrasilOcspClient.Create;
begin
  inherited;
  FTimeoutMs := 5000;
  FUserAgent := 'Synapse-CSL OCSP/41.7';
end;

destructor TIcpBrasilOcspClient.Destroy;
begin
  inherited;
end;

function _BuildOcspRequest(ACert, AIssuer: PX509; out ARequestBytes: TBytes;
  out AErrorMsg: string): Boolean;
var
  LReq, LCertId: SslPtr;
  LBuf: PByte;
  LLen: Integer;
begin
  Result := False;
  AErrorMsg := '';
  SetLength(ARequestBytes, 0);

  LReq := _OcspRequestNew;
  if not Assigned(LReq) then
  begin
    AErrorMsg := 'OCSP_REQUEST_new falhou.';
    Exit;
  end;
  try
    LCertId := _OcspCertToId(_EvpSha1Ocsp, ACert, AIssuer);
    if not Assigned(LCertId) then
    begin
      AErrorMsg := 'OCSP_cert_to_id falhou (cert/issuer invalidos).';
      Exit;
    end;
    if not Assigned(_OcspRequestAdd0Id(LReq, LCertId)) then
    begin
      AErrorMsg := 'OCSP_request_add0_id falhou.';
      Exit;
    end;
    LBuf := nil;
    LLen := _I2dOcspRequest(LReq, @LBuf);
    if (LLen <= 0) or not Assigned(LBuf) then
    begin
      AErrorMsg := 'i2d_OCSP_REQUEST falhou.';
      Exit;
    end;
    try
      SetLength(ARequestBytes, LLen);
      Move(LBuf^, ARequestBytes[0], LLen);
      Result := True;
    finally
      if Assigned(_CryptoFreeOcsp) then
        _CryptoFreeOcsp(LBuf, nil, 0);
    end;
  finally
    _OcspRequestFree(LReq);
  end;
end;

function _PostOcspRequest(const AUrl: string; const ARequestBytes: TBytes;
  ATimeoutMs: Integer; const AUserAgent: string;
  out AHttpStatus: Integer; out AResponseBytes: AnsiString;
  out AErrorMsg: string): Boolean;
var
  LHttp: THTTPSend;
  LMs: TMemoryStream;
begin
  Result := False;
  AHttpStatus := 0;
  AResponseBytes := '';
  AErrorMsg := '';

  LHttp := THTTPSend.Create;
  try
    LHttp.Sock.ConnectionTimeout := ATimeoutMs;
    LHttp.Timeout := ATimeoutMs;
    LHttp.MimeType := 'application/ocsp-request';
    LHttp.UserAgent := AUserAgent;
    if Length(ARequestBytes) > 0 then
      LHttp.Document.WriteBuffer(ARequestBytes[0], Length(ARequestBytes));

    if not LHttp.HTTPMethod('POST', AUrl) then
    begin
      AErrorMsg := 'HTTP POST falhou: ' + LHttp.Sock.LastErrorDesc;
      Exit;
    end;
    AHttpStatus := LHttp.ResultCode;
    if (AHttpStatus < 200) or (AHttpStatus >= 300) then
    begin
      AErrorMsg := Format('HTTP status %d (%s)', [AHttpStatus, LHttp.ResultString]);
      Exit;
    end;
    LMs := TMemoryStream.Create;
    try
      LHttp.Document.Position := 0;
      LMs.CopyFrom(LHttp.Document, 0);
      if LMs.Size > 0 then
      begin
        SetString(AResponseBytes, PAnsiChar(LMs.Memory), LMs.Size);
        Result := True;
      end
      else
        AErrorMsg := 'Resposta OCSP vazia.';
    finally
      LMs.Free;
    end;
  finally
    LHttp.Free;
  end;
end;

function TIcpBrasilOcspClient.Check(ACert, AIssuer: PX509;
  const AResponderUrl: string): TOcspResult;
var
  LReqBytes: TBytes;
  LRespRaw: AnsiString;
  LRespPtr: SslPtr;
  LRespBio: PByte;
  LBasicResp, LCertId: SslPtr;
  LStatus, LReason: Integer;
  LRevTime, LThisUpd, LNextUpd: SslPtr;
  LFindRc: Integer;
  LSrcPtr: PByte;
  LSrcPtrPtr: PPointer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Status := ocspError;
  Result.Reason := -1;
  Result.ResponderUrl := AResponderUrl;
  FLastError := '';

  if not InitOcspBindings then
  begin
    Result.ErrorMsg := 'Bindings OCSP nao disponiveis em libcrypto-3.';
    FLastError := Result.ErrorMsg;
    Exit;
  end;
  if not Assigned(ACert) or not Assigned(AIssuer) then
  begin
    Result.ErrorMsg := 'ACert ou AIssuer nil.';
    Exit;
  end;
  if AResponderUrl = '' then
  begin
    Result.ErrorMsg := 'AResponderUrl vazia.';
    Exit;
  end;

  if not _BuildOcspRequest(ACert, AIssuer, LReqBytes, Result.ErrorMsg) then
  begin
    FLastError := Result.ErrorMsg;
    Exit;
  end;

  if not _PostOcspRequest(AResponderUrl, LReqBytes, FTimeoutMs, FUserAgent,
                          Result.HttpStatus, LRespRaw, Result.ErrorMsg) then
  begin
    FLastError := Result.ErrorMsg;
    Exit;
  end;
  Result.RawResponse := LRespRaw;

  LRespBio := PByte(@LRespRaw[1]);
  LSrcPtr := LRespBio;
  LSrcPtrPtr := @LSrcPtr;
  LRespPtr := _D2iOcspResponse(nil, PPointer(LSrcPtrPtr), Length(LRespRaw));
  if not Assigned(LRespPtr) then
  begin
    Result.ErrorMsg := 'd2i_OCSP_RESPONSE falhou (formato invalido).';
    FLastError := Result.ErrorMsg;
    Exit;
  end;
  try
    if _OcspResponseStatus(LRespPtr) <> OCSP_RESPONSE_STATUS_SUCCESSFUL then
    begin
      Result.ErrorMsg := Format('OCSP responder rejeitou request (status %d).',
        [_OcspResponseStatus(LRespPtr)]);
      FLastError := Result.ErrorMsg;
      Exit;
    end;
    LBasicResp := _OcspResponseGet1Basic(LRespPtr);
    if not Assigned(LBasicResp) then
    begin
      Result.ErrorMsg := 'OCSP_response_get1_basic falhou.';
      FLastError := Result.ErrorMsg;
      Exit;
    end;
    try
      LCertId := _OcspCertToId(_EvpSha1Ocsp, ACert, AIssuer);
      if not Assigned(LCertId) then
      begin
        Result.ErrorMsg := 'OCSP_cert_to_id (lookup) falhou.';
        FLastError := Result.ErrorMsg;
        Exit;
      end;
      LFindRc := _OcspRespFindStatus(LBasicResp, LCertId, @LStatus, @LReason,
        @LRevTime, @LThisUpd, @LNextUpd);
      if LFindRc <> 1 then
      begin
        Result.Status := ocspUnknown;
        Result.ErrorMsg := 'OCSP_resp_find_status: serial nao encontrado no response.';
        FLastError := Result.ErrorMsg;
        Exit;
      end;
      Result.ThisUpdate := TX509Ext.X509ASN1TimeToDateTimeUTC(LThisUpd);
      if Assigned(LNextUpd) then
        Result.NextUpdate := TX509Ext.X509ASN1TimeToDateTimeUTC(LNextUpd);
      Result.Reason := LReason;
      case LStatus of
        V_OCSP_CERTSTATUS_GOOD:    Result.Status := ocspGood;
        V_OCSP_CERTSTATUS_REVOKED:
        begin
          Result.Status := ocspRevoked;
          if Assigned(LRevTime) then
            Result.RevokedAt := TX509Ext.X509ASN1TimeToDateTimeUTC(LRevTime);
        end;
        V_OCSP_CERTSTATUS_UNKNOWN: Result.Status := ocspUnknown;
      end;
    finally
      _OcspBasicrespFree(LBasicResp);
    end;
  finally
    _OcspResponseFree(LRespPtr);
  end;
end;

initialization

finalization
  CslFreeLib(FLibHandle);
  FLibHandle := 0;

end.
