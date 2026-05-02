# Security Considerations — Synapse v41.5 fork extensions

> **V41.5 (S8) — actualizacao:** record agora expoe `ThumbPrintSHA1`,
> `ThumbPrintSHA256`, `NumeroSerie` e `DERBase64`. Esses campos **podem**
> aparecer em logs/auditoria de forma segura — nao revelam identidade do
> titular nem chave privada. Vide secao "Identificacao segura de cert" abaixo.

## Manuseio de PFX em produtos consumidores

PFX contem **chave privada** + identificadores fiscais (CNPJ/CPF) +
nomes pessoais. Tratamento equivalente a credenciais de producao.

### NAO faca

- **NAO** logar bytes do PFX (mesmo cifrados em memoria).
- **NAO** logar senha do PFX (mesmo em log de debug local).
- **NAO** logar nome de arquivo PFX inteiro (use hash SHA256-8).
- **NAO** logar CNPJ/CPF completo (redacao obrigatoria).
- **NAO** persistir senha do PFX em plain text no banco
  (LGPD + OWASP A04 - Insecure Design).
- **NAO** commitar PFX no git nem em build artifacts.
- **NAO** subir PFX para Postman cloud, Sentry, ferramentas de
  observabilidade externas. Verificar que `HandleException` middleware
  nao ecoa bytes do PFX em response 500.
- **NAO** rodar testes contra PFX reais em CI cloud / containers efemeros
  com risco de filesystem snapshot leak.
- **NAO** logar `DERBase64` se a auditoria for compartilhada (e o cert
  publico inteiro — nao secreto, mas permite verificacao terceirizada de
  posse). Logar apenas `ThumbPrintSHA256` para identificar instancia.

### Faca

- **Acesso somente-leitura** ao arquivo PFX no codigo de teste/upload.
- **Wipe da memoria** apos uso:

  ```pascal
  if Length(LPfxBytes) > 0 then
    FillChar(LPfxBytes[0], Length(LPfxBytes), 0);
  SetLength(LPfxBytes, 0);
  ```

- **Redacao em logs**:
  - CNPJ: `12.345.678/0001-XXXX`
  - CPF: `***.456.789-**`
  - Nome titular: 3 letras + `***`
- **Cifragem at-rest** se persistir senha (AES-256 + HMAC).
- **Rotacao**: chave privada exposta = certificado comprometido. Cliente
  precisa **emitir novo cert** ICP-Brasil (custo R$ 200-500 por certificado).

## Identificacao segura de certificado em logs (V41.5)

Use os novos campos do record para identificar instancias de cert sem
expor PII:

| Campo | Pode logar? | Comentario |
| --- | --- | --- |
| `Subject` | NAO | Contem `TITULAR:DOCUMENTO` legivel |
| `SubjectTitular` | NAO | Nome pessoal/empresarial |
| `SubjectDocumento` | Apenas redatado | CNPJ/CPF — redacao obrigatoria |
| `Issuer` / `Certificadora` | SIM | Nome da AC e publico |
| `NumeroSerie` / `NumeroSerieHex` | SIM | ID interno do cert no AC; identifica instancia mas nao titular |
| `ThumbPrintSHA1` / `ThumbPrintSHA256` | SIM | **Hash do cert publico** — preferir SHA-256 (SHA-1 obsoleto criptograficamente, util como compat) |
| `DERBase64` | Cuidado | Cert publico inteiro — nao revela chave privada mas expoe metadados (incluindo nome, email, etc.) |
| `NotBefore` / `NotAfter` | SIM | Datas publicas |
| `ResponsavelCpf` | NAO | PII — redacao obrigatoria |
| `Email` | NAO | PII |
| `TituloEleitor` / `PisOuCaepf` / `RgSeparado` | NAO | PII fiscal |

### Padrao recomendado

```pascal
function CertSignatureForLog(const ACert: TIcpBrasilCertificado): string;
begin
  // Identifica unicamente o cert sem expor PII
  Result := Format('cert sha256=%s | issuer=%s | valid=%s..%s | days=%d',
    [Copy(ACert.ThumbPrintSHA256, 1, 16),  // primeiros 8 bytes
     ACert.Certificadora,
     FormatDateTime('yyyy-mm-dd', ACert.NotBefore),
     FormatDateTime('yyyy-mm-dd', ACert.NotAfter),
     ACert.DiasParaExpirar]);
end;
```

## Validacao fiscal sem expor PII

```pascal
// Checa se cert e valido para assinar NFe sem logar CNPJ
if not LCert.EstaValido then
  Logger.Warn('cert thumbprint=%s expirado em %s',
              [Copy(LCert.ThumbPrintSHA256, 1, 16),
               FormatDateTime('yyyy-mm-dd', LCert.NotAfter)]);
if not MatchCnpjRaiz(LCert.SubjectDocumento, ANFeEmitCnpj) then
  Logger.Warn('cert thumbprint=%s nao corresponde ao emitente da NFe',
              [Copy(LCert.ThumbPrintSHA256, 1, 16)]);
```

## SHA-1 thumbprint — quando usar

`ThumbPrintSHA1` e exposto para compatibilidade com:

- Windows Certificate Store (SHA-1 historico)
- Sistemas legacy SEFAZ que ainda enumeram certs por SHA-1
- Auditoria reversa contra logs antigos

**Nao usar SHA-1 para finalidade criptografica** (resistencia a colisao quebrada
desde 2017 — SHAttered/Shambles). Para identificacao unica em sistemas novos,
preferir `ThumbPrintSHA256`.

## Vetores de teste (`tests-extra/fixtures/`)

**100% sinteticos**. CNPJs e CPFs gerados com `mod-11` valido mas sem
corresponder a entidades reais. Code review obrigatorio em PRs vs `tests/`
para garantir.

`grep -rE "<CPF_REAL>|<CNPJ_REAL>" tests-extra/fixtures/` deve retornar 0.

## Em caso de incidente (vazamento)

1. **Remover blob do git** (`git filter-repo --path <arquivo> --invert-paths`).
2. **Force-push** apos confirmacao de owner.
3. **Comunicar titulares** afetados (LGPD: direito de informacao).
4. **Rotacionar certificados** comprometidos (emissao nova ICP-Brasil).
5. **Registrar incidente** em log auditavel — usar `ThumbPrintSHA256` do
   cert comprometido como ID na auditoria (nao expoe PII).

## Memory ownership

Apos `TX509Ext.PKCS12ReadFromBytes`, consumidor **deve** liberar:

```pascal
if Assigned(LCert) then X509Free(LCert);     // ssl_openssl3_lib
if Assigned(LPKey) then EvpPkeyFree(LPKey);  // ssl_openssl3_lib
```

`LCaChain` (terceiro out-param) e gerenciado automaticamente por
`PKCS12_parse` no caminho de sucesso e pode ser nil no caminho de erro.

## Validacoes pendentes (S9-S10)

V41.5 **nao valida**:

- Cadeia ate AC-Raiz ICP-Brasil (S9 planeado).
- Revogacao via CRL ou OCSP (S10 planeado).
- PolicyIdentifier (`2.5.29.32`) contra OIDs canonicos do ITI (`2.16.76.1.2.*`).

Consumidores que precisam destas validacoes para compliance fiscal devem,
ate S9-S10 estarem disponiveis:

1. Confiar na validacao TLS do SO (Windows CryptoAPI ou OpenSSL stack
   verify) na hora do handshake com SEFAZ.
2. Implementar verificacao programatica externa (e.g. via `openssl verify`
   CLI ou stack OpenSSL completa).
3. **Nao usar V41.5 standalone para emitir documento fiscal** sem
   validacao secundaria de revogacao.

## Roadmap de seguranca

| Sprint | Conteudo |
| --- | --- |
| **S9 (V41.6)** | Bindings `X509_STORE_CTX_*` + `X509_verify_cert`; bundle AC-Raiz ITI v1-v10 embarcado; parser `Certificate Policies`. |
| **S10 (V41.7)** | Bindings CRL + OCSP; cliente AIA + CDP fetch; cache de revogacao. |
| **S11 (V41.8)** | Parser SAN completo + Key Usage + Extended Key Usage + OAB digital. |
| **S12 (V41.9)** | Assinatura PKCS#7/CAdES + Time-stamping RFC 3161 (assinar XML NFe nativamente). |
| **S13 (V42.0)** | PKCS#11 cross-platform + Windows Store + A3 detection. |
