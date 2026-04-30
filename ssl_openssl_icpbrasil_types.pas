{==============================================================================|
| Project : Ararat Synapse                                       | 001.000.000 |
|==============================================================================|
| Content: ICP-Brasil public types - TIcpBrasilCertificado record + exceptions |
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
| History: see HISTORY.HTM from distribution package                           |
|          (Found at URL: http://www.ararat.cz/synapse/)                       |
|==============================================================================}

{:@abstract(ICP-Brasil public types - TIcpBrasilCertificado record + 3 exceptions)

Record extracted from a PFX file. All fields can be empty if absent in cert.
}
unit ssl_openssl_icpbrasil_types;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils;

type
  { ICP-Brasil certificate classification. }
  TIcpBrasilTipo = (
    ibtDesconhecido,
    ibtECnpj,
    ibtECpf
  );

  { Complete record extracted from a PFX. All fields may be empty if absent. }
  TIcpBrasilCertificado = record
    Tipo:               TIcpBrasilTipo;
    Subject:            string;
    SubjectTitular:     string;
    SubjectDocumento:   string;
    DocumentoFormatado: string;
    DocumentoValido:    Boolean;
    Issuer:             string;
    IssuerSerial:       string;
    NotBefore:          TDateTime;
    NotAfter:           TDateTime;
    ResponsavelNome:    string;
    ResponsavelCpf:     string;
    ResponsavelNasc:    TDateTime;
    ResponsavelRg:      string;
    ResponsavelEmissor: string;
    Email:              string;
    OtherNamesRaw:      array of Byte;
  end;

  { Senha incorrect (PKCS12_parse failed). }
  EIcpBrasilSenhaInvalida = class(Exception);

  { Bytes are not a valid PKCS12 (corrupt, wrong format). }
  EIcpBrasilPfxCorrompido = class(Exception);

  { Cert is valid PKCS12 but has no recognized ICP-Brasil OIDs nor
    expected Subject CN format. Raised by LerDoPfx (strict mode). }
  EIcpBrasilNaoIcpBrasil  = class(Exception);

implementation

end.
