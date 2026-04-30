{
| Project   : Ararat Synapse                                     |  v41.4     |
|==============================================================================|
| Content: ICP-Brasil public types - record + classifier enum + exceptions     |
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
