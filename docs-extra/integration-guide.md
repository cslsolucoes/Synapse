# Integration Guide — Synapse v41.4 fork extensions (X509 + ICP-Brasil)

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
  ssl_openssl_icpbrasil;
```

Build flags exigidas:

- `{$IFDEF MSWINDOWS}` resolve corretamente em Delphi Win64.
- Namespace prefixes minimos: `-NSSystem;System.Win;Vcl;Winapi`.

## Instalacao via `laz_synapse.lpk` (Lazarus)

1. `Package > Open Package File (.lpk) > laz_synapse.lpk`.
2. `Compile > Use > Add to Project`.
3. Em projeto consumidor, `uses ssl_openssl_x509_ext, ssl_openssl_icpbrasil;`.

## Versionamento

Pinar versao explicita ao consumir:

```pascal
// Project home: https://github.com/<remote>/synapse
// Confirmed against: v41.4
```

A unidade `ssl_openssl_x509_ext.pas` e companion - **zero modificacao**
de `ssl_openssl3_lib.pas` ou `ssl_openssl4_lib.pas`. Mitiga risco de
upstream rebase.

## Politica de breaking changes

- **Patch (41.4.X)**: bug fixes, nao quebra API publica.
- **Minor (41.X.0)**: novas features, mantem compatibilidade.
- **Major (XX.0.0)**: breaking changes (alteracao de assinaturas publicas,
  remocao de funcoes, mudanca de comportamento documentado).

## Quick smoke

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

Se compila e roda, a integracao esta funcional.

## Troubleshooting

| Sintoma | Causa provavel | Solucao |
| --- | --- | --- |
| `EIcpBrasilPfxCorrompido` em `Init` | libcrypto-3 nao carrega | Confirmar DLL no PATH; rodar `TOpenSSLPaths.Apply(3)` antes |
| `EIcpBrasilSenhaInvalida` | PKCS12_parse falhou | Confirmar senha; alguns PFX antigos usam AES-128 incompativel |
| `EIcpBrasilNaoIcpBrasil` | Cert nao tem OID 2.16.76.1.3.* | Usar `TentarLerDoPfx` (tolerante) ou validar Subject CN |
| Compila mas reader nao reconhece | OpenSSL 1.x carregada em vez de 3.x | `TX509Ext.Init` retorna False; logar para diagnostico |
