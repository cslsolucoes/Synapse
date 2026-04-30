# Security Considerations — Synapse v41.4 fork extensions

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
5. **Registrar incidente** em log auditavel.

## Memory ownership

Apos `TX509Ext.PKCS12ReadFromBytes`, consumidor **deve** liberar:

```pascal
if Assigned(LCert) then X509Free(LCert);     // ssl_openssl3_lib
if Assigned(LPKey) then EvpPkeyFree(LPKey);  // ssl_openssl3_lib
```

`LCaChain` (terceiro out-param) e gerenciado automaticamente por
`PKCS12_parse` no caminho de sucesso e pode ser nil no caminho de erro.
