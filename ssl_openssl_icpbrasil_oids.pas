{
| Project   : Ararat Synapse                                     |  v41.4     |
|==============================================================================|
| Content: ICP-Brasil DOC-ICP-04 OIDs                                          |
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
| Reference: ITI / DOC-ICP-04 - https://www.gov.br/iti/pt-br                   |
|==============================================================================|
}

{:@abstract(ICP-Brasil OIDs DOC-ICP-04 - constants and group helpers)

Identifies certificate fields specific to Brazilian ICP-Brasil PFX in
subjectAltName.otherName extension. Returned via functions (not const)
because synapse.dpk uses WRITEABLECONST OFF and string literals like
'2.16.76.1.3.7' confuse the parser as range notation.
}
unit ssl_openssl_icpbrasil_oids;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

{ e-CPF data of natural person holder. PrintableString DDMMYYYY+CPF+RG+issuer. }
function OID_ICPBR_E_CPF_DATA: string;

{ e-CPF voter title. PrintableString number/zone/section/municipality/UF. }
function OID_ICPBR_E_CPF_TITULO: string;

{ e-CPF PIS/PASEP (11 digits). }
function OID_ICPBR_E_CPF_INSS: string;

{ e-CNPJ data of legal person (14 digits CNPJ). }
function OID_ICPBR_E_CNPJ_DATA: string;

{ e-CNPJ data of natural person responsible (same format as e-CPF data). }
function OID_ICPBR_E_CNPJ_RESPONSAVEL: string;

{ e-CPF RG and issuing body. }
function OID_ICPBR_E_CPF_RG: string;

{ ICP-Brasil OID tree root prefix. }
function OID_ICPBR_ROOT_PREFIX: string;

{ Returns True if OID belongs to legal person (PJ) certificate group. }
function IsOidIcpBrasilPJ(const AOID: string): Boolean;

{ Returns True if OID belongs to natural person (PF) certificate group. }
function IsOidIcpBrasilPF(const AOID: string): Boolean;

implementation

function OID_ICPBR_E_CPF_DATA: string;          begin Result := '2.16.76.1.3.1'; end;
function OID_ICPBR_E_CPF_TITULO: string;        begin Result := '2.16.76.1.3.5'; end;
function OID_ICPBR_E_CPF_INSS: string;          begin Result := '2.16.76.1.3.6'; end;
function OID_ICPBR_E_CNPJ_DATA: string;         begin Result := '2.16.76.1.3.7'; end;
function OID_ICPBR_E_CNPJ_RESPONSAVEL: string;  begin Result := '2.16.76.1.3.4'; end;
function OID_ICPBR_E_CPF_RG: string;            begin Result := '2.16.76.1.3.8'; end;
function OID_ICPBR_ROOT_PREFIX: string;         begin Result := '2.16.76.1.3.';  end;

function IsOidIcpBrasilPJ(const AOID: string): Boolean;
begin
  Result := (AOID = OID_ICPBR_E_CNPJ_DATA) or
            (AOID = OID_ICPBR_E_CNPJ_RESPONSAVEL);
end;

function IsOidIcpBrasilPF(const AOID: string): Boolean;
begin
  Result := (AOID = OID_ICPBR_E_CPF_DATA) or
            (AOID = OID_ICPBR_E_CPF_TITULO) or
            (AOID = OID_ICPBR_E_CPF_INSS) or
            (AOID = OID_ICPBR_E_CPF_RG);
end;

end.
