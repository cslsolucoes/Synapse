# Assinatura PKCS#7/CAdES + Time-stamping RFC 3161 — V41.9+

> Documentação da camada de assinatura entregue em **S12 (V41.9)**:
> Synapse passa a ser **standalone para emissão fiscal** — sem dependência
> de XmlSec/MSXML para gerar CAdES-T (padrão NFe + eSocial).

## Visão geral

CAdES (CMS Advanced Electronic Signatures, ETSI EN 319 122) é o padrão
europeu/ICP-Brasil para assinatura digital long-term. Variantes:

- **CAdES-BES** (Basic Electronic Signature) — assinatura PKCS#7 com
  atributos obrigatórios (`signingTime`, `messageDigest`, `contentType`,
  `signingCertificateV2`).
- **CAdES-T** (Timestamp) — BES + timestamp RFC 3161 anexado como
  unsigned attribute.
- **CAdES-X**, **CAdES-A** — variantes com revocation references e
  timestamps recursivos para arquivamento longo prazo.

V41.9 entrega **CAdES-BES + RFC 3161 timestamp** (componentes para BES e T).

## Componentes

| Unit | Classe | Função |
|---|---|---|
| `ssl_openssl_icpbrasil_pkcs7.pas` | `TPkcs7Signer` | Assinatura PKCS#7 detached/attached/binário/B64 |
| `ssl_openssl_icpbrasil_tsp.pas` | `TTspClient` | Cliente RFC 3161 (POST request, parse response) |

## PKCS#7 / CAdES-BES detached (padrão NFe)

```pascal
uses
  ssl_openssl_x509_ext,           // PKCS12ReadFromBytes
  ssl_openssl_icpbrasil_pkcs7;    // TPkcs7Signer

var
  LCert: PX509;
  LKey, LCa: SslPtr;
  LSigner: TPkcs7Signer;
  LRes:    TPkcs7SignResult;
  LXmlBytes: TBytes;
begin
  // 1. Carregar PFX
  if not TX509Ext.PKCS12ReadFromBytes(LPfxBytes, LSenha, LKey, LCert, LCa) then
    raise Exception.Create('PFX read failed');
  try
    // 2. Obter bytes do XML NFe a assinar
    LXmlBytes := TFile.ReadAllBytes('NFe.xml');

    // 3. Assinar CAdES-BES detached
    LSigner := TPkcs7Signer.Create;
    try
      LRes := LSigner.AssinarBytes(LXmlBytes, LCert, LKey, psDetached);
      if not LRes.OK then
        raise Exception.Create('Sign failed: ' + LRes.ErrorMsg);
      WriteLn('Signed bytes: ', LRes.SizeBytes);
      // LRes.SignedBytes pode ser anexado como CAdES detached signature
      TFile.WriteAllBytes('NFe.p7s', LRes.SignedBytes);
    finally
      LSigner.Free;
    end;
  finally
    if Assigned(LCert) then X509Free(LCert);
    if Assigned(LKey) then EvpPkeyFree(LKey);
  end;
end;
```

### Modos de assinatura (`TPkcs7Mode`)

| Modo | Saída | Uso típico |
|---|---|---|
| `psBinarioCMS` | DER attached (conteúdo embedded) | Geração de envelope SignedData |
| `psDetached` | DER detached (apenas assinatura) | **NFe** — assinatura separada |
| `psAttached` | DER attached (conteúdo embedded) | Equivalente a `psBinarioCMS` |
| `psBase64` | Base64 do DER detached | Wrap em XML/SOAP envelope |

## Time-stamping RFC 3161

```pascal
uses ssl_openssl_icpbrasil_tsp;

var
  LTsp: TTspClient;
  LHash: TBytes;
  LRes: TTimestampResult;
begin
  // 1. Hash SHA-256 do que vai timestampar (PKCS#7 signature, p.ex.)
  LHash := SHA256OfBytes(LSignedBytes);   // helper externo

  // 2. Pedir timestamp à TSA
  LTsp := TTspClient.Create;
  try
    LTsp.TimeoutMs := 10000;
    LRes := LTsp.RequestTimestamp(LHash, 'http://timestamp.serpro.gov.br/');

    if LRes.OK then
    begin
      // LRes.TimestampToken = DER bytes (TimeStampResp inteiro)
      // Pode ser anexado à PKCS#7 SignerInfo como unsigned attribute
      // (id-aa-signatureTimeStampToken: 1.2.840.113549.1.9.16.2.14)
      TFile.WriteAllBytes('timestamp.tsr', LRes.TimestampToken);
    end
    else
      WriteLn('TSP error: ', LRes.ErrorMsg);
  finally
    LTsp.Free;
  end;
end;
```

### TSAs públicos brasileiros conhecidos

| TSA | URL | Notas |
|---|---|---|
| Serpro Timestamp | `http://timestamp.serpro.gov.br/` | Gratuito, ICP-Brasil |
| Certisign Timestamp | `http://timestamp.certisign.com.br/` | Gratuito |
| FreeTSA | `https://freetsa.org/tsr` | Gratuito, internacional |
| DigiCert | `http://timestamp.digicert.com` | Gratuito, internacional |

> URLs e disponibilidade podem mudar — consultar provedor para SLA.

## Componendo CAdES-T (assinatura + timestamp)

```pascal
// 1. Sign CAdES-BES
LBesRes := LSigner.AssinarBytes(LXmlBytes, LCert, LKey, psDetached);

// 2. Hash do PKCS#7 SignerInfo (não do conteúdo)
LSignatureHash := SHA256OfBytes(LBesRes.SignedBytes);

// 3. Timestamp do hash
LTspRes := LTsp.RequestTimestamp(LSignatureHash, ATsaUrl);

// 4. Anexar TimestampToken como unsigned attribute do SignerInfo
// (manipulação DER manual; helper dedicado é roadmap)
LCadestRes := AppendTimestampToPkcs7(LBesRes.SignedBytes, LTspRes.TimestampToken);
```

> **Nota:** o helper `AppendTimestampToPkcs7` ainda não está em V41.9 —
> caller é responsável por compor a estrutura. Roadmap: helper
> `AssinarComTimestamp(AXml, ACert, AKey, ATsaUrl): TBytes` em V42.x.

## Verificação de assinatura

```pascal
var
  LStore: SslPtr;
  LVerifier: TX509ChainVerifier;
  LSigned, LOriginal: TBytes;
  LValid: Boolean;
begin
  // Trust store com AC-Raiz ICP-Brasil
  LVerifier := TX509ChainVerifier.Create;
  try
    LVerifier.LoadStoreFromPEM('bundles/ac-raiz-icp-brasil.pem');
    LSigned := TFile.ReadAllBytes('NFe.p7s');
    LOriginal := TFile.ReadAllBytes('NFe.xml');

    LValid := LSigner.VerificarAssinatura(LSigned, LVerifier.Store,
                                          LOriginal, ADetached := True);
    if LValid then
      WriteLn('Assinatura valida.')
    else
      WriteLn('Erro: ', LSigner.LastError);
  finally
    LVerifier.Free;
  end;
end;
```

## Estrutura ASN.1 (referência)

### PKCS#7 SignedData

```text
SignedData ::= SEQUENCE {
   version            INTEGER,
   digestAlgorithms   SET OF AlgorithmIdentifier,
   contentInfo        ContentInfo,
   certificates       [0] IMPLICIT CertificateSet OPTIONAL,
   crls               [1] IMPLICIT CertificateRevocationLists OPTIONAL,
   signerInfos        SET OF SignerInfo
}

SignerInfo ::= SEQUENCE {
   version            INTEGER,
   sid                SignerIdentifier,
   digestAlgorithm    AlgorithmIdentifier,
   signedAttrs        [0] IMPLICIT SignedAttributes OPTIONAL,
   signatureAlgorithm AlgorithmIdentifier,
   signature          OCTET STRING,
   unsignedAttrs      [1] IMPLICIT UnsignedAttributes OPTIONAL
}
```

### TimeStampToken (RFC 3161)

```text
TimeStampResp ::= SEQUENCE {
   status             PKIStatusInfo,
   timeStampToken     TimeStampToken OPTIONAL
}

TimeStampToken ::= ContentInfo
   contentType       id-signedData (1.2.840.113549.1.7.2)
   content           SignedData with TSTInfo as eContent
```

## Limitações V41.9

- **Helper para CAdES-T composto** — ainda não existe; caller compõe
  manualmente PKCS#7 + timestamp via DER manipulation. Roadmap V42.x.
- **CAdES-X / CAdES-A** (longa duração) — fora do escopo. Caller pode
  compor manualmente.
- **PAdES** (PDF Advanced Signatures) — fora do escopo (PDF Sign-Tools
  são proprietárias geralmente).
- **XmlDSig wrapping** — V41.9 produz CAdES-BES PKCS#7 cru. Para wrappar
  em `<Signature>` XmlDSig (formato NFe XML), consumidor usa biblioteca
  XmlDSig externa ou compõe manualmente.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `Sign failed: PKCS7_sign falhou` | OpenSSL 3 sem PKCS#7 module | Confirmar libcrypto-3 build inclui PKCS#7 (raro estar excluído) |
| Assinatura inválida na SEFAZ | Conteúdo modificado após assinar | Detached: garantir bytes do XML idênticos byte-a-byte |
| TSP retorna HTTP 415 | Header `Content-Type` errado | `httpsend.MimeType` deve ser `application/timestamp-query` |
| TSP retorna PKI status `rejection` | Rate limit / IP bloqueado | Retry após delay ou trocar TSA |
| `VerificarAssinatura` retorna False | Trust store sem AC-Raiz que assinou | Carregar bundle ITI + intermediárias |

## Referências

- [RFC 5652 — Cryptographic Message Syntax (CMS)](https://datatracker.ietf.org/doc/html/rfc5652)
- [RFC 3161 — Time-Stamp Protocol](https://datatracker.ietf.org/doc/html/rfc3161)
- [ETSI EN 319 122 — CAdES](https://www.etsi.org/deliver/etsi_en/319100_319199/31912201/01.01.01_60/en_31912201v010101p.pdf)
- [ICP-Brasil DOC-ICP-15.03 — Política de Carimbo do Tempo](https://www.gov.br/iti/pt-br)
