{==============================================================================|
| Project : Ararat Synapse (CSL fork)                            | 001.001.000 |
|==============================================================================|
| Content: ICP-Brasil DOC-ICP-04 OIDs (Brazilian PKI tropicalization)          |
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
| Reference: ITI / DOC-ICP-04 - https://www.gov.br/iti/pt-br                   |
|==============================================================================|
| History: see HISTORY.HTM from distribution package                           |
|          (Found at URL: http://www.ararat.cz/synapse/)                       |
|==============================================================================}

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

{ Legal person name (PJ — DOC-ICP-04 pre-v3, legacy). Rare today; some
  certs from older CAs still populate this instead of the newer .7. }
function OID_ICPBR_PJ_NOME_LEGACY: string;

{ Legal person CNPJ (DOC-ICP-04 pre-v3, legacy). PrintableString with 14
  digits. ACBr reads this OID; older e-CNPJ A1 certs in circulation may
  populate only this and not the modern .7. Use as fallback. }
function OID_ICPBR_E_CNPJ_LEGACY: string;

{ e-CPF voter title. PrintableString number/zone/section/municipality/UF. }
function OID_ICPBR_E_CPF_TITULO: string;

{ e-CPF PIS/PASEP (11 digits) — DOC-ICP-04 v3.
  CAEPF (14 digits) or CEI (12 digits) — DOC-ICP-04 v6+ (CEI deprecated 2018). }
function OID_ICPBR_E_CPF_INSS: string;

{ e-CNPJ data of legal person (14 digits CNPJ — DOC-ICP-04 v3+). }
function OID_ICPBR_E_CNPJ_DATA: string;

{ e-CNPJ data of natural person responsible (same format as e-CPF data). }
function OID_ICPBR_E_CNPJ_RESPONSAVEL: string;

{ e-CPF RG and issuing body. }
function OID_ICPBR_E_CPF_RG: string;

{ OAB digital (Ordem dos Advogados do Brasil) — number + UF. }
function OID_ICPBR_OAB: string;

{ ICP-Brasil OID tree root prefix. }
function OID_ICPBR_ROOT_PREFIX: string;

{ Returns True if OID belongs to legal person (PJ) certificate group. }
function IsOidIcpBrasilPJ(const AOID: string): Boolean;

{ Returns True if OID belongs to natural person (PF) certificate group. }
function IsOidIcpBrasilPF(const AOID: string): Boolean;

implementation

function OID_ICPBR_E_CPF_DATA: string;          begin Result := '2.16.76.1.3.1'; end;
function OID_ICPBR_PJ_NOME_LEGACY: string;      begin Result := '2.16.76.1.3.2'; end;
function OID_ICPBR_E_CNPJ_LEGACY: string;       begin Result := '2.16.76.1.3.3'; end;
function OID_ICPBR_E_CNPJ_RESPONSAVEL: string;  begin Result := '2.16.76.1.3.4'; end;
function OID_ICPBR_E_CPF_TITULO: string;        begin Result := '2.16.76.1.3.5'; end;
function OID_ICPBR_E_CPF_INSS: string;          begin Result := '2.16.76.1.3.6'; end;
function OID_ICPBR_E_CNPJ_DATA: string;         begin Result := '2.16.76.1.3.7'; end;
function OID_ICPBR_E_CPF_RG: string;            begin Result := '2.16.76.1.3.8'; end;
function OID_ICPBR_OAB: string;                 begin Result := '2.16.76.1.3.10'; end;
function OID_ICPBR_ROOT_PREFIX: string;         begin Result := '2.16.76.1.3.';  end;

function IsOidIcpBrasilPJ(const AOID: string): Boolean;
begin
  Result := (AOID = OID_ICPBR_E_CNPJ_DATA) or
            (AOID = OID_ICPBR_E_CNPJ_LEGACY) or
            (AOID = OID_ICPBR_PJ_NOME_LEGACY) or
            (AOID = OID_ICPBR_E_CNPJ_RESPONSAVEL);
end;

function IsOidIcpBrasilPF(const AOID: string): Boolean;
begin
  Result := (AOID = OID_ICPBR_E_CPF_DATA) or
            (AOID = OID_ICPBR_E_CPF_TITULO) or
            (AOID = OID_ICPBR_E_CPF_INSS) or
            (AOID = OID_ICPBR_E_CPF_RG) or
            (AOID = OID_ICPBR_OAB);
end;

end.
