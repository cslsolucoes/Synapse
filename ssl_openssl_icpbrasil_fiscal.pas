{==============================================================================|
| Project : Ararat Synapse (CSL fork)                            | 001.000.000 |
|==============================================================================|
| Content: Fiscal helpers for ICP-Brasil — NFe/eSocial/Serpro/Sefaz/EFD-Reinf  |
|          (S14 — v42.1)                                                       |
|==============================================================================|
| Copyright (c)2026, CSL Tech Solutions                                        |
| All rights reserved.                                                         |
|==============================================================================|
| Reference: ICP-Brasil DOC-ICP-04 v8.x; SEFAZ NT/RN; eSocial leiautes;        |
|            EFD-Reinf manual; Serpro AC documentation                         |
|==============================================================================|
| History:                                                                     |
|   001.000.000 (2026-05-01): Criacao S14. Helpers fiscais one-liner para      |
|                             classificar certs por proposito (NFe, eSocial,   |
|                             Serpro, Sefaz, EFD-Reinf).                       |
|==============================================================================}

(*:@abstract(Fiscal helpers — One-liner classification of ICP-Brasil certs)

Conjunto de helpers que combinam validacoes de S8..S13 para responder
perguntas tipicas do dia-a-dia fiscal:

  - IsCertificadoNFe         — pode assinar NFe?
  - IsCertificadoESocial     — pode acessar eSocial?
  - IsCertificadoSerpro      — emitido pela AC SERPRO?
  - IsCertificadoSefaz       — emitido pela AC SEFAZ de uma UF?
  - IsCertificadoEFDReinf    — pode assinar EFD-Reinf?

Todos aceitam um TIcpBrasilCertificado ja preenchido por LerDoPfx.
*)

unit ssl_openssl_icpbrasil_fiscal;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  SysUtils,
  ssl_openssl_icpbrasil_types;

{ Verifica se cert pode assinar NFe.
  Criterio: e-CNPJ valido + EKU clientAuth + cert valido. }
function IsCertificadoNFe(const ACert: TIcpBrasilCertificado): Boolean;

{ Verifica se cert pode acessar eSocial. eSocial aceita e-CNPJ ou e-CPF
  com EKU clientAuth. }
function IsCertificadoESocial(const ACert: TIcpBrasilCertificado): Boolean;

{ Verifica se cert foi emitido pela AC SERPRO (subset ICP-Brasil). }
function IsCertificadoSerpro(const ACert: TIcpBrasilCertificado): Boolean;

{ Verifica se cert foi emitido pela AC SEFAZ de AUf (e.g. 'SP', 'RJ').
  Vazio em AUf aceita qualquer SEFAZ. }
function IsCertificadoSefaz(const ACert: TIcpBrasilCertificado;
                            const AUf: string): Boolean;

{ Verifica se cert pode assinar EFD-Reinf. Mesmo criterio do eSocial. }
function IsCertificadoEFDReinf(const ACert: TIcpBrasilCertificado): Boolean;

{ Helper geral: True se algum EKU OID em ACert.ExtKeyUsageOids casa com AOID. }
function HasExtKeyUsage(const ACert: TIcpBrasilCertificado;
                        const AOID: string): Boolean;

const
  EKU_CLIENT_AUTH    = '1.3.6.1.5.5.7.3.2';
  EKU_EMAIL_PROTECT  = '1.3.6.1.5.5.7.3.4';
  EKU_CODE_SIGNING   = '1.3.6.1.5.5.7.3.3';

implementation

function HasExtKeyUsage(const ACert: TIcpBrasilCertificado;
  const AOID: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(ACert.ExtKeyUsageOids) do
    if ACert.ExtKeyUsageOids[I] = AOID then
      Exit(True);
end;

function IsCertificadoNFe(const ACert: TIcpBrasilCertificado): Boolean;
begin
  Result := (ACert.Tipo = ibtECnpj) and
            ACert.DocumentoValido and
            ACert.EstaValido and
            (HasExtKeyUsage(ACert, EKU_CLIENT_AUTH) or
             (Length(ACert.ExtKeyUsageOids) = 0));   { alguns certs antigos sem EKU }
end;

function IsCertificadoESocial(const ACert: TIcpBrasilCertificado): Boolean;
begin
  Result := (ACert.Tipo in [ibtECnpj, ibtECpf]) and
            ACert.DocumentoValido and
            ACert.EstaValido and
            (HasExtKeyUsage(ACert, EKU_CLIENT_AUTH) or
             (Length(ACert.ExtKeyUsageOids) = 0));
end;

function _ContainsCI(const AHaystack, ANeedle: string): Boolean;
begin
  Result := (ANeedle <> '') and
            (Pos(LowerCase(ANeedle), LowerCase(AHaystack)) > 0);
end;

function IsCertificadoSerpro(const ACert: TIcpBrasilCertificado): Boolean;
begin
  Result := _ContainsCI(ACert.Certificadora, 'SERPRO') or
            _ContainsCI(ACert.Issuer, 'SERPRO');
end;

function IsCertificadoSefaz(const ACert: TIcpBrasilCertificado;
  const AUf: string): Boolean;
begin
  Result := _ContainsCI(ACert.Certificadora, 'SEFAZ') or
            _ContainsCI(ACert.Issuer, 'SEFAZ');
  if Result and (AUf <> '') then
    Result := _ContainsCI(ACert.Certificadora, AUf) or
              _ContainsCI(ACert.Issuer, AUf);
end;

function IsCertificadoEFDReinf(const ACert: TIcpBrasilCertificado): Boolean;
begin
  Result := IsCertificadoESocial(ACert);   { mesmo criterio }
end;

end.
