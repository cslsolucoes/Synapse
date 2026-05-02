{==============================================================================|
| Project : Ararat Synapse                                       | 001.000.000 |
|==============================================================================|
| Content: CRL client for ICP-Brasil revocation checking (S10 — v41.7)         |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
| All rights reserved.                                                         |
|==============================================================================|
| Reference: RFC 5280 §5 (CRL), RFC 5280 §4.2.1.13 (CRL DP)                    |
|==============================================================================|
| History:                                                                     |
|   001.000.000 (2026-05-01): Criacao S10. Cliente CRL com cache em filesystem.|
|                             Download via Synapse httpsend; TTL respeitando   |
|                             nextUpdate; verifica assinatura contra issuer.   |
|==============================================================================}

(*:@abstract(CRL client — Download + cache + revocation lookup)

Cliente de CRL com cache em pasta configuravel. Download de URLs (extraidas
de `CDP` extension via ssl_openssl_icpbrasil_extparsers) ou paths arbitrarios.
TTL respeitando `nextUpdate` da CRL.

Uso tipico:
  var
    LClient: TIcpBrasilCrlClient;
    LRes:    TCrlCheckResult;
  begin
    LClient := TIcpBrasilCrlClient.Create;
    try
      LClient.CacheDir := 'caches/crl';
      if LClient.LoadFromUrl('http://crl.exemplo.com.br/raiz.crl') then
        if LClient.IsRevogado(ASerialHex, LRes) then
          if LRes.Revogado then WriteLn('REVOGADO em ', LRes.DataRevogacao);
    finally
      LClient.Free;
    end;
  end;
*)

unit ssl_openssl_icpbrasil_crl;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils, Classes,
  ssl_openssl3_lib,
  ssl_openssl_chain_verify;

type
  TIcpBrasilCrlClient = class
  private
    FCacheDir:    string;
    FTimeoutMs:   Integer;
    FUserAgent:   string;
    FCrl:         SslPtr;          // X509_CRL* loaded
    FCrlInfo:     TCrlInfo;
    FLastError:   string;

    procedure ReleaseCrl;
    function CacheFileFor(const AUrl: string): string;
    function ReadCacheFile(const APath: string; out ABytes: TBytes): Boolean;
    function WriteCacheFile(const APath: string; const ABytes: TBytes): Boolean;
    function DownloadCrl(const AUrl: string; out ABytes: TBytes): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { Carrega CRL de DER bytes em memoria. }
    function LoadFromBytes(const ABytes: array of Byte): Boolean;

    { Carrega CRL de path local (DER ou PEM detectado por header). }
    function LoadFromFile(const APath: string): Boolean;

    { Baixa CRL de AUrl (HTTP/HTTPS), valida cache local em CacheDir/.
      Se cache existe e ainda valido (data < nextUpdate), usa cache.
      Senao, baixa, valida formato, salva em cache, e carrega. }
    function LoadFromUrl(const AUrl: string): Boolean;

    { Verifica assinatura da CRL carregada contra a chave publica do issuer. }
    function VerifySignature(AIssuerCert: PX509): Boolean;

    { Procura ASerialHex (hex uppercase, sem 0x) na CRL carregada. }
    function IsRevogado(const ASerialHex: string;
                       out AResult: TCrlCheckResult): Boolean;

    property CacheDir:  string  read FCacheDir  write FCacheDir;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property UserAgent: string  read FUserAgent write FUserAgent;
    property CrlInfo:   TCrlInfo read FCrlInfo;
    property LastError: string  read FLastError;
  end;

implementation

uses
  httpsend;

constructor TIcpBrasilCrlClient.Create;
begin
  inherited;
  FCacheDir := '';
  FTimeoutMs := 10000;
  FUserAgent := 'Synapse-CSL CRL/41.7';
  FCrl := nil;
end;

destructor TIcpBrasilCrlClient.Destroy;
begin
  ReleaseCrl;
  inherited;
end;

procedure TIcpBrasilCrlClient.ReleaseCrl;
begin
  if Assigned(FCrl) then
    TX509ChainVerifier.FreeCrl(FCrl);
  FCrl := nil;
  FillChar(FCrlInfo, SizeOf(FCrlInfo), 0);
end;

function _SafeFilenameFromUrl(const AUrl: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AUrl) do
  begin
    C := AUrl[I];
    if (C >= 'a') and (C <= 'z') then Result := Result + C
    else if (C >= 'A') and (C <= 'Z') then Result := Result + C
    else if (C >= '0') and (C <= '9') then Result := Result + C
    else if (C = '.') or (C = '-') or (C = '_') then Result := Result + C
    else Result := Result + '_';
  end;
  if Length(Result) > 100 then
    Result := Copy(Result, 1, 100);
  Result := Result + '.crl';
end;

function TIcpBrasilCrlClient.CacheFileFor(const AUrl: string): string;
begin
  if FCacheDir = '' then
    Exit('');
  Result := IncludeTrailingPathDelimiter(FCacheDir) + _SafeFilenameFromUrl(AUrl);
end;

function TIcpBrasilCrlClient.ReadCacheFile(const APath: string;
  out ABytes: TBytes): Boolean;
var
  LFile: TFileStream;
begin
  Result := False;
  SetLength(ABytes, 0);
  if (APath = '') or not FileExists(APath) then Exit;
  try
    LFile := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
    try
      if LFile.Size > 0 then
      begin
        SetLength(ABytes, LFile.Size);
        LFile.ReadBuffer(ABytes[0], LFile.Size);
        Result := True;
      end;
    finally
      LFile.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Erro lendo cache: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TIcpBrasilCrlClient.WriteCacheFile(const APath: string;
  const ABytes: TBytes): Boolean;
var
  LFile: TFileStream;
  LDir: string;
begin
  Result := False;
  if APath = '' then Exit;
  LDir := ExtractFilePath(APath);
  if (LDir <> '') and not DirectoryExists(LDir) then
    if not ForceDirectories(LDir) then
    begin
      FLastError := 'Cache dir nao pode ser criado: ' + LDir;
      Exit;
    end;
  try
    LFile := TFileStream.Create(APath, fmCreate or fmShareDenyWrite);
    try
      if Length(ABytes) > 0 then
        LFile.WriteBuffer(ABytes[0], Length(ABytes));
      Result := True;
    finally
      LFile.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Erro gravando cache: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TIcpBrasilCrlClient.DownloadCrl(const AUrl: string;
  out ABytes: TBytes): Boolean;
var
  LHttp: THTTPSend;
  LMs: TMemoryStream;
begin
  Result := False;
  SetLength(ABytes, 0);
  LHttp := THTTPSend.Create;
  try
    LHttp.Sock.ConnectionTimeout := FTimeoutMs;
    LHttp.Timeout := FTimeoutMs;
    LHttp.UserAgent := FUserAgent;
    if not LHttp.HTTPMethod('GET', AUrl) then
    begin
      FLastError := 'HTTP GET falhou: ' + LHttp.Sock.LastErrorDesc;
      Exit;
    end;
    if (LHttp.ResultCode < 200) or (LHttp.ResultCode >= 300) then
    begin
      FLastError := Format('HTTP %d %s', [LHttp.ResultCode, LHttp.ResultString]);
      Exit;
    end;
    LMs := TMemoryStream.Create;
    try
      LHttp.Document.Position := 0;
      LMs.CopyFrom(LHttp.Document, 0);
      if LMs.Size = 0 then
      begin
        FLastError := 'CRL vazia recebida.';
        Exit;
      end;
      SetLength(ABytes, LMs.Size);
      Move(LMs.Memory^, ABytes[0], LMs.Size);
      Result := True;
    finally
      LMs.Free;
    end;
  finally
    LHttp.Free;
  end;
end;

function TIcpBrasilCrlClient.LoadFromBytes(const ABytes: array of Byte): Boolean;
var
  LCrl: SslPtr;
  LInfo: TCrlInfo;
  LStr: AnsiString;
begin
  Result := False;
  ReleaseCrl;
  FLastError := '';
  if Length(ABytes) = 0 then
  begin
    FLastError := 'Bytes vazios.';
    Exit;
  end;

  { Tenta DER primeiro; se falhar, tenta PEM. }
  if TX509ChainVerifier.LoadCrlFromBytes(ABytes, LCrl, LInfo) then
  begin
    FCrl := LCrl;
    FCrlInfo := LInfo;
    Result := True;
    Exit;
  end;

  SetString(LStr, PAnsiChar(@ABytes[0]), Length(ABytes));
  if Pos('-----BEGIN', string(LStr)) > 0 then
    if TX509ChainVerifier.LoadCrlFromPEM(LStr, LCrl, LInfo) then
    begin
      FCrl := LCrl;
      FCrlInfo := LInfo;
      Result := True;
      Exit;
    end;
  FLastError := 'CRL invalida (nem DER nem PEM).';
end;

function TIcpBrasilCrlClient.LoadFromFile(const APath: string): Boolean;
var
  LBytes: TBytes;
begin
  Result := False;
  if not FileExists(APath) then
  begin
    FLastError := 'Arquivo nao existe: ' + APath;
    Exit;
  end;
  if not ReadCacheFile(APath, LBytes) then Exit;
  Result := LoadFromBytes(LBytes);
end;

function TIcpBrasilCrlClient.LoadFromUrl(const AUrl: string): Boolean;
var
  LCachePath: string;
  LBytes: TBytes;
  LCacheValid: Boolean;
begin
  Result := False;
  FLastError := '';
  LCachePath := CacheFileFor(AUrl);

  { Tenta cache primeiro. }
  if (LCachePath <> '') and ReadCacheFile(LCachePath, LBytes) then
  begin
    if LoadFromBytes(LBytes) then
    begin
      LCacheValid := (FCrlInfo.NextUpdate = 0) or
                     (Now() < FCrlInfo.NextUpdate);
      if LCacheValid then
        Exit(True);
      ReleaseCrl;
    end;
  end;

  { Cache stale ou ausente — baixa fresh. }
  if not DownloadCrl(AUrl, LBytes) then Exit;
  if not LoadFromBytes(LBytes) then Exit;

  { Salva no cache se directorio configurado. }
  if LCachePath <> '' then
    WriteCacheFile(LCachePath, LBytes);

  Result := True;
end;

function TIcpBrasilCrlClient.VerifySignature(AIssuerCert: PX509): Boolean;
begin
  if not Assigned(FCrl) then
  begin
    FLastError := 'Nenhuma CRL carregada.';
    Exit(False);
  end;
  Result := TX509ChainVerifier.VerifyCrlSignature(FCrl, AIssuerCert);
  if not Result then
    FLastError := 'CRL signature verification falhou.';
end;

function TIcpBrasilCrlClient.IsRevogado(const ASerialHex: string;
  out AResult: TCrlCheckResult): Boolean;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  if not Assigned(FCrl) then
  begin
    FLastError := 'Nenhuma CRL carregada.';
    Exit(False);
  end;
  Result := TX509ChainVerifier.IsRevogadoNaCRL(FCrl, ASerialHex, AResult);
end;

end.
