{
| Project   : Ararat Synapse                                     |  v41.4     |
|==============================================================================|
| Content: ICP-Brasil Subject CN parser + CNPJ/CPF mod-11 validators           |
|==============================================================================|
| Copyright (c)1999-2023, Lukas Gebauer (Synapse upstream)                     |
| Copyright (c)2026, contributors (fork extensions)                            |
| All rights reserved.                                                         |
|                                                                              |
| BSD 3-Clause License (with linking exception) - see LICENSE for full text.   |
|==============================================================================|
| Portions created by contributors (incl. CSL Tech Solutions) are              |
| Copyright (c) 2026.                                                          |
|==============================================================================|
}

{:@abstract(Parsers and validators for ICP-Brasil Subject CN format
            'COMPANY:CNPJ' (e-CNPJ) or 'NAME:CPF' (e-CPF), plus mod-11
            validators for CNPJ and CPF.)
}
unit ssl_openssl_icpbrasil_subject;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils,
  ssl_openssl_icpbrasil_types;

{ Parses Subject CN in 'TITULAR:DOCUMENTO' format. Splits on LAST ':'
  (some CNs have ':' in the name part). Returns False if no ':' or
  document not all-digits or wrong length (must be 11 or 14). }
function ParseSubjectCN(const ACN: string;
                        out ATitular, ADocumento: string): Boolean;

{ Formats raw CNPJ (14 digits) as '12.345.678/0001-90'. Empty if wrong length. }
function FormatarCnpj(const ACnpjCru: string): string;

{ Formats raw CPF (11 digits) as '123.456.789-09'. Empty if wrong length. }
function FormatarCpf(const ACpfCru: string): string;

{ Strips non-digit chars. }
function SoDigitos(const ATexto: string): string;

{ CNPJ mod-11 validator (Receita Federal standard).
  Rejects all-equal digits ('00000000000000', etc).
  Accepts formatted or raw input. }
function IsCnpjValido(const ACnpj: string): Boolean;

{ CPF mod-11 validator (Receita Federal standard).
  Rejects all-equal digits.
  Accepts formatted or raw input. }
function IsCpfValido(const ACpf: string): Boolean;

{ Classifies pure document by digit count:
    14 digits -> ibtECnpj
    11 digits -> ibtECpf
    other     -> ibtDesconhecido }
function ClassificarDocumento(const ADocumentoCru: string): TIcpBrasilTipo;

implementation

function SoDigitos(const ATexto: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(ATexto) do
    if (ATexto[I] >= '0') and (ATexto[I] <= '9') then
      Result := Result + ATexto[I];
end;

function ParseSubjectCN(const ACN: string;
  out ATitular, ADocumento: string): Boolean;
var
  LPos, I: Integer;
  LTrimmed, LDocCandidato: string;
begin
  Result := False;
  ATitular := '';
  ADocumento := '';

  LTrimmed := Trim(ACN);
  if LTrimmed = '' then Exit;

  LPos := 0;
  for I := Length(LTrimmed) downto 1 do
    if LTrimmed[I] = ':' then
    begin
      LPos := I;
      Break;
    end;

  if LPos = 0 then Exit;

  ATitular := Trim(Copy(LTrimmed, 1, LPos - 1));
  LDocCandidato := Trim(Copy(LTrimmed, LPos + 1, MaxInt));

  if (LDocCandidato = '') or (SoDigitos(LDocCandidato) <> LDocCandidato) then
  begin
    ATitular := '';
    Exit;
  end;

  ADocumento := LDocCandidato;
  Result := (ATitular <> '') and ((Length(ADocumento) = 11) or (Length(ADocumento) = 14));
end;

function FormatarCnpj(const ACnpjCru: string): string;
var
  LCru: string;
begin
  Result := '';
  LCru := SoDigitos(ACnpjCru);
  if Length(LCru) <> 14 then Exit;

  Result :=
    Copy(LCru, 1, 2)  + '.' +
    Copy(LCru, 3, 3)  + '.' +
    Copy(LCru, 6, 3)  + '/' +
    Copy(LCru, 9, 4)  + '-' +
    Copy(LCru, 13, 2);
end;

function FormatarCpf(const ACpfCru: string): string;
var
  LCru: string;
begin
  Result := '';
  LCru := SoDigitos(ACpfCru);
  if Length(LCru) <> 11 then Exit;

  Result :=
    Copy(LCru, 1, 3) + '.' +
    Copy(LCru, 4, 3) + '.' +
    Copy(LCru, 7, 3) + '-' +
    Copy(LCru, 10, 2);
end;

function TodosDigitosIguais(const ADig: string): Boolean;
var
  I: Integer;
begin
  Result := True;
  if Length(ADig) <= 1 then Exit;
  for I := 2 to Length(ADig) do
    if ADig[I] <> ADig[1] then
      Exit(False);
end;

function CalcularDigitoMod11(const ADig: string; const APesos: array of Integer): Integer;
var
  LSoma, I, LDig: Integer;
begin
  if Length(ADig) <> Length(APesos) then Exit(-1);
  LSoma := 0;
  for I := 1 to Length(ADig) do
  begin
    LDig := Ord(ADig[I]) - Ord('0');
    LSoma := LSoma + LDig * APesos[I - 1];
  end;
  Result := LSoma mod 11;
  if Result < 2 then
    Result := 0
  else
    Result := 11 - Result;
end;

function IsCnpjValido(const ACnpj: string): Boolean;
const
  PESOS_DV1: array[0..11] of Integer = (5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
  PESOS_DV2: array[0..12] of Integer = (6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
var
  LCru: string;
  LDV1, LDV2: Integer;
begin
  Result := False;
  LCru := SoDigitos(ACnpj);
  if Length(LCru) <> 14 then Exit;
  if TodosDigitosIguais(LCru) then Exit;

  LDV1 := CalcularDigitoMod11(Copy(LCru, 1, 12), PESOS_DV1);
  if LDV1 <> (Ord(LCru[13]) - Ord('0')) then Exit;

  LDV2 := CalcularDigitoMod11(Copy(LCru, 1, 13), PESOS_DV2);
  if LDV2 <> (Ord(LCru[14]) - Ord('0')) then Exit;

  Result := True;
end;

function IsCpfValido(const ACpf: string): Boolean;
const
  PESOS_DV1: array[0..8]  of Integer = (10, 9, 8, 7, 6, 5, 4, 3, 2);
  PESOS_DV2: array[0..9]  of Integer = (11, 10, 9, 8, 7, 6, 5, 4, 3, 2);
var
  LCru: string;
  LDV1, LDV2: Integer;
begin
  Result := False;
  LCru := SoDigitos(ACpf);
  if Length(LCru) <> 11 then Exit;
  if TodosDigitosIguais(LCru) then Exit;

  LDV1 := CalcularDigitoMod11(Copy(LCru, 1, 9), PESOS_DV1);
  if LDV1 <> (Ord(LCru[10]) - Ord('0')) then Exit;

  LDV2 := CalcularDigitoMod11(Copy(LCru, 1, 10), PESOS_DV2);
  if LDV2 <> (Ord(LCru[11]) - Ord('0')) then Exit;

  Result := True;
end;

function ClassificarDocumento(const ADocumentoCru: string): TIcpBrasilTipo;
var
  LCru: string;
begin
  LCru := SoDigitos(ADocumentoCru);
  case Length(LCru) of
    14: Result := ibtECnpj;
    11: Result := ibtECpf;
  else
    Result := ibtDesconhecido;
  end;
end;

end.
