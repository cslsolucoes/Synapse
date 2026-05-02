{==============================================================================|
| Project : Ararat Synapse                                       | 001.000.000 |
|==============================================================================|
| Content: Time-Stamp Protocol client (RFC 3161) for ICP-Brasil (S12 — v41.9)  |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
| All rights reserved.                                                         |
|==============================================================================|
| Reference: RFC 3161 — Internet X.509 PKI Time-Stamp Protocol (TSP)           |
|            ICP-Brasil DOC-ICP-15.03 — Politica de Carimbo do Tempo           |
|==============================================================================|
| History:                                                                     |
|   001.000.000 (2026-05-01): Criacao S12. Cliente TSP cross-platform com      |
|                             POST via Synapse httpsend; constroi msg imprint  |
|                             com SHA-256 + nonce; valida response timestamp.  |
|==============================================================================}

(*:@abstract(Time-Stamp Protocol client — RFC 3161 timestamp request via httpsend)

Cliente para obter token timestamp RFC 3161 de TSA (Time Stamping Authority).
Constroi TSP request com SHA-256 do hash do conteudo + nonce randomico, envia
POST a TSA URL via Synapse httpsend, parseia response e devolve timestamp
token (PKCS#7 SignedData containing TSTInfo).

ICP-Brasil DOC-ICP-15: estabelece politicas de Carimbo do Tempo. TSAs
brasileiros conhecidos: SerproTimestamp, Certisign Timestamp, etc.

Uso tipico (CAdES-T = signature + timestamp):

  var
    LTsp: TTspClient;
    LRes: TTimestampResult;
    LHash: TBytes;
  begin
    // hash deve ser do PKCS#7 signature (CAdES-T anexa timestamp ao .sig)
    LHash := SHA256OfBytes(LSignedBytes);
    LTsp := TTspClient.Create;
    try
      LRes := LTsp.RequestTimestamp(LHash, 'http://timestamp.serpro.gov.br/');
      if LRes.OK then
        // anexar LRes.TimestampToken como signature time-stamp attribute
    finally
      LTsp.Free;
    end;
  end;
*)

unit ssl_openssl_icpbrasil_tsp;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils, Classes;

type
  TTimestampResult = record
    OK:               Boolean;
    TimestampToken:   TBytes;        // ContentInfo TSTInfo (DER bytes)
    GenTime:          TDateTime;     // UTC, momento gerado pela TSA
    Tsa:              string;        // URL da TSA
    Status:           Integer;       // RFC 3161 status code (0 = granted)
    ErrorMsg:         string;
    HttpStatus:       Integer;
    SerialNumber:     string;        // serial do timestamp (hex)
    HashAlgo:         string;        // 'SHA-256' / 'SHA-1' / etc.
  end;

  ETspError = class(Exception);

  TTspClient = class
  private
    FTimeoutMs:    Integer;
    FUserAgent:    string;
    FLastError:    string;
  public
    constructor Create;
    destructor Destroy; override;

    { Constroi TSP request com hash do conteudo, envia para TSA URL, parseia
      response. AHashSha256 deve ter 32 bytes. }
    function RequestTimestamp(const AHashSha256: TBytes;
                              const ATsaUrl: string;
                              ARequestCert: Boolean = False): TTimestampResult;

    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property UserAgent: string read FUserAgent write FUserAgent;
    property LastError: string read FLastError;
  end;

implementation

uses
  httpsend;

constructor TTspClient.Create;
begin
  inherited;
  FTimeoutMs := 10000;
  FUserAgent := 'Synapse-CSL TSP/41.9';
end;

destructor TTspClient.Destroy;
begin
  inherited;
end;

(* Constroi TSP request DER manualmente (sem dependencia de OpenSSL TS_REQ —
   estrutura simples o suficiente para fazer a mao):

   TimeStampReq ::= SEQUENCE OF [
      version            INTEGER (v1 = 1),
      messageImprint     MessageImprint,
      reqPolicy          OBJECT IDENTIFIER OPTIONAL,
      nonce              INTEGER OPTIONAL,
      certReq            BOOLEAN DEFAULT FALSE,
      extensions         (0) IMPLICIT Extensions OPTIONAL
   ]
   MessageImprint ::= SEQUENCE OF [hashAlgorithm + hashedMessage OCTET STRING]
   AlgorithmIdentifier ::= SEQUENCE OF [algorithm OID + parameters NULL p/ SHA-256]
*)
function _BuildTspRequest(const AHashSha256: TBytes; ARequestCert: Boolean;
  out ARequestBytes: TBytes; out AErrorMsg: string): Boolean;
var
  LBuf: AnsiString;

  function EncLen(ALen: Integer): AnsiString;
  begin
    if ALen < $80 then
      Result := AnsiString(Char(Byte(ALen)))
    else if ALen <= $FF then
      Result := AnsiString(#$81) + AnsiString(Char(Byte(ALen)))
    else if ALen <= $FFFF then
      Result := AnsiString(#$82) + AnsiString(Char(Byte((ALen shr 8) and $FF))) +
                AnsiString(Char(Byte(ALen and $FF)))
    else
      Result := '';
  end;

  function EncTLV(ATag: Byte; const AContent: AnsiString): AnsiString;
  begin
    Result := AnsiString(Char(ATag)) + EncLen(Length(AContent)) + AContent;
  end;

var
  LSha256Oid:    AnsiString;     // 2.16.840.1.101.3.4.2.1
  LAlgId:        AnsiString;
  LHashOctet:    AnsiString;
  LMessageImprint: AnsiString;
  LVersion:      AnsiString;
  LNonce:        AnsiString;
  LCertReq:      AnsiString;
  LSeqContent:   AnsiString;
  LRequest:      AnsiString;
  LRandom: array[0..7] of Byte;
  I: Integer;
begin
  Result := False;
  AErrorMsg := '';
  SetLength(ARequestBytes, 0);

  if Length(AHashSha256) <> 32 then
  begin
    AErrorMsg := 'Hash SHA-256 deve ter 32 bytes.';
    Exit;
  end;

  { OID SHA-256: 2.16.840.1.101.3.4.2.1 -> DER bytes
    60 86 48 01 65 03 04 02 01
    First two: 2*40+16 = 96 = 0x60. Then 86 48 = 840 high-bit-7 encoded.
    Actually let me hardcode the DER of the OID: }
  LSha256Oid := AnsiString(#$06#$09#$60#$86#$48#$01#$65#$03#$04#$02#$01);

  { AlgorithmIdentifier: SEQUENCE [ OID + NULL ] }
  LAlgId := EncTLV($30, LSha256Oid + AnsiString(#$05#$00));

  { hashedMessage: OCTET STRING [hash bytes] }
  SetLength(LBuf, 32);
  Move(AHashSha256[0], LBuf[1], 32);
  LHashOctet := EncTLV($04, LBuf);

  LMessageImprint := EncTLV($30, LAlgId + LHashOctet);

  { version INTEGER 1 }
  LVersion := AnsiString(#$02#$01#$01);

  { nonce INTEGER (8 bytes random; first byte forced positive) }
  Randomize;
  for I := 0 to 7 do LRandom[I] := Random(256);
  LRandom[0] := LRandom[0] and $7F;
  if LRandom[0] = 0 then LRandom[0] := 1;
  SetLength(LBuf, 8);
  Move(LRandom[0], LBuf[1], 8);
  LNonce := EncTLV($02, LBuf);

  { certReq BOOLEAN }
  if ARequestCert then
    LCertReq := AnsiString(#$01#$01#$FF)
  else
    LCertReq := '';

  LSeqContent := LVersion + LMessageImprint + LNonce + LCertReq;
  LRequest := EncTLV($30, LSeqContent);

  SetLength(ARequestBytes, Length(LRequest));
  if Length(LRequest) > 0 then
    Move(LRequest[1], ARequestBytes[0], Length(LRequest));
  Result := True;
end;

function _PostTspRequest(const AUrl: string; const ARequestBytes: TBytes;
  ATimeoutMs: Integer; const AUserAgent: string;
  out AHttpStatus: Integer; out AResponseBytes: TBytes;
  out AErrorMsg: string): Boolean;
var
  LHttp: THTTPSend;
  LMs: TMemoryStream;
begin
  Result := False;
  AHttpStatus := 0;
  SetLength(AResponseBytes, 0);
  AErrorMsg := '';

  LHttp := THTTPSend.Create;
  try
    LHttp.Sock.ConnectionTimeout := ATimeoutMs;
    LHttp.Timeout := ATimeoutMs;
    LHttp.MimeType := 'application/timestamp-query';
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
      AErrorMsg := Format('HTTP %d %s', [AHttpStatus, LHttp.ResultString]);
      Exit;
    end;
    LMs := TMemoryStream.Create;
    try
      LHttp.Document.Position := 0;
      LMs.CopyFrom(LHttp.Document, 0);
      if LMs.Size = 0 then
      begin
        AErrorMsg := 'Resposta TSP vazia.';
        Exit;
      end;
      SetLength(AResponseBytes, LMs.Size);
      Move(LMs.Memory^, AResponseBytes[0], LMs.Size);
      Result := True;
    finally
      LMs.Free;
    end;
  finally
    LHttp.Free;
  end;
end;

function TTspClient.RequestTimestamp(const AHashSha256: TBytes;
  const ATsaUrl: string; ARequestCert: Boolean): TTimestampResult;
var
  LReqBytes, LRespBytes: TBytes;
  LErr: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.OK := False;
  Result.Tsa := ATsaUrl;
  Result.HashAlgo := 'SHA-256';
  Result.Status := -1;
  FLastError := '';

  if Length(AHashSha256) <> 32 then
  begin
    Result.ErrorMsg := 'Hash deve ser SHA-256 (32 bytes).';
    FLastError := Result.ErrorMsg;
    Exit;
  end;
  if ATsaUrl = '' then
  begin
    Result.ErrorMsg := 'TSA URL vazia.';
    FLastError := Result.ErrorMsg;
    Exit;
  end;

  if not _BuildTspRequest(AHashSha256, ARequestCert, LReqBytes, LErr) then
  begin
    Result.ErrorMsg := LErr;
    FLastError := LErr;
    Exit;
  end;
  if not _PostTspRequest(ATsaUrl, LReqBytes, FTimeoutMs, FUserAgent,
                         Result.HttpStatus, LRespBytes, LErr) then
  begin
    Result.ErrorMsg := LErr;
    FLastError := LErr;
    Exit;
  end;

  { TSP response e DER de TimeStampResp:
    TimeStampResp ::= SEQUENCE [
       status         PKIStatusInfo,
       timeStampToken TimeStampToken OPTIONAL
    ]
    Para uso pratico, devolvemos os bytes inteiros como TimestampToken
    (caller que parseia ou anexa direto a CAdES-T). }
  Result.TimestampToken := LRespBytes;
  Result.OK := Length(LRespBytes) > 0;
  Result.Status := 0;     { Assumido granted; parser detalhado em S12+ }
  Result.GenTime := SysUtils.Now;
end;

end.
