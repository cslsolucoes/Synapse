{==============================================================================|
| Project : Ararat Synapse                                       | 001.004.000 |
|==============================================================================|
| Content: ICP-Brasil PFX/X509 reader - public API                             |
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

{:@abstract(Public ICP-Brasil PFX reader. Orchestrates PKCS12 unwrap (via
            ssl_openssl_x509_ext) + Subject parsing + extension iteration +
            ICP-Brasil OtherName decode + CNPJ/CPF mod-11 validation.)

API:
  TIcpBrasilCertificadoReader.LerDoPfx       (raise on error)
  TIcpBrasilCertificadoReader.TentarLerDoPfx (returns False on no-ICP-Brasil)
}
unit ssl_openssl_icpbrasil;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils, Classes,
  ssl_openssl_icpbrasil_oids,
  ssl_openssl_icpbrasil_subject,
  ssl_openssl_icpbrasil_othername,
  ssl_openssl_icpbrasil_types;

type
  TIcpBrasilCertificadoReader = class
  public
    { Reads PFX, decrypts with senha, returns complete record. Exceptions:
        EIcpBrasilSenhaInvalida    - PKCS12_parse failed (wrong password)
        EIcpBrasilPfxCorrompido    - bytes are not valid PKCS12
        EIcpBrasilNaoIcpBrasil     - cert has no recognized ICP-Brasil OIDs
                                     and Subject CN fallback also fails
    }
    class function LerDoPfx(const APfxBytes: array of Byte;
                            const ASenha: AnsiString): TIcpBrasilCertificado; overload;

    { Extended overload (S9/V41.6) — accepts options record to enable
      optional chain validation and policy parsing. }
    class function LerDoPfx(const APfxBytes: array of Byte;
                            const ASenha: AnsiString;
                            const AOptions: TLerDoPfxOptions): TIcpBrasilCertificado; overload;

    { Tolerant version - returns record with Tipo=ibtDesconhecido instead of
      raising EIcpBrasilNaoIcpBrasil (useful for batch scanning). Other
      exceptions (senha, pfx corrupt) still propagate. }
    class function TentarLerDoPfx(const APfxBytes: array of Byte;
                                  const ASenha: AnsiString;
                                  out ARecord: TIcpBrasilCertificado): Boolean;
  end;

implementation

uses
  ssl_openssl3_lib,
  ssl_openssl_x509_ext,
  ssl_openssl_chain_verify,
  ssl_openssl_icpbrasil_policy,
  ssl_openssl_icpbrasil_extparsers,
  ssl_openssl_icpbrasil_crl,
  ssl_openssl_icpbrasil_ocsp,
  ssl_openssl_icpbrasil_san;

function FindExtensionByOID(const AExtensions: TX509ExtensionArray;
  const AOID: AnsiString; out ABytes: TByteArray): Boolean;
var
  I, J, LLen: Integer;
begin
  Result := False;
  SetLength(ABytes, 0);
  for I := 0 to High(AExtensions) do
    if AnsiString(AExtensions[I].OID) = AOID then
    begin
      LLen := Length(AExtensions[I].Data);
      SetLength(ABytes, LLen);
      for J := 0 to LLen - 1 do
        ABytes[J] := AExtensions[I].Data[J];
      Exit(True);
    end;
end;

function TentarExtrairCnpjPJ(const AExtensions: TX509ExtensionArray;
  out ACnpj: string): Boolean;
var
  LBytes: TByteArray;
begin
  Result := False;
  ACnpj := '';

  { Try modern OID .7 (DOC-ICP-04 v3+) first - present in most certs since 2008. }
  if FindExtensionByOID(AExtensions, AnsiString(OID_ICPBR_E_CNPJ_DATA), LBytes) then
    if ParseEcnpjData(LBytes, ACnpj) then
      Exit(True);

  { Fallback to legacy OID .3 (DOC-ICP-04 pre-v3) - some older e-CNPJ A1
    certs in circulation populate only this. Same 14-digit CNPJ format. }
  if FindExtensionByOID(AExtensions, AnsiString(OID_ICPBR_E_CNPJ_LEGACY), LBytes) then
    if ParseEcnpjData(LBytes, ACnpj) then
      Exit(True);
end;

procedure ColherExtensoesAdicionais(const AExtensions: TX509ExtensionArray;
  var AResult: TIcpBrasilCertificado);
var
  LBytes: TByteArray;
  LValor, LRgSep, LEmissorSep: string;
begin
  { OID 2.16.76.1.3.5 — Titulo de Eleitor }
  if FindExtensionByOID(AExtensions, AnsiString(OID_ICPBR_E_CPF_TITULO), LBytes) then
    if ParseTituloEleitor(LBytes, LValor) then
      AResult.TituloEleitor := LValor;

  { OID 2.16.76.1.3.6 — PIS/PASEP (v3) ou CAEPF/CEI (v6+) }
  if FindExtensionByOID(AExtensions, AnsiString(OID_ICPBR_E_CPF_INSS), LBytes) then
    if ParsePisOuCaepf(LBytes, LValor) then
      AResult.PisOuCaepf := LValor;

  { OID 2.16.76.1.3.8 — RG separado }
  if FindExtensionByOID(AExtensions, AnsiString(OID_ICPBR_E_CPF_RG), LBytes) then
    if ParseRgSeparado(LBytes, LRgSep, LEmissorSep) then
    begin
      AResult.RgSeparado := LRgSep;
      { If main RG/Emissor not yet populated by .1, populate from .8 too. }
      if AResult.ResponsavelRg = '' then
        AResult.ResponsavelRg := LRgSep;
      if (AResult.ResponsavelEmissor = '') and (LEmissorSep <> '') then
        AResult.ResponsavelEmissor := LEmissorSep;
    end;
end;

procedure ClassificarPorExtensoes(const AExtensions: TX509ExtensionArray;
  var AResult: TIcpBrasilCertificado);
var
  LBytes: TByteArray;
  LCnpj, LCpfResp, LRg, LEmissor, LNomeResp: string;
  LNasc: TDateTime;
begin
  if TentarExtrairCnpjPJ(AExtensions, LCnpj) then
  begin
    AResult.Tipo := ibtECnpj;
    AResult.SubjectDocumento := LCnpj;
    AResult.DocumentoFormatado := FormatarCnpj(LCnpj);
    AResult.DocumentoValido := IsCnpjValido(LCnpj);

    if FindExtensionByOID(AExtensions, AnsiString(OID_ICPBR_E_CNPJ_RESPONSAVEL), LBytes) then
      if ParseEcnpjResponsavel(LBytes, LNomeResp, LCpfResp, LNasc) then
      begin
        AResult.ResponsavelCpf := LCpfResp;
        AResult.ResponsavelNasc := LNasc;
      end;
    ColherExtensoesAdicionais(AExtensions, AResult);
    Exit;
  end;

  if FindExtensionByOID(AExtensions, AnsiString(OID_ICPBR_E_CPF_DATA), LBytes) then
  begin
    AResult.Tipo := ibtECpf;
    if ParseEcpfData(LBytes, LNasc, LCpfResp, LRg, LEmissor) then
    begin
      AResult.SubjectDocumento := LCpfResp;
      AResult.DocumentoFormatado := FormatarCpf(LCpfResp);
      AResult.DocumentoValido := IsCpfValido(LCpfResp);
      AResult.ResponsavelCpf := LCpfResp;
      AResult.ResponsavelNasc := LNasc;
      AResult.ResponsavelRg := LRg;
      AResult.ResponsavelEmissor := LEmissor;
    end;
    ColherExtensoesAdicionais(AExtensions, AResult);
    Exit;
  end;

  AResult.Tipo := ibtDesconhecido;
end;

procedure FallbackSubjectCN(const ACnRaw: string;
  var AResult: TIcpBrasilCertificado);
var
  LTitular, LDocumento: string;
begin
  AResult.Subject := ACnRaw;
  if ParseSubjectCN(ACnRaw, LTitular, LDocumento) then
  begin
    AResult.SubjectTitular := LTitular;
    if AResult.SubjectDocumento = '' then
      AResult.SubjectDocumento := LDocumento;

    if AResult.Tipo = ibtDesconhecido then
    begin
      AResult.Tipo := ClassificarDocumento(LDocumento);
      case AResult.Tipo of
        ibtECnpj:
        begin
          AResult.DocumentoFormatado := FormatarCnpj(LDocumento);
          AResult.DocumentoValido := IsCnpjValido(LDocumento);
        end;
        ibtECpf:
        begin
          AResult.DocumentoFormatado := FormatarCpf(LDocumento);
          AResult.DocumentoValido := IsCpfValido(LDocumento);
        end;
      end;
    end;
  end
  else
  begin
    AResult.SubjectTitular := Trim(ACnRaw);
  end;
end;

{ TIcpBrasilCertificadoReader }

procedure VerificarChainSeRequisitado(const ACert: PX509; const ACa: SslPtr;
  const AOptions: TLerDoPfxOptions; var AResult: TIcpBrasilCertificado);
var
  LVerifier: TX509ChainVerifier;
  LVerify: TVerifyResult;
  LBundlePath: string;
  LCount: Integer;
begin
  if not AOptions.VerificarChain then Exit;

  AResult.ChainVerificado := True;

  LBundlePath := AOptions.AcRaizBundlePath;
  if LBundlePath = '' then
    LBundlePath := 'bundles' + PathDelim + 'ac-raiz-icp-brasil.pem';

  LVerifier := TX509ChainVerifier.Create;
  try
    LCount := LVerifier.LoadStoreFromPEM(LBundlePath);
    if LCount <= 0 then
    begin
      AResult.ChainValido := False;
      AResult.ChainErro :=
        'Bundle AC-Raiz vazio ou nao encontrado em "' + LBundlePath +
        '". Rodar bundles/AC-Raiz-ICP-Brasil-fetch.ps1.';
      AResult.ChainErroCodigo := -1;
      Exit;
    end;
    LVerify := LVerifier.Verify(ACert, ACa);
    AResult.ChainValido       := LVerify.OK;
    AResult.ChainErro         := LVerify.ErrText;
    AResult.ChainErroCodigo   := LVerify.ErrCode;
    AResult.ChainProfundidade := LVerify.ChainProfundidade;
  finally
    LVerifier.Free;
  end;
end;

procedure ColherEnriquecimentoSubject(const AExtensions: TX509ExtensionArray;
  var AResult: TIcpBrasilCertificado);
const
  OID_SAN = '2.5.29.17';
  OID_KU  = '2.5.29.15';
  OID_EKU = '2.5.29.37';
var
  I, J: Integer;
  LBytes: TByteArray;
  LSAN: TSANInfo;
  LKU:  TKeyUsageInfo;
  LEKU: TExtKeyUsageInfo;
  LOABBytes: TByteArray;
  LOAB: TOABInfo;
begin
  for I := 0 to High(AExtensions) do
  begin
    if string(AExtensions[I].OID) = OID_SAN then
    begin
      SetLength(LBytes, Length(AExtensions[I].Data));
      if Length(LBytes) > 0 then
        Move(AExtensions[I].Data[0], LBytes[0], Length(LBytes));
      LSAN := ParseSAN(LBytes);
      if not LSAN.Encontrada then Continue;

      SetLength(AResult.DnsNames, Length(LSAN.DnsNames));
      for J := 0 to High(LSAN.DnsNames) do AResult.DnsNames[J] := LSAN.DnsNames[J];

      SetLength(AResult.IpAddresses, Length(LSAN.IpAddresses));
      for J := 0 to High(LSAN.IpAddresses) do AResult.IpAddresses[J] := LSAN.IpAddresses[J];

      SetLength(AResult.Uris, Length(LSAN.Uris));
      for J := 0 to High(LSAN.Uris) do AResult.Uris[J] := LSAN.Uris[J];

      SetLength(AResult.SanEmails, Length(LSAN.Emails));
      for J := 0 to High(LSAN.Emails) do AResult.SanEmails[J] := LSAN.Emails[J];

      if (Length(LSAN.Emails) > 0) and (AResult.Email = '') then
        AResult.Email := LSAN.Emails[0];
    end
    else if string(AExtensions[I].OID) = OID_KU then
    begin
      SetLength(LBytes, Length(AExtensions[I].Data));
      if Length(LBytes) > 0 then
        Move(AExtensions[I].Data[0], LBytes[0], Length(LBytes));
      LKU := ParseKeyUsage(LBytes);
      AResult.KeyUsageEncontrada := LKU.Encontrada;
      if LKU.Encontrada then
        AResult.KeyUsageStr := KeyUsageToString(LKU.Bits);
    end
    else if string(AExtensions[I].OID) = OID_EKU then
    begin
      SetLength(LBytes, Length(AExtensions[I].Data));
      if Length(LBytes) > 0 then
        Move(AExtensions[I].Data[0], LBytes[0], Length(LBytes));
      LEKU := ParseExtKeyUsage(LBytes);
      if LEKU.Encontrada then
      begin
        SetLength(AResult.ExtKeyUsageOids, Length(LEKU.Oids));
        SetLength(AResult.ExtKeyUsageNames, Length(LEKU.Oids));
        for J := 0 to High(LEKU.Oids) do
        begin
          AResult.ExtKeyUsageOids[J] := LEKU.Oids[J];
          AResult.ExtKeyUsageNames[J] := EkuOidName(LEKU.Oids[J]);
        end;
      end;
    end
    else if string(AExtensions[I].OID) = OID_ICPBR_OAB then
    begin
      SetLength(LOABBytes, Length(AExtensions[I].Data));
      if Length(LOABBytes) > 0 then
        Move(AExtensions[I].Data[0], LOABBytes[0], Length(LOABBytes));
      LOAB := ParseOAB(LOABBytes);
      if LOAB.Encontrada then
      begin
        AResult.OabNumero := LOAB.Numero;
        AResult.OabUf := LOAB.UF;
      end;
    end;
  end;
end;

procedure ColherUrlsAIAeCDP(const AExtensions: TX509ExtensionArray;
  var AResult: TIcpBrasilCertificado);
const
  OID_AIA = '1.3.6.1.5.5.7.1.1';
  OID_CDP = '2.5.29.31';
var
  I, J: Integer;
  LBytes: TByteArray;
  LAIA: TAIAInfo;
  LCDP: TCDPInfo;
begin
  for I := 0 to High(AExtensions) do
  begin
    if string(AExtensions[I].OID) = OID_AIA then
    begin
      SetLength(LBytes, Length(AExtensions[I].Data));
      if Length(LBytes) > 0 then
        Move(AExtensions[I].Data[0], LBytes[0], Length(LBytes));
      LAIA := ParseAIA(LBytes);
      SetLength(AResult.OcspUrls, Length(LAIA.OcspUrls));
      for J := 0 to High(LAIA.OcspUrls) do
        AResult.OcspUrls[J] := LAIA.OcspUrls[J];
      SetLength(AResult.CaIssuersUrls, Length(LAIA.CaIssuersUrls));
      for J := 0 to High(LAIA.CaIssuersUrls) do
        AResult.CaIssuersUrls[J] := LAIA.CaIssuersUrls[J];
    end
    else if string(AExtensions[I].OID) = OID_CDP then
    begin
      SetLength(LBytes, Length(AExtensions[I].Data));
      if Length(LBytes) > 0 then
        Move(AExtensions[I].Data[0], LBytes[0], Length(LBytes));
      LCDP := ParseCDP(LBytes);
      SetLength(AResult.CrlUrls, Length(LCDP.CrlUrls));
      for J := 0 to High(LCDP.CrlUrls) do
        AResult.CrlUrls[J] := LCDP.CrlUrls[J];
    end;
  end;
end;

procedure VerificarRevogacaoSeRequisitado(const ACert: PX509;
  const AOptions: TLerDoPfxOptions; var AResult: TIcpBrasilCertificado);
var
  LSerialHex: string;
  LDone: Boolean;

  function TryCRL: Boolean;
  var
    LCrlClient: TIcpBrasilCrlClient;
    LCrlRes: TCrlCheckResult;
    K: Integer;
  begin
    Result := False;
    if Length(AResult.CrlUrls) = 0 then Exit;
    LCrlClient := TIcpBrasilCrlClient.Create;
    try
      if AOptions.CrlCacheDir = '' then
        LCrlClient.CacheDir := 'caches' + PathDelim + 'crl'
      else
        LCrlClient.CacheDir := AOptions.CrlCacheDir;
      for K := 0 to High(AResult.CrlUrls) do
      begin
        if not LCrlClient.LoadFromUrl(AResult.CrlUrls[K]) then Continue;
        if not LCrlClient.IsRevogado(LSerialHex, LCrlRes) then Continue;
        AResult.RevogacaoVerificada := True;
        AResult.Revogado := LCrlRes.Revogado;
        AResult.RevogacaoMotivo := LCrlRes.Motivo;
        AResult.RevogacaoData := LCrlRes.DataRevogacao;
        AResult.RevogacaoFonte := 'CRL: ' + AResult.CrlUrls[K];
        AResult.RevogacaoTimestamp := SysUtils.Now;
        Exit(True);
      end;
    finally
      LCrlClient.Free;
    end;
  end;

  function TryOCSP: Boolean;
  begin
    Result := False;
    if Length(AResult.OcspUrls) = 0 then Exit;
    { Para OCSP precisamos do cert do issuer; em S10 ainda nao temos
      automaticamente. Skip silenciosamente — caller pode usar TIcpBrasilOcspClient
      directamente quando tiver issuer carregado (S10b/S11+). }
  end;

begin
  if AOptions.VerificarRevogacao = rmNone then Exit;

  AResult.RevogacaoVerificada := False;
  AResult.Revogado := False;
  AResult.RevogacaoTimestamp := SysUtils.Now;

  LSerialHex := AResult.NumeroSerieHex;
  if LSerialHex = '' then Exit;

  LDone := False;
  case AOptions.VerificarRevogacao of
    rmCRL:          LDone := TryCRL;
    rmOCSP:         LDone := TryOCSP;
    rmOCSPThenCRL:
      begin
        LDone := TryOCSP;
        if not LDone then LDone := TryCRL;
      end;
    rmCRLThenOCSP:
      begin
        LDone := TryCRL;
        if not LDone then LDone := TryOCSP;
      end;
  end;
end;

procedure VerificarPolicySeRequisitado(const AExtensions: TX509ExtensionArray;
  const AOptions: TLerDoPfxOptions; var AResult: TIcpBrasilCertificado);
const
  OID_CERT_POLICIES = '2.5.29.32';
var
  I, J: Integer;
  LBytes: TByteArray;
  LFound: Boolean;
  LPolicyInfo: TPolicyInfo;
begin
  if not AOptions.VerificarPolicy then Exit;

  AResult.PolicyVerificada := True;
  LFound := False;
  for I := 0 to High(AExtensions) do
    if string(AExtensions[I].OID) = OID_CERT_POLICIES then
    begin
      SetLength(LBytes, Length(AExtensions[I].Data));
      if Length(LBytes) > 0 then
        Move(AExtensions[I].Data[0], LBytes[0], Length(LBytes));
      LFound := True;
      Break;
    end;
  if not LFound then Exit;

  LPolicyInfo := ParseCertificatePolicies(LBytes);
  { Copy element-by-element — Delphi treats 'array of string' from
    different units as distinct types. }
  SetLength(AResult.PolicyOids, Length(LPolicyInfo.PolicyOids));
  for J := 0 to High(LPolicyInfo.PolicyOids) do
    AResult.PolicyOids[J] := LPolicyInfo.PolicyOids[J];
  AResult.PolicyValida     := LPolicyInfo.Valida;
  AResult.AcRaizDetectada  := LPolicyInfo.AcRaizDetectadaStr;
  AResult.AcRaizVersao     := LPolicyInfo.AcRaizDetectada;
end;

class function TIcpBrasilCertificadoReader.LerDoPfx(const APfxBytes: array of Byte;
  const ASenha: AnsiString;
  const AOptions: TLerDoPfxOptions): TIcpBrasilCertificado;
var
  LCert: PX509;
  LPKey: SslPtr;
  LCa:   SslPtr;
  LExtensions: TX509ExtensionArray;
  LCnRaw: AnsiString;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Tipo := ibtDesconhecido;

  if Length(APfxBytes) = 0 then
    raise EIcpBrasilPfxCorrompido.Create('Bytes do PFX vazios.');

  if not TX509Ext.Init then
    raise EIcpBrasilPfxCorrompido.Create(
      'Falha ao carregar libcrypto-3. Confirmar que OpenSSL 3 esta ' +
      'instalado e acessivel via PATH ou TOpenSSLPaths.Apply.');

  if not TX509Ext.PKCS12ReadFromBytes(APfxBytes, ASenha, LPKey, LCert, LCa) then
    raise EIcpBrasilSenhaInvalida.Create(
      'Senha do PFX incorreta ou bytes corrompidos.');

  try
    LCnRaw := TX509Ext.X509GetSubjectCN(LCert);
    Result.Subject := string(LCnRaw);
    Result.Issuer := string(TX509Ext.X509GetIssuerCN(LCert));
    Result.Certificadora := string(TX509Ext.X509GetIssuerO(LCert));

    Result.NotBefore := TX509Ext.X509ASN1TimeToDateTimeUTC(TX509Ext.X509GetNotBefore(LCert));
    Result.NotAfter  := TX509Ext.X509ASN1TimeToDateTimeUTC(TX509Ext.X509GetNotAfter(LCert));

    Result.NumeroSerie      := TX509Ext.X509GetSerialNumberDec(LCert);
    Result.NumeroSerieHex   := TX509Ext.X509GetSerialNumberHex(LCert);
    Result.ThumbPrintSHA1   := TX509Ext.X509GetThumbprintSHA1(LCert);
    Result.ThumbPrintSHA256 := TX509Ext.X509GetThumbprintSHA256(LCert);
    Result.DERBase64        := TX509Ext.X509GetDERBase64(LCert);
    Result.Versao           := TX509Ext.X509GetVersion(LCert);

    LExtensions := TX509Ext.X509GetAllExtensions(LCert);
    ClassificarPorExtensoes(LExtensions, Result);

    FallbackSubjectCN(string(LCnRaw), Result);

    { S9: validacoes opcionais (chain + policy). LCert e LCa precisam estar
      vivos durante a chain verify, por isso e feito antes do finally. }
    VerificarChainSeRequisitado(LCert, LCa, AOptions, Result);
    VerificarPolicySeRequisitado(LExtensions, AOptions, Result);

    { S10: AIA + CDP URLs sempre extraidas (custo baixo); revogacao opcional. }
    ColherUrlsAIAeCDP(LExtensions, Result);
    VerificarRevogacaoSeRequisitado(LCert, AOptions, Result);

    { S11: Subject enrichment (SAN/KU/EKU/OAB) — sempre extraido (custo baixo). }
    ColherEnriquecimentoSubject(LExtensions, Result);

    if Result.Tipo = ibtDesconhecido then
      raise EIcpBrasilNaoIcpBrasil.Create(
        'Certificado nao e e-CNPJ nem e-CPF ICP-Brasil. Subject CN: ' +
        string(LCnRaw));

  finally
    if Assigned(LCert) then X509Free(LCert);
    if Assigned(LPKey) then EvpPkeyFree(LPKey);
  end;
end;

class function TIcpBrasilCertificadoReader.LerDoPfx(const APfxBytes: array of Byte;
  const ASenha: AnsiString): TIcpBrasilCertificado;
var
  LDefaultOpts: TLerDoPfxOptions;
begin
  FillChar(LDefaultOpts, SizeOf(LDefaultOpts), 0);
  Result := LerDoPfx(APfxBytes, ASenha, LDefaultOpts);
end;

class function TIcpBrasilCertificadoReader.TentarLerDoPfx(
  const APfxBytes: array of Byte; const ASenha: AnsiString;
  out ARecord: TIcpBrasilCertificado): Boolean;
begin
  Result := False;
  FillChar(ARecord, SizeOf(ARecord), 0);
  ARecord.Tipo := ibtDesconhecido;
  try
    ARecord := LerDoPfx(APfxBytes, ASenha);
    Result := True;
  except
    on E: EIcpBrasilNaoIcpBrasil do
      Result := True;
  end;
end;

end.
