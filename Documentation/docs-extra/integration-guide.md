# Integration Guide — Synapse v41.5 fork extensions (X509 + ICP-Brasil)

> **V41.5 (S8)** — record `TIcpBrasilCertificado` agora expoe NumeroSerie,
> Thumbprints, DERBase64, Certificadora, Versao + 3 OIDs adicionais
> (`.5`/`.6`/`.8`) + helpers fiscais `MatchCnpjRaiz` e `EstaValidoEm`.
> Fallback automatico para OID `.3` (CNPJ legacy) garante compatibilidade
> com e-CNPJ A1 antigos.

## Pre-requisitos

- **Delphi 12+** ou **Lazarus/FPC** com `{$MODE DELPHI}`.
- **OpenSSL 3.x** runtime DLLs:
  - Windows: `libcrypto-3-x64.dll` (e `libssl-3-x64.dll` se for usar TLS).
  - Linux: `libcrypto.so.3`.
  - macOS: `libcrypto.3.dylib`.
- DLLs acessiveis via `PATH`, working dir, ou `TOpenSSLPaths.Apply(3)`.

## Instalacao via `synapse.dpk` (Delphi)

```pascal
// projeto consumidor (.dpr / .dproj):
uses
  ssl_openssl_x509_ext,
  ssl_openssl_icpbrasil,
  ssl_openssl_icpbrasil_subject;     // helpers MatchCnpjRaiz, FormatarCnpj, IsCnpjValido (V41.5)
```

Build flags exigidas:

- `{$IFDEF MSWINDOWS}` resolve corretamente em Delphi Win64.
- Namespace prefixes minimos: `-NSSystem;System.Win;Vcl;Winapi`.

## Instalacao via `laz_synapse.lpk` (Lazarus)

1. `Package > Open Package File (.lpk) > laz_synapse.lpk`.
2. `Compile > Use > Add to Project`.
3. Em projeto consumidor, `uses ssl_openssl_x509_ext, ssl_openssl_icpbrasil, ssl_openssl_icpbrasil_subject;`.

## Versionamento

Pinar versao explicita ao consumir:

```pascal
// Project home: https://github.com/<remote>/synapse
// Confirmed against: v41.5
```

A unidade `ssl_openssl_x509_ext.pas` e companion — **zero modificacao**
de `ssl_openssl3_lib.pas` ou `ssl_openssl4_lib.pas`. Mitiga risco de
upstream rebase.

## Politica de breaking changes

- **Patch (41.4.X / 41.5.X)**: bug fixes, nao quebra API publica.
- **Minor (41.X.0)**: novas features, mantem compatibilidade.
  - **V41.5 e backwards compatible** com V41.4: campos novos do record
    sao adicionados no fim; consumidores legados continuam a funcionar
    sem recompilar (record padding zero-init).
- **Major (XX.0.0)**: breaking changes (alteracao de assinaturas publicas,
  remocao de funcoes, mudanca de comportamento documentado).

## Quick smoke

### Smoke basico (compatibilidade V41.4)

```pascal
program test_v414;
{$APPTYPE CONSOLE}
uses
  ssl_openssl_icpbrasil;
begin
  WriteLn('OID e-CNPJ: ', OID_ICPBR_E_CNPJ_DATA);  // 2.16.76.1.3.7
  WriteLn('CNPJ valido (synthetic): ', IsCnpjValido('11222333000181'));
end.
```

### Smoke V41.5 — campos novos + helpers fiscais

```pascal
program test_v415;
{$APPTYPE CONSOLE}
uses
  SysUtils, Classes,
  ssl_openssl_icpbrasil,
  ssl_openssl_icpbrasil_oids,
  ssl_openssl_icpbrasil_subject;

var
  LBytes: TBytes;
  LCert: TIcpBrasilCertificado;
  LStream: TFileStream;
begin
  // Confirmar OIDs novos
  WriteLn('OID e-CNPJ legacy: ', OID_ICPBR_E_CNPJ_LEGACY);   // 2.16.76.1.3.3
  WriteLn('OID OAB:           ', OID_ICPBR_OAB);             // 2.16.76.1.3.10

  // Helper fiscal (8 digitos raiz)
  WriteLn('Match raiz matriz/filial: ',
          MatchCnpjRaiz(AnsiString('12345678000190'),
                        AnsiString('12345678000271')));      // True

  // Ler PFX (real fiscal)
  LStream := TFileStream.Create('cert.pfx', fmOpenRead);
  try
    SetLength(LBytes, LStream.Size);
    LStream.Read(LBytes[0], LStream.Size);
  finally
    LStream.Free;
  end;
  LCert := TIcpBrasilCertificadoReader.LerDoPfx(LBytes, AnsiString('senha'));

  WriteLn('Tipo:           ', Ord(LCert.Tipo));
  WriteLn('Documento:      ', LCert.DocumentoFormatado);
  WriteLn('Certificadora:  ', LCert.Certificadora);             // novo
  WriteLn('Numero serie:   ', LCert.NumeroSerie);               // novo
  WriteLn('Thumbprint:     ', LCert.ThumbPrintSHA256);          // novo
  WriteLn('DER tamanho:    ', Length(LCert.DERBase64));         // novo
  WriteLn('Versao X509:    v', LCert.Versao + 1);               // novo
  WriteLn('Esta valido:    ', LCert.EstaValido);                // novo (helper)
  WriteLn('Dias para venc: ', LCert.DiasParaExpirar);           // novo (helper)
end.
```

Se compila e roda, a integracao V41.5 esta funcional.

### Cenarios de uso fiscal

```pascal
// Validacao para assinar NFe — checa expiracao + raiz CNPJ
function PodeAssinarNFe(const ACertPfxBytes: TBytes;
  const ASenha: AnsiString;
  const ANFeEmitCnpj: AnsiString): Boolean;
var
  LCert: TIcpBrasilCertificado;
begin
  Result := False;
  LCert := TIcpBrasilCertificadoReader.LerDoPfx(ACertPfxBytes, ASenha);
  if LCert.Tipo <> ibtECnpj then Exit;
  if not LCert.DocumentoValido then Exit;
  if not LCert.EstaValido then Exit;
  if not MatchCnpjRaiz(LCert.SubjectDocumento, ANFeEmitCnpj) then Exit;
  Result := True;
end;

// Identificacao unica do certificado em logs/auditoria
function CertSignature(const ACert: TIcpBrasilCertificado): string;
begin
  Result := Format('%s | %s | SHA-256: %s',
    [ACert.Certificadora, ACert.NumeroSerieHex, ACert.ThumbPrintSHA256]);
end;
```

## Troubleshooting

| Sintoma | Causa provavel | Solucao |
| --- | --- | --- |
| `EIcpBrasilPfxCorrompido` em `Init` | libcrypto-3 nao carrega | Confirmar DLL no PATH; rodar `TOpenSSLPaths.Apply(3)` antes |
| `EIcpBrasilSenhaInvalida` | PKCS12_parse falhou | Confirmar senha; alguns PFX antigos usam AES-128 incompativel |
| `EIcpBrasilNaoIcpBrasil` em cert e-CNPJ A1 antigo | Cert tem so OID `.3` legacy (V41.4) | Atualizar para **V41.5** — fallback automatico para `.3` |
| `EIcpBrasilNaoIcpBrasil` mesmo em V41.5 | Cert nao tem nenhum OID `2.16.76.1.3.*` reconhecido | Usar `TentarLerDoPfx` (tolerante) ou validar Subject CN |
| `Versao = 0` no record | X509 v1 (raro hoje) | Aceitar — significa cert pre-2000; checa NotAfter |
| `NumeroSerie` vazio | OpenSSL 3 sem `BN_bn2dec` exposto (build minimal) | Usar `NumeroSerieHex` como fallback ou bumpar libcrypto |
| `Thumbprint` vazio | `EVP_sha1`/`sha256` nao resolveram | Verificar `TX509Ext.Init` retornou True; libcrypto-3 versao >= 3.0 |
| `Certificadora` vazio mas `Issuer` populado | Issuer DN nao tem `O=` (raro) | Cert nao-conforme DOC-ICP-04; usar `Issuer` directamente |
| Compila mas reader nao reconhece | OpenSSL 1.x carregada em vez de 3.x | `TX509Ext.Init` retorna False; logar para diagnostico |
