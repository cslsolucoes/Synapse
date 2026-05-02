# Revogação programática (CRL + OCSP) — V41.7+

> Documentação da camada de revogação entregue em **S10 (V41.7)**:
> validação programática se um certificado foi revogado pela AC, sem
> depender do SO ou do TLS handshake.

## Visão geral

Antes de V41.7, o Synapse validava **cadeia** (S9) mas não **revogação**.
Cert válido na cadeia podia estar revogado pela AC e o leitor não detectava.
S10 fecha essa lacuna com:

- **CRL** (`Certificate Revocation List`, RFC 5280 §5) — lista offline de
  certificados revogados, baixada por URL e cacheada em filesystem.
- **OCSP** (`Online Certificate Status Protocol`, RFC 6960) — query online
  ao responder OCSP da AC para um cert específico.
- **AIA** (`Authority Information Access`, ext `1.3.6.1.5.5.7.1.1`) —
  extracção automática de URLs OCSP/caIssuers do cert.
- **CDP** (`CRL Distribution Points`, ext `2.5.29.31`) — extracção
  automática de URLs CRL do cert.

## Componentes

| Unit | Classe/Função | Função |
|---|---|---|
| `ssl_openssl_chain_verify.pas` | `TX509ChainVerifier.LoadCrlFromBytes` etc. | Bindings CRL OpenSSL — carregar/validar CRL, lookup por serial |
| `ssl_openssl_icpbrasil_crl.pas` | `TIcpBrasilCrlClient` | Cliente CRL com cache filesystem + download via httpsend |
| `ssl_openssl_icpbrasil_ocsp.pas` | `TIcpBrasilOcspClient` | Cliente OCSP com bindings auto-contidos + POST via httpsend |
| `ssl_openssl_icpbrasil_extparsers.pas` | `ParseAIA` / `ParseCDP` | Parsers de URLs nas extensões X509 |

## Uso integrado em `LerDoPfx`

```pascal
uses
  ssl_openssl_icpbrasil,
  ssl_openssl_icpbrasil_types;

var
  LCert: TIcpBrasilCertificado;
  LOpts: TLerDoPfxOptions;
begin
  FillChar(LOpts, SizeOf(LOpts), 0);
  LOpts.VerificarChain      := True;
  LOpts.VerificarRevogacao  := rmCRL;        // ou rmOCSP, rmOCSPThenCRL, rmCRLThenOCSP
  LOpts.CrlCacheDir         := 'caches/crl';

  LCert := TIcpBrasilCertificadoReader.LerDoPfx(LPfxBytes, LSenha, LOpts);

  WriteLn('AIA OCSP URLs: ', Length(LCert.OcspUrls));
  WriteLn('CDP CRL URLs:  ', Length(LCert.CrlUrls));

  if LCert.RevogacaoVerificada then
  begin
    if LCert.Revogado then
      WriteLn(Format('REVOGADO em %s — motivo: %s — fonte: %s',
        [DateTimeToStr(LCert.RevogacaoData),
         LCert.RevogacaoMotivo, LCert.RevogacaoFonte]))
    else
      WriteLn('Cert nao revogado (verificado em ', LCert.RevogacaoFonte, ')');
  end;
end;
```

## Modos de revogação (`TRevogacaoMode`)

| Modo | Comportamento |
|---|---|
| `rmNone` | Sem verificação (default — preserva V41.6) |
| `rmCRL` | Tenta CRL apenas (offline, baixa CRL via CDP) |
| `rmOCSP` | Tenta OCSP apenas (online, query via AIA) |
| `rmOCSPThenCRL` | OCSP primeiro; fallback CRL se OCSP falhar |
| `rmCRLThenOCSP` | CRL primeiro; fallback OCSP se CRL falhar |

## Cliente CRL standalone

```pascal
uses ssl_openssl_icpbrasil_crl;

var
  LClient: TIcpBrasilCrlClient;
  LRes:    TCrlCheckResult;
begin
  LClient := TIcpBrasilCrlClient.Create;
  try
    LClient.CacheDir := 'caches/crl';
    if not LClient.LoadFromUrl('http://crl.acsoluti.com.br/multipla.crl') then
      raise Exception.Create('CRL falhou: ' + LClient.LastError);

    WriteLn('CRL carregada. NextUpdate: ',
            DateTimeToStr(LClient.CrlInfo.NextUpdate));
    WriteLn('Certs revogados: ', LClient.CrlInfo.NumRevoked);

    if LClient.IsRevogado('1A2B3C4D5E6F', LRes) then
    begin
      if LRes.Revogado then
        WriteLn('Revogado em ', DateTimeToStr(LRes.DataRevogacao))
      else
        WriteLn('Nao consta na CRL');
    end;
  finally
    LClient.Free;
  end;
end;
```

### Cache CRL

- Pasta configurável via `CacheDir` (default: nenhuma — sem cache).
- Filename derivado da URL (sanitizado, máx 100 chars + `.crl`).
- TTL: respeita `nextUpdate` da CRL — se passou, baixa nova.
- Se cache falhar (corrupted/missing), download fresco automático.

## Cliente OCSP standalone

```pascal
uses ssl_openssl_icpbrasil_ocsp;

var
  LClient: TIcpBrasilOcspClient;
  LRes:    TOcspResult;
begin
  LClient := TIcpBrasilOcspClient.Create;
  try
    LClient.TimeoutMs := 5000;
    LRes := LClient.Check(ACert, AIssuer, 'http://ocsp.acsoluti.com.br/');
    case LRes.Status of
      ocspGood:    WriteLn('OK em ', DateTimeToStr(LRes.ThisUpdate));
      ocspRevoked: WriteLn('REVOGADO em ', DateTimeToStr(LRes.RevokedAt));
      ocspUnknown: WriteLn('OCSP desconhece este cert.');
      ocspError:   WriteLn('Erro: ', LRes.ErrorMsg);
    end;
  finally
    LClient.Free;
  end;
end;
```

### Limitações S10

- **OCSP integrado a `LerDoPfx`** — exige cert do **issuer** carregado para
  construir o request. Em V41.7 a extracção automática do issuer do PFX
  chain ainda não está integrada — fluxo OCSP via `LerDoPfx` retorna
  sem-acao se issuer ausente. **Workaround**: usar `TIcpBrasilOcspClient`
  directamente quando tiver o issuer carregado (via `LCa` do PKCS#12 parse
  ou bundle AC-Raiz). CRL via CDP funciona stand-alone sem precisar do issuer.

- **Motivo de revogação** — actual implementação retorna `'unspecified'`.
  Parsing detalhado da extensão `reasonCode` (RFC 5280 §5.3.1) é trivial
  mas ficou fora do escopo S10.

- **OCSP signature verify** — `OCSP_basic_verify` está nos bindings mas
  ainda não invocado no fluxo padrão; verificar manualmente passando
  responder cert + trust store.

## Estrutura ASN.1 (referência)

```text
TimeStampReq ::= SEQUENCE {
   version           INTEGER,
   messageImprint    MessageImprint,
   reqPolicy         OBJECT IDENTIFIER OPTIONAL,
   nonce             INTEGER OPTIONAL,
   certReq           BOOLEAN DEFAULT FALSE
}
```

Para CRL:

```text
CertificateList ::= SEQUENCE {
   tbsCertList          TBSCertList,
   signatureAlgorithm   AlgorithmIdentifier,
   signature            BIT STRING
}

TBSCertList ::= SEQUENCE {
   version              INTEGER OPTIONAL,
   signature            AlgorithmIdentifier,
   issuer               Name,
   thisUpdate           Time,
   nextUpdate           Time OPTIONAL,
   revokedCertificates  SEQUENCE OF SEQUENCE { userCertificate, ... } OPTIONAL,
   ...
}
```

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `LoadFromUrl` retorna False | URL inacessível ou cert SSL inválido | Confirmar conectividade; CRL é geralmente HTTP (não HTTPS) |
| `IsRevogado` retorna False com cache | Cache stale + offline | Verificar `CrlInfo.NextUpdate`; forçar download apagando cache |
| OCSP retorna `ocspError` HTTP 405 | Responder não aceita POST sem header `Host` correto | Verificar `httpsend` envia headers HTTP/1.1 corretos |
| OCSP retorna `ocspError` HTTP 200 | Response não-padrão (binário corrompido) | Salvar `LRes.RawResponse` para debug com `openssl ocsp -resp_text` |
| `Revogado=False` mas certificado revogado | CRL carregada não é da AC correcta (issuer mismatch) | Chamar `LClient.VerifySignature(AIssuer)` antes de `IsRevogado` |

## Referências

- [RFC 5280 §5 — Certificate Revocation List](https://datatracker.ietf.org/doc/html/rfc5280#section-5)
- [RFC 6960 — OCSP](https://datatracker.ietf.org/doc/html/rfc6960)
- [DOC-ICP-04 §revocation policies](https://www.gov.br/iti/pt-br)
- ITI Lista de AC com endpoints CRL/OCSP: <https://estrutura.iti.gov.br>
