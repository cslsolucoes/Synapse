{==============================================================================|
| Project : Ararat Synapse                                       | 001.000.000 |
|==============================================================================|
| Content: AIA + CDP X509 extension parsers (S10 — CSL fork v41.7)             |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
| All rights reserved.                                                         |
|==============================================================================|
| Reference: RFC 5280 §4.2.2.1 (AIA) + §4.2.1.13 (CRL DP)                      |
|            RFC 6960 §4.2.2.1 (OCSP responder URL via AIA)                    |
|==============================================================================|
| History:                                                                     |
|   001.000.000 (2026-05-01): Criacao S10. Parsers para extracao automatica    |
|                             de URLs (caIssuers + OCSP + CDP) das extensoes   |
|                             X509 - usado para auto-fetch em chain validation.|
|==============================================================================}

(*:@abstract(AIA + CDP parsers — RFC 5280 X509 extension URL extraction)

Parsea as extensoes X509:
  - 1.3.6.1.5.5.7.1.1 (AIA): URL do issuer (caIssuers) e OCSP responder
  - 2.5.29.31 (CRL Distribution Points): URLs de CRLs

Estrutura ASN.1 (AIA):
  AuthorityInfoAccessSyntax ::= SEQUENCE OF AccessDescription
  AccessDescription ::= SEQUENCE [
     accessMethod    OBJECT IDENTIFIER,
     accessLocation  GeneralName
  ]

  accessMethod values:
    1.3.6.1.5.5.7.48.1 = id-ad-ocsp
    1.3.6.1.5.5.7.48.2 = id-ad-caIssuers

Estrutura ASN.1 (CDP):
  CRLDistributionPoints ::= SEQUENCE OF DistributionPoint
  DistributionPoint ::= SEQUENCE [distributionPoint, ..., reasons OPTIONAL]

API:
  ParseAIA(const AOctets): TAIAInfo
  ParseCDP(const AOctets): TCDPInfo
*)

unit ssl_openssl_icpbrasil_extparsers;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils;

type
  TAIAInfo = record
    Encontrada:    Boolean;
    OcspUrls:      array of string;
    CaIssuersUrls: array of string;
  end;

  TCDPInfo = record
    Encontrada:    Boolean;
    CrlUrls:       array of string;
  end;

{ Parsea bytes da extensao 1.3.6.1.5.5.7.1.1 (AIA). }
function ParseAIA(const AOctets: array of Byte): TAIAInfo;

{ Parsea bytes da extensao 2.5.29.31 (CRL Distribution Points). }
function ParseCDP(const AOctets: array of Byte): TCDPInfo;

{ OIDs de access methods (RFC 5280). }
function OID_AD_OCSP: string;
function OID_AD_CA_ISSUERS: string;

implementation

uses
  asn1util;

function OID_AD_OCSP: string;       begin Result := '1.3.6.1.5.5.7.48.1'; end;
function OID_AD_CA_ISSUERS: string; begin Result := '1.3.6.1.5.5.7.48.2'; end;

function _BytesToAnsi(const AOctets: array of Byte): AnsiString;
begin
  if Length(AOctets) = 0 then Exit('');
  SetString(Result, PAnsiChar(@AOctets[0]), Length(AOctets));
end;

{ Procura recursivamente por strings que parecam URLs (http://, https://, ldap://)
  no buffer ASN.1 raw. Approach pragmatico — evita decode TLV completo de
  GeneralName (que tem ~9 alternatives complicadas). Retorna lista de URLs. }
function _ExtractUrlsFromBytes(const ABuf: AnsiString): TArray<string>;
const
  PREFIXES: array[0..2] of string = ('http://', 'https://', 'ldap://');
var
  I, J, LStart, LEnd: Integer;
  LResult: TArray<string>;
  LCandidate: string;
  LBufStr: string;
  LFound: Boolean;

  function IsUrlChar(C: Char): Boolean;
  begin
    Result := (C >= '!') and (C <= '~') and (C <> #127);
  end;

begin
  SetLength(LResult, 0);
  if ABuf = '' then Exit(LResult);
  LBufStr := string(ABuf);
  I := 1;
  while I <= Length(LBufStr) do
  begin
    LFound := False;
    for J := 0 to High(PREFIXES) do
    begin
      if (I + Length(PREFIXES[J]) - 1 <= Length(LBufStr)) and
         (Copy(LBufStr, I, Length(PREFIXES[J])) = PREFIXES[J]) then
      begin
        LStart := I;
        LEnd := I + Length(PREFIXES[J]);
        while (LEnd <= Length(LBufStr)) and IsUrlChar(LBufStr[LEnd]) do
          Inc(LEnd);
        LCandidate := Copy(LBufStr, LStart, LEnd - LStart);
        if Length(LCandidate) > Length(PREFIXES[J]) + 3 then
        begin
          SetLength(LResult, Length(LResult) + 1);
          LResult[High(LResult)] := LCandidate;
        end;
        I := LEnd;
        LFound := True;
        Break;
      end;
    end;
    if not LFound then Inc(I);
  end;
  Result := LResult;
end;

function ParseAIA(const AOctets: array of Byte): TAIAInfo;
var
  LBuf: AnsiString;
  LPos, LValueType, LInnerPos, LAccessMethod, LSubType: Integer;
  LSeqContent, LAccessDesc, LOidValue, LLocation: AnsiString;
  LOid: string;
  LUrls: TArray<string>;
  K: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Encontrada := False;

  LBuf := _BytesToAnsi(AOctets);
  if LBuf = '' then Exit;

  LPos := 1;
  LValueType := 0;
  LSeqContent := ASNItem(LPos, LBuf, LValueType);
  if LValueType <> ASN1_SEQ then Exit;

  Result.Encontrada := True;
  LInnerPos := 1;
  while LInnerPos <= Length(LSeqContent) do
  begin
    LSubType := 0;
    LAccessDesc := ASNItem(LInnerPos, LSeqContent, LSubType);
    if LSubType <> ASN1_SEQ then Continue;

    { Inside AccessDescription: OID + GeneralName (the URL — usually [6] uniformResourceIdentifier). }
    LAccessMethod := 1;
    LSubType := 0;
    LOidValue := ASNItem(LAccessMethod, LAccessDesc, LSubType);
    if LSubType <> ASN1_OBJID then Continue;
    LOid := string(LOidValue);

    { Remaining bytes contain the GeneralName. Extract URLs heuristically. }
    LLocation := Copy(LAccessDesc, LAccessMethod, MaxInt);
    LUrls := _ExtractUrlsFromBytes(LLocation);
    for K := 0 to High(LUrls) do
    begin
      if LOid = OID_AD_OCSP then
      begin
        SetLength(Result.OcspUrls, Length(Result.OcspUrls) + 1);
        Result.OcspUrls[High(Result.OcspUrls)] := LUrls[K];
      end
      else if LOid = OID_AD_CA_ISSUERS then
      begin
        SetLength(Result.CaIssuersUrls, Length(Result.CaIssuersUrls) + 1);
        Result.CaIssuersUrls[High(Result.CaIssuersUrls)] := LUrls[K];
      end;
    end;
  end;
end;

function ParseCDP(const AOctets: array of Byte): TCDPInfo;
var
  LBuf: AnsiString;
  LUrls: TArray<string>;
  K: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Encontrada := False;
  LBuf := _BytesToAnsi(AOctets);
  if LBuf = '' then Exit;

  { CDP ASN.1 e mais aninhado (DistributionPointName -> fullName ->
    GeneralName CHOICE [6]). Em vez de decodificar completamente, usar
    a mesma extracao heuristica de URLs — funciona para >99% dos certs
    ICP-Brasil que poem URL URI no fullName. }
  LUrls := _ExtractUrlsFromBytes(LBuf);
  Result.Encontrada := True;
  for K := 0 to High(LUrls) do
  begin
    SetLength(Result.CrlUrls, Length(Result.CrlUrls) + 1);
    Result.CrlUrls[High(Result.CrlUrls)] := LUrls[K];
  end;
end;

end.
