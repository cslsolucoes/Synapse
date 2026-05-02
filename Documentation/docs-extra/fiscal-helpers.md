# Helpers fiscais (NFe / eSocial / Serpro / Sefaz / EFD-Reinf) — V42.1+

> Documentação dos helpers fiscais entregues em **S14 (V42.1)** —
> sprint final que combina S8..S13 em funções one-liner para classificar
> certificados por propósito fiscal típico.

## Visão geral

Os helpers em `ssl_openssl_icpbrasil_fiscal.pas` consomem o record
`TIcpBrasilCertificado` já preenchido por `LerDoPfx` (com S8..S13 features
opt-in) e respondem perguntas tipicas:

| Helper | Pergunta respondida |
|---|---|
| `IsCertificadoNFe` | Pode assinar NFe? |
| `IsCertificadoESocial` | Pode acessar eSocial? |
| `IsCertificadoSerpro` | Foi emitido pela AC SERPRO? |
| `IsCertificadoSefaz(AUf)` | Foi emitido pela AC SEFAZ de uma UF? |
| `IsCertificadoEFDReinf` | Pode assinar EFD-Reinf? |
| `HasExtKeyUsage(AOID)` | Tem este OID em Extended Key Usage? |

## Componente

| Unit | Função |
|---|---|
| `ssl_openssl_icpbrasil_fiscal.pas` (001.000.000) | Helpers + dictionary `EkuOidName` |

## Critérios

### `IsCertificadoNFe`

```text
Tipo = ibtECnpj                    AND
DocumentoValido = True             AND
EstaValido (não expirado)          AND
(EKU clientAuth presente OR sem EKU)
```

- **e-CNPJ obrigatório** (não aceita e-CPF para NFe — emitente é PJ).
- Expiração checada via `EstaValido` (helper de record V41.5).
- EKU `1.3.6.1.5.5.7.3.2` (clientAuth) é o padrão para SEFAZ.
- Tolera certs antigos sem EKU explícito (raros mas em circulação).

### `IsCertificadoESocial`

```text
Tipo in [ibtECnpj, ibtECpf]        AND
DocumentoValido = True             AND
EstaValido                         AND
(EKU clientAuth OR sem EKU)
```

- Aceita **e-CNPJ** (empresa) **OU e-CPF** (empregador doméstico, MEI sem CNPJ, etc.).
- Demais critérios idênticos a NFe.

### `IsCertificadoSerpro`

```text
Match heurístico em Certificadora ('SERPRO') OR Issuer
```

- Procura "SERPRO" (case-insensitive) no `Issuer` ou `Certificadora`
  (extraído do `Issuer.O=`).
- Não verifica policy OID — match textual é suficiente em prática.
- AC SERPRO emite certs para órgãos federais (Receita, INSS, etc.).

### `IsCertificadoSefaz(AUf)`

```text
Match em 'SEFAZ' AND (AUf vazio OR match em AUf)
```

- Procura "SEFAZ" no Issuer/Certificadora.
- Se `AUf <> ''`, exige que UF (e.g. 'SP', 'RJ') também apareça.
- Útil para confirmar que cert é de SEFAZ específica (NFe estadual).

### `IsCertificadoEFDReinf`

Idêntico ao `IsCertificadoESocial` — EFD-Reinf usa mesmos critérios.

### `HasExtKeyUsage(AOID)`

Procura literal no array `ACert.ExtKeyUsageOids` (preenchido em S11).

## Constantes pre-definidas

```pascal
const
  EKU_CLIENT_AUTH    = '1.3.6.1.5.5.7.3.2';   // SEFAZ/eSocial/EFD
  EKU_EMAIL_PROTECT  = '1.3.6.1.5.5.7.3.4';   // S/MIME
  EKU_CODE_SIGNING   = '1.3.6.1.5.5.7.3.3';   // assinatura de software
```

## Uso típico

### Validar cert antes de emitir NFe

```pascal
uses
  ssl_openssl_icpbrasil,
  ssl_openssl_icpbrasil_fiscal,
  ssl_openssl_icpbrasil_subject;

var
  LCert: TIcpBrasilCertificado;
  LOpts: TLerDoPfxOptions;
begin
  FillChar(LOpts, SizeOf(LOpts), 0);
  LOpts.VerificarChain := True;
  LCert := TIcpBrasilCertificadoReader.LerDoPfx(LPfxBytes, LSenha, LOpts);

  if not IsCertificadoNFe(LCert) then
    raise Exception.Create('Cert não habilitado para NFe.');

  // Se houver CNPJ específico do emitente (NF do XML), confirmar match
  if not MatchCnpjRaiz(LCert.SubjectDocumento, ANFeEmitCnpj) then
    raise Exception.Create('CNPJ do cert não bate com emitente da NFe.');

  // Pode prosseguir com assinatura...
end;
```

### Filtrar lote de PFX por aplicabilidade fiscal

```pascal
var
  LFiles: TStringDynArray;
  I: Integer;
  LCert: TIcpBrasilCertificado;
begin
  LFiles := TDirectory.GetFiles('certs/', '*.pfx');
  WriteLn('NFe-capable certs:');
  for I := 0 to High(LFiles) do
  begin
    if not TIcpBrasilCertificadoReader.TentarLerDoPfx(
              TFile.ReadAllBytes(LFiles[I]), 'senha', LCert) then
      Continue;
    if IsCertificadoNFe(LCert) then
      WriteLn('  ', LFiles[I], ' (', LCert.DocumentoFormatado, ')');
  end;
end;
```

### Auto-classificação de cert

```pascal
var
  LCert: TIcpBrasilCertificado;
  LPurposes: TStringList;
begin
  LCert := TIcpBrasilCertificadoReader.LerDoPfx(LPfxBytes, LSenha);
  LPurposes := TStringList.Create;
  try
    if IsCertificadoNFe(LCert)        then LPurposes.Add('NFe');
    if IsCertificadoESocial(LCert)    then LPurposes.Add('eSocial');
    if IsCertificadoEFDReinf(LCert)   then LPurposes.Add('EFD-Reinf');
    if IsCertificadoSerpro(LCert)     then LPurposes.Add('SERPRO');
    if IsCertificadoSefaz(LCert, '')  then LPurposes.Add('SEFAZ');
    if HasExtKeyUsage(LCert, '1.3.6.1.4.1.311.20.2.2') then
      LPurposes.Add('SmartCardLogon');
    if HasExtKeyUsage(LCert, EKU_EMAIL_PROTECT) then
      LPurposes.Add('S/MIME');
    WriteLn('Cert ', LCert.DocumentoFormatado,
            ' habilitado para: ', LPurposes.CommaText);
  finally
    LPurposes.Free;
  end;
end;
```

## Limitações V42.1

- **Match heurístico** em `Certificadora`/`Issuer` para detecção
  Serpro/Sefaz — depende do nome da AC ser textualmente reconhecível.
  Não usa policy OID (`2.16.76.1.2.*`) que seria mais robusto.
- **Não valida CRL/OCSP** — caller deve passar `VerificarRevogacao` em
  `LerDoPfx` se quiser revogação considerada.
- **Tolerância EKU** — aceita certs sem EKU como "permitido para tudo".
  Em produção, considerar reforçar para exigir EKU explícito conforme
  política do consumidor.

## Roadmap

- **V42.2** — Detecção via Policy OID (mais robusto que match textual em nome).
- **V42.2** — Helpers para sub-domínios fiscais: `IsCertificadoCTe`,
  `IsCertificadoMDFe`, `IsCertificadoNFCe`, `IsCertificadoCFE`.
- **V42.3** — `IsCertificadoOAB` baseado em campo `OabNumero` populado em S11.

## Referências

- [SEFAZ NT NFe - Manual de Assinatura](https://www.nfe.fazenda.gov.br/portal/listaConteudo.aspx?tipoConteudo=04BIflQt1aY=)
- [eSocial - Layouts e validações](https://www.gov.br/esocial)
- [EFD-Reinf - Manual](http://sped.rfb.gov.br/projeto/show/1196)
- [Serpro AC - Lista de servicos](https://www.gov.br/serpro)
