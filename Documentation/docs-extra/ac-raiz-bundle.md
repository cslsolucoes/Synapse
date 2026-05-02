# AC-Raiz ICP-Brasil — bundle e validacao de cadeia (V41.6+)

> Documentacao da nova capacidade entregue em S9 (v41.6): validacao de
> cadeia X509 offline contra AC-Raiz ICP-Brasil v1..v10.

## Visao geral

Antes de V41.6, o leitor `TIcpBrasilCertificadoReader.LerDoPfx` apenas
**lia** os campos do certificado, sem verificar se foi emitido por uma
AC-Raiz reconhecida. A partir de V41.6, o consumidor pode opcionalmente
validar a cadeia contra um bundle de AC-Raiz autoritativas.

Componentes:

1. **`ssl_openssl_chain_verify.pas` (CSL S9)** — Companion com bindings
   para `X509_STORE_*`, `X509_STORE_CTX_*`, `X509_verify_cert` e
   `PEM_read_bio_X509`. Expoe classe `TX509ChainVerifier`.
2. **`ssl_openssl_icpbrasil_policy.pas` (CSL S9)** — Parser da extensao
   `Certificate Policies` (`2.5.29.32`), classifica OIDs ITI
   (`2.16.76.1.2.*`) por versao de AC-Raiz (V1..V10).
3. **`bundles/AC-Raiz-ICP-Brasil-fetch.ps1` (CSL S9)** — Script PowerShell
   que baixa as AC-Raiz vigentes do ITI e gera bundle PEM.
4. **Integracao em `LerDoPfx`** — parametro opcional para chain verify
   automatico.

## Arquitectura

```text
+----------------------------------------+
| Cliente (consumidor)                   |
| LerDoPfx(bytes, senha,                 |
|          AVerificarChain=True)         |
+--+-------------------------------------+
   |
   v
+----------------------------------------+
| ssl_openssl_icpbrasil.pas              |
|  - PKCS12ReadFromBytes                 |
|  - ClassificarPorExtensoes (S8)        |
|  - VerificarChain (S9, opcional)       |
+--+-------------------------------------+
   |
   +--> TX509ChainVerifier.Verify
   |      (ssl_openssl_chain_verify)
   |       --> X509_STORE_CTX_new
   |       --> X509_STORE_CTX_init
   |       --> X509_verify_cert
   |       --> X509_STORE_CTX_get_error
   |
   +--> ParseCertificatePolicies
          (ssl_openssl_icpbrasil_policy)
           --> asn1util.ASNItem (TLV decoder)
           --> IsIcpBrasilPolicyOid
```

## Como usar

### Caminho 1 — Chain verify standalone

```pascal
uses
  ssl_openssl_x509_ext,        // PKCS12ReadFromBytes
  ssl_openssl_chain_verify;    // TX509ChainVerifier

var
  LCert: PX509;
  LKey, LCa: SslPtr;
  LVerifier: TX509ChainVerifier;
  LResult:   TVerifyResult;
  LBundleCount: Integer;
begin
  // 1. Carrega o PFX
  if not TX509Ext.PKCS12ReadFromBytes(LPfxBytes, LSenha, LKey, LCert, LCa) then
    raise Exception.Create('PFX read failed');
  try
    // 2. Cria verifier e carrega bundle AC-Raiz
    LVerifier := TX509ChainVerifier.Create;
    try
      LBundleCount := LVerifier.LoadStoreFromPEM('bundles/ac-raiz-icp-brasil.pem');
      if LBundleCount <= 0 then
        raise Exception.Create('AC-Raiz bundle vazio. Rodar AC-Raiz-ICP-Brasil-fetch.ps1');

      // 3. Valida cadeia (passa LCa para incluir intermediarias do PFX)
      LResult := LVerifier.Verify(LCert, LCa);
      if LResult.OK then
        WriteLn('Cert ', LResult.SubjectCN, ' validado contra AC-Raiz ICP-Brasil')
      else
        WriteLn(Format('Chain invalida [%d]: %s',
          [LResult.ErrCode, LResult.ErrText]));
    finally
      LVerifier.Free;
    end;
  finally
    if Assigned(LCert) then X509Free(LCert);
    if Assigned(LKey) then EvpPkeyFree(LKey);
  end;
end;
```

### Caminho 2 — Chain verify integrado em LerDoPfx (S9-B6)

```pascal
uses
  ssl_openssl_icpbrasil;

var
  LCert: TIcpBrasilCertificado;
  LOpts: TLerDoPfxOptions;
begin
  LOpts.VerificarChain := True;
  LOpts.AcRaizBundlePath := 'bundles/ac-raiz-icp-brasil.pem';
  LOpts.VerificarPolicy := True;

  LCert := TIcpBrasilCertificadoReader.LerDoPfxOpt(LPfxBytes, LSenha, LOpts);

  if not LCert.ChainValido then
    WriteLn('AVISO: cadeia invalida — ', LCert.ChainErro);

  if LCert.AcRaizDetectada <> '' then
    WriteLn('AC-Raiz: ', LCert.AcRaizDetectada);    // 'AC-Raiz V5'
end;
```

> Verificacao opcional — `VerificarChain := False` mantem comportamento
> V41.4/V41.5 (apenas leitura de campos).

## Codigos de erro (X509_V_ERR_*)

Os codigos retornados em `TVerifyResult.ErrCode` sao constantes
`X509_V_ERR_*` definidas em `ssl_openssl3_lib.pas`. Comuns:

| Codigo (decimal) | Constante | Significado |
| --- | --- | --- |
| 0 | `X509_V_OK` | Cadeia valida ate raiz reconhecida |
| 2 | `X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT` | Issuer nao no store/chain |
| 3 | `X509_V_ERR_UNABLE_TO_GET_CRL` | CRL nao disponivel (S10) |
| 7 | `X509_V_ERR_CERT_SIGNATURE_FAILURE` | Cert nao foi assinado pelo issuer indicado |
| 9 | `X509_V_ERR_CERT_NOT_YET_VALID` | NotBefore no futuro (clock skew?) |
| 10 | `X509_V_ERR_CERT_HAS_EXPIRED` | NotAfter no passado |
| 18 | `X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT` | Cert auto-assinado (nao confiavel) |
| 19 | `X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN` | Self-signed no meio da cadeia |
| 20 | `X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY` | **Comum:** AC-Raiz nao no bundle |
| 21 | `X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE` | Sig do leaf falhou |
| 22 | `X509_V_ERR_CERT_CHAIN_TOO_LONG` | Cadeia muito longa |
| 24 | `X509_V_ERR_INVALID_CA` | Issuer nao tem `cA: TRUE` no Basic Constraints |
| 26 | `X509_V_ERR_INVALID_PURPOSE` | EKU nao casa com proposito (S11) |
| 27 | `X509_V_ERR_CERT_UNTRUSTED` | Cert na chain nao e trusted |

`TVerifyResult.ErrText` ja traz a string humano-legivel via
`X509_verify_cert_error_string`.

## AC-Raiz reconhecidas (vigente em DOC-ICP-04 v8.x)

| Versao | Subject | Algoritmo | NotAfter (referencia) |
| --- | --- | --- | --- |
| V1 | AC-Raiz Brasileira | RSA SHA-1 | 2011 (descontinuada) |
| V2 | AC-Raiz Brasileira V2 | RSA SHA-256 | 2023 |
| V3 | AC-Raiz Brasileira V3 | RSA SHA-256 | 2025 |
| V4 | AC-Raiz Brasileira V4 | RSA SHA-256 | 2026 |
| V5 | AC-Raiz Brasileira V5 | RSA SHA-512 | 2028 |
| V6 | AC-Raiz Brasileira V6 | ECDSA P-521 | 2028 |
| V7 | AC-Raiz Brasileira V7 | RSA SHA-512 | 2034 |
| V8 | AC-Raiz Brasileira V8 | ECDSA P-521 | 2034 |
| V9 | AC-Raiz Brasileira V9 | RSA SHA-512 | 2042 |
| V10 | AC-Raiz Brasileira V10 | ECDSA P-521 | 2042 |

> **Datas e algoritmos:** referencia aproximada — checar `NotAfter` do
> bundle baixado. Bundle gerado pelo script tem comentarios com Subject
> e validade reais.

## Refresh schedule recomendado

- **Producao:** cron mensal — rodar `AC-Raiz-ICP-Brasil-fetch.ps1`.
- **Build artifact:** se preferir bundle commitado, baixar uma vez em CI
  e committar; auditar manualmente a cada 6 meses.
- **Eventos ITI:** quando ITI publicar V11+ ou revogar V<N>, atualizar
  imediatamente. Subscrever boletins em
  [https://www.gov.br/iti/pt-br/assuntos](https://www.gov.br/iti/pt-br/assuntos).

## Limitacoes em V41.6

- **CRL (revogacao)** ainda nao verificada — agendado para S10 (V41.7).
- **OCSP** idem — S10.
- **AIA auto-fetch** (AC intermediaria nao no PFX) — S10.
- **Embedding** do bundle em build (sem dependencia de filesystem) —
  futuro post-S9. Por agora consumir bundle externo via `LoadStoreFromPEM`.

## Troubleshooting

| Sintoma | Causa provavel | Solucao |
| --- | --- | --- |
| `LoadStoreFromPEM` retorna 0 | Bundle vazio / arquivo inexistente | Rodar `AC-Raiz-ICP-Brasil-fetch.ps1` |
| `LoadStoreFromPEM` retorna `-1` | libcrypto-3 sem `PEM_read_bio_X509` | Verificar OpenSSL >= 3.0; rodar `TOpenSSLPaths.Apply(3)` |
| `Verify` retorna `ErrCode = 20` | AC-Raiz da cadeia nao esta no bundle | Bundle desatualizado — refresh |
| `Verify` retorna `ErrCode = 10` | NotAfter no passado | Cert expirou; renovar |
| `Verify` retorna `ErrCode = 7` | Sig invalida (cert adulterado ou wrong issuer) | **Critico** — investigar urgentemente |
| `Verify` retorna `ErrCode = 21` | Sig do leaf falhou | Mismatch entre cert e issuer claimed |
