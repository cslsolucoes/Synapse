{==============================================================================|
| Project : Ararat Synapse                                       | 001.001.000 |
|==============================================================================|
| Content: ICP-Brasil ASN.1 OtherName parsers (DOC-ICP-04 v3.0)                |
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
| Reference: ITI / DOC-ICP-04 v3.0 - https://www.gov.br/iti/pt-br              |
|==============================================================================|
| History: see HISTORY.HTM from distribution package                           |
|          (Found at URL: http://www.ararat.cz/synapse/)                       |
|==============================================================================}

{:@abstract(Parsers for ASN.1 OtherName encoding of ICP-Brasil OIDs 2.16.76.1.3.*
            per DOC-ICP-04 v3.0)

Generic ASN.1 structure:
  OtherName ::= SEQUENCE [
    type-id OBJECT IDENTIFIER,
    value [0] EXPLICIT ANY DEFINED BY type-id
  ]

For 2.16.76.1.3.1 (e-CPF data):
  value ::= [0] OCTET STRING with PrintableString
            'DDMMYYYY' [8] + CPF [11] + NIS [11] + RG [15] + issuer [6]

For 2.16.76.1.3.7 (e-CNPJ data):
  value ::= [0] OCTET STRING with '<14 digits>'

NOTE: 'value' octets arrive already from ASN1_OCTET_STRING via X509GetAllExtensions
of Synapse base. This unit interprets the contents only - does not do recursive
TLV decode unless StripASN1OctetWrapper detects nested wrapper.
}
unit ssl_openssl_icpbrasil_othername;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils;

type
  TByteArray = array of Byte;

{ Parses OID 2.16.76.1.3.1 (e-CPF data).
  Expected: 'DDMMYYYYCPF...........NIS...........RG..............ISSU' (>=19).
  Returns True if at least date+CPF extracted (RG/issuer optional). }
function ParseEcpfData(const AOctets: TByteArray;
                       out ANasc: TDateTime;
                       out ACpf, ARg, AEmissor: string): Boolean;

{ Parses OID 2.16.76.1.3.7 (e-CNPJ data).
  Expected: '<14 digits>' (CNPJ).
  Returns True if 14 digits found. }
function ParseEcnpjData(const AOctets: TByteArray;
                        out ACnpj: string): Boolean;

{ Parses OID 2.16.76.1.3.4 (e-CNPJ responsavel - PF). Same structure as e-CPF data. }
function ParseEcnpjResponsavel(const AOctets: TByteArray;
                               out ANomeResponsavel, ACpfResp: string;
                               out ANascResp: TDateTime): Boolean;

{ Parses OID 2.16.76.1.3.5 (Voter title — Titulo de Eleitor).
  Expected: 27-char PrintableString concatenation:
    Title (12) + Zona (3) + Secao (4) + Municipio (6) + UF (2)
  Returns digits-only string preserving order; '' if no digits. }
function ParseTituloEleitor(const AOctets: TByteArray;
                            out ATitulo: string): Boolean;

{ Parses OID 2.16.76.1.3.6 (PIS/PASEP/INSS or CAEPF/CEI per DOC-ICP-04 v6+).
  Expected: PrintableString of 11 digits (PIS legacy), 12 digits (CEI legacy)
  or 14 digits (CAEPF current). Returns the digits without separators. }
function ParsePisOuCaepf(const AOctets: TByteArray;
                        out AValor: string): Boolean;

{ Parses OID 2.16.76.1.3.8 (RG separado).
  Expected: 21-char PrintableString = RG (15) + UF emissor (2) + Orgao (4)
  or RG (15) + Emissor (6). Returns RG and Emissor separately. }
function ParseRgSeparado(const AOctets: TByteArray;
                         out ARg, AEmissor: string): Boolean;

{ Fallback: extracts printable raw content. Sanitizes non-printable to '.'. }
function ExtractFieldOrRaw(const AOctets: TByteArray; const AOIDName: string): string;

{ Reads ASN.1 OCTET STRING TLV wrapper if present and returns content.
  Detects tag 0x04 (OCTET STRING) and 0xA0 ([0] EXPLICIT). Tolerates up
  to 1 level of nested wrapper. }
function StripASN1OctetWrapper(const AOctets: TByteArray): TByteArray;

implementation

function BytesToAnsi(const AOctets: TByteArray): AnsiString;
begin
  if Length(AOctets) = 0 then Exit('');
  SetString(Result, PAnsiChar(@AOctets[0]), Length(AOctets));
end;

function StripASN1OctetWrapper(const AOctets: TByteArray): TByteArray;
var
  LStart, LContentLen, I: Integer;
begin
  Result := AOctets;
  if Length(AOctets) < 2 then Exit;

  if (AOctets[0] <> $04) and (AOctets[0] <> $A0) then Exit;

  if AOctets[1] < $80 then
  begin
    LContentLen := AOctets[1];
    LStart := 2;
  end
  else if AOctets[1] = $81 then
  begin
    if Length(AOctets) < 3 then Exit;
    LContentLen := AOctets[2];
    LStart := 3;
  end
  else if AOctets[1] = $82 then
  begin
    if Length(AOctets) < 4 then Exit;
    LContentLen := (AOctets[2] shl 8) or AOctets[3];
    LStart := 4;
  end
  else
    Exit;

  if LContentLen <= 0 then Exit;
  if LStart + LContentLen > Length(AOctets) then Exit;

  SetLength(Result, LContentLen);
  for I := 0 to LContentLen - 1 do
    Result[I] := AOctets[LStart + I];

  if (Length(Result) >= 2) and (Result[0] = $04) then
    Result := StripASN1OctetWrapper(Result);
end;

function ParseDataDDMMYYYY(const AStr: AnsiString): TDateTime;
var
  LDay, LMonth, LYear: Word;
begin
  Result := 0;
  if Length(AStr) < 8 then Exit;
  LDay   := StrToIntDef(string(Copy(AStr, 1, 2)), 0);
  LMonth := StrToIntDef(string(Copy(AStr, 3, 2)), 0);
  LYear  := StrToIntDef(string(Copy(AStr, 5, 4)), 0);
  if (LDay in [1..31]) and (LMonth in [1..12]) and (LYear >= 1900) and (LYear <= 2200) then
    try
      Result := EncodeDate(LYear, LMonth, LDay);
    except
      Result := 0;
    end;
end;

function SoDigitosLocal(const AStr: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AStr) do
    if (AStr[I] >= '0') and (AStr[I] <= '9') then
      Result := Result + AStr[I];
end;

function ParseEcnpjData(const AOctets: TByteArray; out ACnpj: string): Boolean;
var
  LStripped: TByteArray;
  LStr, LDigits: AnsiString;
begin
  Result := False;
  ACnpj := '';

  LStripped := StripASN1OctetWrapper(AOctets);
  if Length(LStripped) = 0 then Exit;

  LStr := BytesToAnsi(LStripped);
  LDigits := SoDigitosLocal(LStr);

  if Length(LDigits) >= 14 then
  begin
    ACnpj := string(Copy(LDigits, 1, 14));
    Result := True;
  end;
end;

function ParseEcpfData(const AOctets: TByteArray;
  out ANasc: TDateTime; out ACpf, ARg, AEmissor: string): Boolean;
var
  LStripped: TByteArray;
  LStr: AnsiString;
  LData, LCpfDigits, LRgRaw, LEmissorRaw: AnsiString;
begin
  Result := False;
  ANasc := 0;
  ACpf := '';
  ARg := '';
  AEmissor := '';

  LStripped := StripASN1OctetWrapper(AOctets);
  if Length(LStripped) = 0 then Exit;

  LStr := BytesToAnsi(LStripped);
  if Length(LStr) < 19 then Exit;

  LData := Copy(LStr, 1, 8);
  ANasc := ParseDataDDMMYYYY(LData);

  LCpfDigits := SoDigitosLocal(Copy(LStr, 9, 11));
  if Length(LCpfDigits) = 11 then
    ACpf := string(LCpfDigits);

  if Length(LStr) >= 45 then
  begin
    LRgRaw := AnsiString(Trim(string(Copy(LStr, 31, 15))));
    if LRgRaw <> '' then
      ARg := string(LRgRaw);

    if Length(LStr) >= 51 then
    begin
      LEmissorRaw := AnsiString(Trim(string(Copy(LStr, 46, 6))));
      if LEmissorRaw <> '' then
        AEmissor := string(LEmissorRaw);
    end;
  end;

  Result := (ACpf <> '') or (ANasc <> 0);
end;

function ParseEcnpjResponsavel(const AOctets: TByteArray;
  out ANomeResponsavel, ACpfResp: string;
  out ANascResp: TDateTime): Boolean;
var
  LRgIgnored, LEmissorIgnored: string;
begin
  ANomeResponsavel := '';
  Result := ParseEcpfData(AOctets, ANascResp, ACpfResp, LRgIgnored, LEmissorIgnored);
end;

function ParseTituloEleitor(const AOctets: TByteArray;
  out ATitulo: string): Boolean;
var
  LStripped: TByteArray;
  LStr, LDigits: AnsiString;
begin
  Result := False;
  ATitulo := '';
  LStripped := StripASN1OctetWrapper(AOctets);
  if Length(LStripped) = 0 then Exit;
  LStr := BytesToAnsi(LStripped);
  LDigits := SoDigitosLocal(LStr);
  if Length(LDigits) >= 12 then
  begin
    ATitulo := string(LDigits);
    Result := True;
  end;
end;

function ParsePisOuCaepf(const AOctets: TByteArray;
  out AValor: string): Boolean;
var
  LStripped: TByteArray;
  LStr, LDigits: AnsiString;
begin
  Result := False;
  AValor := '';
  LStripped := StripASN1OctetWrapper(AOctets);
  if Length(LStripped) = 0 then Exit;
  LStr := BytesToAnsi(LStripped);
  LDigits := SoDigitosLocal(LStr);
  { 11 = PIS/PASEP legacy; 12 = CEI legacy; 14 = CAEPF (DOC-ICP-04 v6+).
    Accept any of these lengths. }
  if (Length(LDigits) = 11) or (Length(LDigits) = 12) or (Length(LDigits) = 14) then
  begin
    AValor := string(LDigits);
    Result := True;
  end;
end;

function ParseRgSeparado(const AOctets: TByteArray;
  out ARg, AEmissor: string): Boolean;
var
  LStripped: TByteArray;
  LStr: AnsiString;
  LRg, LEmissor: AnsiString;
begin
  Result := False;
  ARg := '';
  AEmissor := '';
  LStripped := StripASN1OctetWrapper(AOctets);
  if Length(LStripped) = 0 then Exit;
  LStr := BytesToAnsi(LStripped);
  if Length(LStr) < 15 then Exit;
  LRg := AnsiString(Trim(string(Copy(LStr, 1, 15))));
  if LRg <> '' then
    ARg := string(LRg);
  if Length(LStr) >= 21 then
  begin
    LEmissor := AnsiString(Trim(string(Copy(LStr, 16, 6))));
    if LEmissor <> '' then
      AEmissor := string(LEmissor);
  end;
  Result := ARg <> '';
end;

function ExtractFieldOrRaw(const AOctets: TByteArray; const AOIDName: string): string;
var
  LStripped: TByteArray;
  LStr, LResult: AnsiString;
  I: Integer;
  C: Byte;
begin
  Result := '';
  LStripped := StripASN1OctetWrapper(AOctets);
  if Length(LStripped) = 0 then Exit;

  LStr := BytesToAnsi(LStripped);
  LResult := '';
  for I := 1 to Length(LStr) do
  begin
    C := Byte(LStr[I]);
    if (C >= 32) and (C < 127) then
      LResult := LResult + LStr[I]
    else
      LResult := LResult + '.';
  end;
  Result := string(LResult);
end;

end.
