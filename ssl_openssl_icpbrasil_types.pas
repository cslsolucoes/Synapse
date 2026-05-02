{==============================================================================|
| Project : Ararat Synapse                                       | 001.004.000 |
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
    { Classification }
    Tipo:               TIcpBrasilTipo;

    { Subject identification }
    Subject:            string;
    SubjectTitular:     string;
    SubjectDocumento:   string;       // CPF (11) or CNPJ (14) digits, no separators
    DocumentoFormatado: string;       // 'XX.XXX.XXX/XXXX-XX' or 'XXX.XXX.XXX-XX'
    DocumentoValido:    Boolean;      // mod-11 check

    { Issuer / certifying authority }
    Issuer:             string;       // raw issuer CN
    IssuerSerial:       string;       // legacy field
    Certificadora:      string;       // O= of issuer (e.g. 'AC SOLUTI Multipla v5')

    { Validity }
    NotBefore:          TDateTime;    // UTC
    NotAfter:           TDateTime;    // UTC

    { Identification (X509-level) }
    NumeroSerie:        string;       // decimal serial
    NumeroSerieHex:     string;       // hex serial (uppercase, no separators)
    ThumbPrintSHA1:     string;       // hex SHA1 of DER (uppercase)
    ThumbPrintSHA256:   string;       // hex SHA256 of DER (uppercase)
    DERBase64:          string;       // X509 DER bytes Base64-encoded
    Versao:             Integer;      // X509 version (2 = v3, etc.)

    { Responsavel (PJ — legal person responsible / PF — own data) }
    ResponsavelNome:    string;
    ResponsavelCpf:     string;
    ResponsavelNasc:    TDateTime;
    ResponsavelRg:      string;
    ResponsavelEmissor: string;

    { Additional ICP-Brasil OID fields (DOC-ICP-04) }
    TituloEleitor:      string;       // OID 2.16.76.1.3.5
    PisOuCaepf:         string;       // OID 2.16.76.1.3.6 (PIS legacy / CAEPF v6+)
    RgSeparado:         string;       // OID 2.16.76.1.3.8 (RG when separated from .1)

    { Subject Alternative Name }
    Email:              string;       // first rfc822Name in SAN

    { Raw bytes for debugging / forensic auditing }
    OtherNamesRaw:      array of Byte;

    { ============================================================
      Chain validation (S9, V41.6) — populated only when caller passes
      AVerificarChain=True. Default LerDoPfx leaves these zeroed. }
    ChainVerificado:    Boolean;
    ChainValido:        Boolean;
    ChainErro:          string;
    ChainErroCodigo:    Integer;
    ChainProfundidade:  Integer;

    { Certificate Policies (ext 2.5.29.32) — populated when AVerificarPolicy=True. }
    PolicyVerificada:   Boolean;
    PolicyOids:         array of string;
    PolicyValida:       Boolean;
    AcRaizDetectada:    string;       // 'AC-Raiz V5' etc., '' se nenhuma reconhecida
    AcRaizVersao:       Integer;      // 1..10 ou 0

    { ============================================================
      S10 (V41.7) — Revocacao via CRL/OCSP. Populated only when
      AOptions.VerificarRevogacao <> rmNone. }
    RevogacaoVerificada: Boolean;
    Revogado:           Boolean;
    RevogacaoMotivo:    string;       // 'unspecified' / 'keyCompromise' / etc.
    RevogacaoData:      TDateTime;    // UTC; 0 se nao revogado
    RevogacaoFonte:     string;       // 'CRL: <url>' ou 'OCSP: <url>'
    RevogacaoTimestamp: TDateTime;    // UTC, momento da verificacao

    { S10 — URLs descobertas em AIA + CDP (ext 1.3.6.1.5.5.7.1.1 e 2.5.29.31). }
    OcspUrls:           array of string;
    CaIssuersUrls:      array of string;
    CrlUrls:            array of string;

    { ============================================================
      S11 (V41.8) — Subject enrichment. Sempre populado (custo baixo). }

    { SAN ext 2.5.29.17 — populates 'Email' principal tambem (primeiro rfc822). }
    DnsNames:           array of string;
    IpAddresses:        array of string;
    Uris:               array of string;
    SanEmails:          array of string;     // todos os emails (Email = primeiro)

    { KU ext 2.5.29.15 — bitmask de proposito. }
    KeyUsageEncontrada: Boolean;
    KeyUsageStr:        string;              // 'DigitalSignature, KeyEncipherment'

    { EKU ext 2.5.29.37 — array de OIDs (com nomes). }
    ExtKeyUsageOids:    array of string;
    ExtKeyUsageNames:   array of string;     // mesmas posicoes (ex: 'clientAuth')

    { OAB digital (OID 2.16.76.1.3.10). }
    OabNumero:          string;
    OabUf:              string;
  end;

  { Modo de verificacao de revogacao (S10). }
  TRevogacaoMode = (
    rmNone,             // sem verificacao (default)
    rmCRL,              // tenta CRL (CDP) apenas
    rmOCSP,             // tenta OCSP (AIA) apenas
    rmOCSPThenCRL,      // tenta OCSP primeiro; se falhar, fallback para CRL
    rmCRLThenOCSP       // tenta CRL primeiro; se falhar, fallback para OCSP
  );

  { Optional flags for LerDoPfx — added in S9/V41.6, expanded in S10/V41.7.
    Default-init (zero) preserves V41.4/V41.5 behavior. }
  TLerDoPfxOptions = record
    VerificarChain:     Boolean;      // se True, valida cadeia contra bundle AC-Raiz
    AcRaizBundlePath:   string;       // PEM path; '' = bundles/ac-raiz-icp-brasil.pem
    VerificarPolicy:    Boolean;      // se True, parsea Certificate Policies
    VerificarRevogacao: TRevogacaoMode; // S10
    CrlCacheDir:        string;       // S10; '' = caches/crl
    OcspTimeoutMs:      Integer;      // S10; 0 = 5000ms default
  end;

  { Helpers — record methods (Pascal extended records) }
  TIcpBrasilCertificadoHelper = record helper for TIcpBrasilCertificado
    { True when AData is in [NotBefore, NotAfter] inclusive (UTC). }
    function EstaValidoEm(const AData: TDateTime): Boolean;
    { Convenience: True when current UTC date is within validity window. }
    function EstaValido: Boolean;
    { Days remaining until expiration (negative if already expired). }
    function DiasParaExpirar: Integer;
  end;

  { Senha incorrect (PKCS12_parse failed). }
  EIcpBrasilSenhaInvalida = class(Exception);

  { Bytes are not a valid PKCS12 (corrupt, wrong format). }
  EIcpBrasilPfxCorrompido = class(Exception);

  { Cert is valid PKCS12 but has no recognized ICP-Brasil OIDs nor
    expected Subject CN format. Raised by LerDoPfx (strict mode). }
  EIcpBrasilNaoIcpBrasil  = class(Exception);

implementation

{ TIcpBrasilCertificadoHelper }

function TIcpBrasilCertificadoHelper.EstaValidoEm(const AData: TDateTime): Boolean;
begin
  Result := (NotBefore > 0) and (NotAfter > 0) and
            (AData >= NotBefore) and (AData <= NotAfter);
end;

function TIcpBrasilCertificadoHelper.EstaValido: Boolean;
begin
  Result := EstaValidoEm(SysUtils.Now);
end;

function TIcpBrasilCertificadoHelper.DiasParaExpirar: Integer;
var
  LDelta: Int64;
begin
  if NotAfter <= 0 then
    Exit(0);
  LDelta := Trunc(NotAfter - SysUtils.Now);
  if LDelta > High(Integer) then
    Result := High(Integer)
  else if LDelta < Low(Integer) then
    Result := Low(Integer)
  else
    Result := Integer(LDelta);
end;

end.
