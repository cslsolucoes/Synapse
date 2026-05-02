{==============================================================================|
| Project : Ararat Synapse (CSL fork)                            | 001.000.000 |
|==============================================================================|
| Content: ICP-Brasil Certificate Policies parser (ext OID 2.5.29.32)          |
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
| Reference: ITI / DOC-ICP-04 - Politicas de Certificacao ICP-Brasil           |
|            RFC 5280 §4.2.1.4 (Certificate Policies extension)                |
|==============================================================================|
| History: CSL fork history (this file):                                       |
|   001.000.000 (2026-05-01): Criacao S9. Parser de extension X509 Certificate |
|                             Policies (OID 2.5.29.32). Reconhece OIDs ITI    |
|                             prefix '2.16.76.1.2.' e classifica em AC-Raiz   |
|                             V1..V10. Cross-platform via asn1util.ASNItem.   |
|==============================================================================}

(*:@abstract(ICP-Brasil Certificate Policies parser — RFC 5280 ext 2.5.29.32)

Parsea a extensao Certificate Policies (2.5.29.32) de um cert X509 e
classifica os OIDs encontrados:

  ITI (ICP-Brasil) — prefix 2.16.76.1.2.:
    2.16.76.1.2.1.*  — politicas AC-Raiz V1
    2.16.76.1.2.3.*  — politicas AC-Raiz V3 (DOC-ICP-04 v3)
    2.16.76.1.2.5.*  — V5
    ... ate
    2.16.76.1.2.10.* — V10 (vigente em DOC-ICP-04 v8.x)

  Outros prefixes ficam em OutrasPolicies.

API:
  ParseCertificatePolicies(const AOctets: array of Byte): TPolicyInfo

Estrutura ASN.1:
  CertificatePolicies ::= SEQUENCE SIZE (1..MAX) OF PolicyInformation
  PolicyInformation ::= SEQUENCE OF [policyIdentifier, policyQualifiers OPTIONAL]
*)
unit ssl_openssl_icpbrasil_policy;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils;

type
  { Resultado do parsing. }
  TPolicyInfo = record
    Encontrada:        Boolean;        // true se ext 2.5.29.32 presente e parseada
    PolicyOids:        array of string;// todos os OIDs encontrados
    AcRaizDetectada:   Integer;        // 1..10 ou 0 se nenhuma reconhecida
    AcRaizDetectadaStr:string;         // 'AC-Raiz V5' etc., '' se nenhuma
    Valida:            Boolean;        // true se ao menos 1 OID ITI reconhecido
  end;

{ Parsea bytes (DER octet string content) da extension 2.5.29.32. }
function ParseCertificatePolicies(const AOctets: array of Byte): TPolicyInfo;

{ Identifica se OID e do tree ITI '2.16.76.1.2.*'. Retorna versao de
  AC-Raiz (1..10) ou 0 se nao reconhecida. }
function IsIcpBrasilPolicyOid(const AOID: string; out AVersao: Integer): Boolean;

{ Prefix do tree de politicas ITI. }
function OID_ICPBR_POLICY_ROOT: string;

implementation

uses
  asn1util;

function OID_ICPBR_POLICY_ROOT: string;
begin
  Result := '2.16.76.1.2.';
end;

function IsIcpBrasilPolicyOid(const AOID: string; out AVersao: Integer): Boolean;
var
  LRest, LFirstSegment: string;
  LDotPos: Integer;
begin
  Result := False;
  AVersao := 0;
  if AOID = '' then Exit;
  if Pos(OID_ICPBR_POLICY_ROOT, AOID) <> 1 then Exit;

  Result := True;
  LRest := Copy(AOID, Length(OID_ICPBR_POLICY_ROOT) + 1, MaxInt);
  LDotPos := Pos('.', LRest);
  if LDotPos > 0 then
    LFirstSegment := Copy(LRest, 1, LDotPos - 1)
  else
    LFirstSegment := LRest;
  AVersao := StrToIntDef(LFirstSegment, 0);
end;

function _BytesToAnsi(const AOctets: array of Byte): AnsiString;
begin
  if Length(AOctets) = 0 then Exit('');
  SetString(Result, PAnsiChar(@AOctets[0]), Length(AOctets));
end;

function _AddOid(var APolicy: TPolicyInfo; const AOID: string): Integer;
var
  LVer: Integer;
begin
  if AOID = '' then Exit(0);
  SetLength(APolicy.PolicyOids, Length(APolicy.PolicyOids) + 1);
  APolicy.PolicyOids[High(APolicy.PolicyOids)] := AOID;
  Result := 1;
  if IsIcpBrasilPolicyOid(AOID, LVer) then
  begin
    APolicy.Valida := True;
    if (LVer > 0) and (LVer > APolicy.AcRaizDetectada) then
    begin
      APolicy.AcRaizDetectada := LVer;
      APolicy.AcRaizDetectadaStr := 'AC-Raiz V' + IntToStr(LVer);
    end;
  end;
end;

function ParseCertificatePolicies(const AOctets: array of Byte): TPolicyInfo;
var
  LBuf: AnsiString;
  LPos, LValueType, LInnerPos, LInnerEnd, LSubType: Integer;
  LContent, LInner, LOidValue: AnsiString;
  LOid: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Encontrada := False;
  Result.AcRaizDetectada := 0;

  LBuf := _BytesToAnsi(AOctets);
  if LBuf = '' then Exit;

  { Outer SEQUENCE — ASNItem decodes the outer wrapper and returns content. }
  LPos := 1;
  LValueType := 0;
  LContent := ASNItem(LPos, LBuf, LValueType);
  if LValueType <> ASN1_SEQ then Exit;

  Result.Encontrada := True;

  { Iterate over PolicyInformation entries (each is a SEQUENCE inside outer). }
  LInnerPos := 1;
  while LInnerPos <= Length(LContent) do
  begin
    LSubType := 0;
    LInner := ASNItem(LInnerPos, LContent, LSubType);
    if LSubType <> ASN1_SEQ then Continue;

    { First item inside PolicyInformation must be OBJECT IDENTIFIER. ASNItem
      decodes ASN1_OBJID directly to MIB string format ('2.16.76.1.2.3.4'). }
    LInnerEnd := 1;
    LSubType := 0;
    LOidValue := ASNItem(LInnerEnd, LInner, LSubType);
    if (LSubType = ASN1_OBJID) and (LOidValue <> '') then
    begin
      LOid := string(LOidValue);
      _AddOid(Result, LOid);
    end;
    { policyQualifiers (optional) ignored — only OID matters for our use. }
  end;
end;

end.
