{==============================================================================|
| Project : Ararat Synapse                                       | 001.000.000 |
|==============================================================================|
| Content: Subject enrichment parsers — SAN/KU/EKU/OAB (S11 — v41.8)           |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
| All rights reserved.                                                         |
|==============================================================================|
| Reference: RFC 5280 §4.2.1.6 (SAN) §4.2.1.3 (KU) §4.2.1.12 (EKU)             |
|            DOC-ICP-04 (OAB digital, OID 2.16.76.1.3.10)                      |
|==============================================================================|
| History:                                                                     |
|   001.000.000 (2026-05-01): Criacao S11. Parsers para extensoes:             |
|                             - 2.5.29.17 (SubjectAltName: DNS, IP, URI, email)|
|                             - 2.5.29.15 (KeyUsage)                           |
|                             - 2.5.29.37 (ExtendedKeyUsage)                   |
|                             - 2.16.76.1.3.10 (OAB)                           |
|==============================================================================}

(*:@abstract(Subject enrichment parsers — RFC 5280 SAN/KU/EKU + OAB digital)

Parsers das extensoes X509 que enriquecem o leitor ICP-Brasil em S11:

- SAN (Subject Alternative Name, ext 2.5.29.17): rfc822Name (email),
  dNSName, iPAddress, uniformResourceIdentifier (URI). Implementa
  GeneralName CHOICE [0..8].
- KU (Key Usage, ext 2.5.29.15): bitmask de proposito da chave.
- EKU (Extended Key Usage, ext 2.5.29.37): array de OIDs de proposito
  estendido (clientAuth, serverAuth, codeSigning, etc.).
- OAB digital (OID 2.16.76.1.3.10): numero + UF do advogado.

Estrutura ASN.1:

  SubjectAltName ::= GeneralNames
  GeneralNames ::= SEQUENCE SIZE (1..MAX) OF GeneralName
  GeneralName ::= CHOICE [
     otherName     [0] OtherName,
     rfc822Name    [1] IA5String,
     dNSName       [2] IA5String,
     x400Address   [3] ORAddress,
     directoryName [4] Name,
     ediPartyName  [5] EDIPartyName,
     uniformResourceIdentifier [6] IA5String,
     iPAddress     [7] OCTET STRING,
     registeredID  [8] OBJECT IDENTIFIER
  ]

  KeyUsage ::= BIT STRING [
     digitalSignature        (0),
     nonRepudiation          (1),
     keyEncipherment         (2),
     dataEncipherment        (3),
     keyAgreement            (4),
     keyCertSign             (5),
     cRLSign                 (6),
     encipherOnly            (7),
     decipherOnly            (8)
  ]

  ExtKeyUsageSyntax ::= SEQUENCE SIZE (1..MAX) OF KeyPurposeId
  KeyPurposeId ::= OBJECT IDENTIFIER
*)

unit ssl_openssl_icpbrasil_san;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils;

type
  TKeyUsageBit = (
    kuDigitalSignature,
    kuNonRepudiation,
    kuKeyEncipherment,
    kuDataEncipherment,
    kuKeyAgreement,
    kuKeyCertSign,
    kuCrlSign,
    kuEncipherOnly,
    kuDecipherOnly
  );
  TKeyUsageSet = set of TKeyUsageBit;

  TSANInfo = record
    Encontrada:    Boolean;
    DnsNames:      array of string;
    IpAddresses:   array of string;
    Uris:          array of string;
    Emails:        array of string;
  end;

  TKeyUsageInfo = record
    Encontrada:    Boolean;
    Bits:          TKeyUsageSet;
  end;

  TExtKeyUsageInfo = record
    Encontrada:    Boolean;
    Oids:          array of string;
  end;

  TOABInfo = record
    Encontrada:    Boolean;
    Numero:        string;          // numero OAB
    UF:            string;           // sigla UF (SP, RJ, MG, etc.)
  end;

{ Parsea ext 2.5.29.17 (Subject Alternative Name). }
function ParseSAN(const AOctets: array of Byte): TSANInfo;

{ Parsea ext 2.5.29.15 (Key Usage). }
function ParseKeyUsage(const AOctets: array of Byte): TKeyUsageInfo;

{ Parsea ext 2.5.29.37 (Extended Key Usage). }
function ParseExtKeyUsage(const AOctets: array of Byte): TExtKeyUsageInfo;

{ Parsea OID 2.16.76.1.3.10 (OAB digital — formato heuristico). }
function ParseOAB(const AOctets: array of Byte): TOABInfo;

{ Helper — converte conjunto de bits para string legivel. }
function KeyUsageToString(const ABits: TKeyUsageSet): string;

{ EKU OID dictionary (humano-legivel). }
function EkuOidName(const AOID: string): string;

implementation

uses
  asn1util;

function _BytesToAnsi(const AOctets: array of Byte): AnsiString;
begin
  if Length(AOctets) = 0 then Exit('');
  SetString(Result, PAnsiChar(@AOctets[0]), Length(AOctets));
end;

{ Le tag + length de um TLV em ABuf comecando em APos. Avanca APos para
  apos o length. Retorna tag (byte completo, sem strip). ALen = comprimento
  do conteudo. AContentStart = inicio do conteudo. }
function _ReadTLV(const ABuf: AnsiString; var APos: Integer;
  out ATag: Byte; out ALen, AContentStart: Integer): Boolean;
var
  LLen: Integer;
begin
  Result := False;
  if APos > Length(ABuf) then Exit;
  ATag := Byte(ABuf[APos]);
  Inc(APos);
  if APos > Length(ABuf) then Exit;
  LLen := Byte(ABuf[APos]);
  Inc(APos);
  if LLen >= $80 then
  begin
    case LLen of
      $81: begin if APos > Length(ABuf) then Exit; LLen := Byte(ABuf[APos]); Inc(APos); end;
      $82: begin
             if APos+1 > Length(ABuf) then Exit;
             LLen := (Byte(ABuf[APos]) shl 8) or Byte(ABuf[APos+1]);
             Inc(APos, 2);
           end;
      $83: begin
             if APos+2 > Length(ABuf) then Exit;
             LLen := (Byte(ABuf[APos]) shl 16) or (Byte(ABuf[APos+1]) shl 8) or Byte(ABuf[APos+2]);
             Inc(APos, 3);
           end;
    else
      Exit;
    end;
  end;
  ALen := LLen;
  AContentStart := APos;
  Result := True;
end;

function ParseSAN(const AOctets: array of Byte): TSANInfo;
var
  LBuf: AnsiString;
  LPos, LSeqEnd, LContentStart, LItemEnd, LSubLen: Integer;
  LTag: Byte;
  LValue: AnsiString;
  LIp: string;
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Encontrada := False;
  LBuf := _BytesToAnsi(AOctets);
  if LBuf = '' then Exit;

  LPos := 1;
  if not _ReadTLV(LBuf, LPos, LTag, LSubLen, LContentStart) then Exit;
  if LTag <> ASN1_SEQ then Exit;
  Result.Encontrada := True;
  LSeqEnd := LContentStart + LSubLen;
  LPos := LContentStart;

  while LPos < LSeqEnd do
  begin
    if not _ReadTLV(LBuf, LPos, LTag, LSubLen, LContentStart) then Break;
    LItemEnd := LContentStart + LSubLen;
    LValue := Copy(LBuf, LContentStart, LSubLen);
    case LTag of
      $81: { rfc822Name [1] IA5String — email }
        begin
          SetLength(Result.Emails, Length(Result.Emails) + 1);
          Result.Emails[High(Result.Emails)] := string(LValue);
        end;
      $82: { dNSName [2] IA5String }
        begin
          SetLength(Result.DnsNames, Length(Result.DnsNames) + 1);
          Result.DnsNames[High(Result.DnsNames)] := string(LValue);
        end;
      $86: { uniformResourceIdentifier [6] IA5String }
        begin
          SetLength(Result.Uris, Length(Result.Uris) + 1);
          Result.Uris[High(Result.Uris)] := string(LValue);
        end;
      $87: { iPAddress [7] OCTET STRING (4 bytes IPv4 ou 16 bytes IPv6) }
        begin
          if Length(LValue) = 4 then
            LIp := Format('%d.%d.%d.%d',
              [Byte(LValue[1]), Byte(LValue[2]), Byte(LValue[3]), Byte(LValue[4])])
          else if Length(LValue) = 16 then
          begin
            LIp := '';
            for I := 1 to 16 do
            begin
              if (I > 1) and ((I-1) mod 2 = 0) then LIp := LIp + ':';
              LIp := LIp + IntToHex(Byte(LValue[I]), 2);
            end;
            LIp := LowerCase(LIp);
          end
          else
            LIp := '';
          if LIp <> '' then
          begin
            SetLength(Result.IpAddresses, Length(Result.IpAddresses) + 1);
            Result.IpAddresses[High(Result.IpAddresses)] := LIp;
          end;
        end;
      { otherName [0], directoryName [4], etc. — silently skipped }
    end;
    LPos := LItemEnd;
  end;
end;

function ParseKeyUsage(const AOctets: array of Byte): TKeyUsageInfo;
var
  LBuf: AnsiString;
  LPos, LContentStart, LSubLen: Integer;
  LTag: Byte;
  LBits, B: Byte;
  LBitIdx, I: Integer;
  LBitNames: array[0..8] of TKeyUsageBit;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Encontrada := False;
  LBuf := _BytesToAnsi(AOctets);
  if LBuf = '' then Exit;

  { KeyUsage extension wraps a BIT STRING. The OCTET wrapping was already
    stripped by the caller (extensions iterator). The BIT STRING itself
    starts with tag 0x03 + len + unused-bits-count + bytes. }
  LPos := 1;
  if not _ReadTLV(LBuf, LPos, LTag, LSubLen, LContentStart) then Exit;
  if LTag <> $03 then Exit;
  if LSubLen < 2 then Exit;
  Result.Encontrada := True;

  { Skip unused-bits byte (LBuf[LContentStart]). }
  LBitNames[0] := kuDigitalSignature;
  LBitNames[1] := kuNonRepudiation;
  LBitNames[2] := kuKeyEncipherment;
  LBitNames[3] := kuDataEncipherment;
  LBitNames[4] := kuKeyAgreement;
  LBitNames[5] := kuKeyCertSign;
  LBitNames[6] := kuCrlSign;
  LBitNames[7] := kuEncipherOnly;
  LBitNames[8] := kuDecipherOnly;

  LBitIdx := 0;
  for I := LContentStart + 1 to LContentStart + LSubLen - 1 do
  begin
    LBits := Byte(LBuf[I]);
    for B := 7 downto 0 do
    begin
      if LBitIdx > 8 then Break;
      if (LBits and (1 shl B)) <> 0 then
        Include(Result.Bits, LBitNames[LBitIdx]);
      Inc(LBitIdx);
    end;
  end;
end;

function ParseExtKeyUsage(const AOctets: array of Byte): TExtKeyUsageInfo;
var
  LBuf, LSeqContent, LOidValue: AnsiString;
  LPos, LValueType, LInnerPos, LSubType: Integer;
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
    LOidValue := ASNItem(LInnerPos, LSeqContent, LSubType);
    if LSubType = ASN1_OBJID then
    begin
      SetLength(Result.Oids, Length(Result.Oids) + 1);
      Result.Oids[High(Result.Oids)] := string(LOidValue);
    end;
  end;
end;

function ParseOAB(const AOctets: array of Byte): TOABInfo;
var
  LBuf: AnsiString;
  LStr: string;
  I, LDashPos: Integer;
  LDigits: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Encontrada := False;
  LBuf := _BytesToAnsi(AOctets);
  if LBuf = '' then Exit;

  { OID .10 nao tem formato canonico documentado — heuristica:
    procurar pattern UF (2 letras maiusculas) + numero. }
  LStr := '';
  for I := 1 to Length(LBuf) do
    if (Byte(LBuf[I]) >= 32) and (Byte(LBuf[I]) < 127) then
      LStr := LStr + Char(LBuf[I]);

  { Pattern comuns: 'OAB-MG-12345', 'MG12345', '12345/MG'. }
  Result.Encontrada := True;
  LDigits := '';
  for I := 1 to Length(LStr) do
    if (LStr[I] >= '0') and (LStr[I] <= '9') then
      LDigits := LDigits + LStr[I];
  Result.Numero := LDigits;

  { Procurar 2 letras maiusculas consecutivas (UF). }
  for I := 1 to Length(LStr) - 1 do
    if (LStr[I] >= 'A') and (LStr[I] <= 'Z') and
       (LStr[I+1] >= 'A') and (LStr[I+1] <= 'Z') then
    begin
      Result.UF := Copy(LStr, I, 2);
      Break;
    end;
end;

function KeyUsageToString(const ABits: TKeyUsageSet): string;
var
  Sep: string;
begin
  Result := '';
  Sep := '';
  if kuDigitalSignature in ABits then begin Result := Result + Sep + 'DigitalSignature';   Sep := ', '; end;
  if kuNonRepudiation   in ABits then begin Result := Result + Sep + 'NonRepudiation';     Sep := ', '; end;
  if kuKeyEncipherment  in ABits then begin Result := Result + Sep + 'KeyEncipherment';    Sep := ', '; end;
  if kuDataEncipherment in ABits then begin Result := Result + Sep + 'DataEncipherment';   Sep := ', '; end;
  if kuKeyAgreement     in ABits then begin Result := Result + Sep + 'KeyAgreement';       Sep := ', '; end;
  if kuKeyCertSign      in ABits then begin Result := Result + Sep + 'KeyCertSign';        Sep := ', '; end;
  if kuCrlSign          in ABits then begin Result := Result + Sep + 'CRLSign';            Sep := ', '; end;
  if kuEncipherOnly     in ABits then begin Result := Result + Sep + 'EncipherOnly';       Sep := ', '; end;
  if kuDecipherOnly     in ABits then begin Result := Result + Sep + 'DecipherOnly';       Sep := ', '; end;
end;

function EkuOidName(const AOID: string): string;
begin
  if AOID = '1.3.6.1.5.5.7.3.1' then Result := 'serverAuth'
  else if AOID = '1.3.6.1.5.5.7.3.2' then Result := 'clientAuth'
  else if AOID = '1.3.6.1.5.5.7.3.3' then Result := 'codeSigning'
  else if AOID = '1.3.6.1.5.5.7.3.4' then Result := 'emailProtection'
  else if AOID = '1.3.6.1.5.5.7.3.8' then Result := 'timeStamping'
  else if AOID = '1.3.6.1.5.5.7.3.9' then Result := 'OCSPSigning'
  else if AOID = '1.3.6.1.4.1.311.20.2.2' then Result := 'smartCardLogon'
  else Result := AOID;
end;

end.
