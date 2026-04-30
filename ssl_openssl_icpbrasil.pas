{==============================================================================|
| Project : Ararat Synapse                                       | 001.000.000 |
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
                            const ASenha: AnsiString): TIcpBrasilCertificado;

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
  ssl_openssl_x509_ext;

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

procedure ClassificarPorExtensoes(const AExtensions: TX509ExtensionArray;
  var AResult: TIcpBrasilCertificado);
var
  LBytes: TByteArray;
  LCnpj, LCpfResp, LRg, LEmissor, LNomeResp: string;
  LNasc: TDateTime;
begin
  if FindExtensionByOID(AExtensions, AnsiString(OID_ICPBR_E_CNPJ_DATA), LBytes) then
  begin
    AResult.Tipo := ibtECnpj;
    if ParseEcnpjData(LBytes, LCnpj) then
    begin
      AResult.SubjectDocumento := LCnpj;
      AResult.DocumentoFormatado := FormatarCnpj(LCnpj);
      AResult.DocumentoValido := IsCnpjValido(LCnpj);
    end;

    if FindExtensionByOID(AExtensions, AnsiString(OID_ICPBR_E_CNPJ_RESPONSAVEL), LBytes) then
      if ParseEcnpjResponsavel(LBytes, LNomeResp, LCpfResp, LNasc) then
      begin
        AResult.ResponsavelCpf := LCpfResp;
        AResult.ResponsavelNasc := LNasc;
      end;
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

class function TIcpBrasilCertificadoReader.LerDoPfx(const APfxBytes: array of Byte;
  const ASenha: AnsiString): TIcpBrasilCertificado;
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

    Result.NotBefore := TX509Ext.X509ASN1TimeToDateTimeUTC(TX509Ext.X509GetNotBefore(LCert));
    Result.NotAfter  := TX509Ext.X509ASN1TimeToDateTimeUTC(TX509Ext.X509GetNotAfter(LCert));

    LExtensions := TX509Ext.X509GetAllExtensions(LCert);
    ClassificarPorExtensoes(LExtensions, Result);

    FallbackSubjectCN(string(LCnRaw), Result);

    if Result.Tipo = ibtDesconhecido then
      raise EIcpBrasilNaoIcpBrasil.Create(
        'Certificado nao e e-CNPJ nem e-CPF ICP-Brasil. Subject CN: ' +
        string(LCnRaw));

  finally
    if Assigned(LCert) then X509Free(LCert);
    if Assigned(LPKey) then EvpPkeyFree(LPKey);
  end;
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
