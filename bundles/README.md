# bundles/ — Trust anchors para validacao offline

Esta pasta contem **trust anchors** (certificados raiz auto-assinados) usados
pelo `TX509ChainVerifier` (`ssl_openssl_chain_verify.pas`) para validar
cadeias offline, sem depender do TLS handshake.

## Conteudo

| Ficheiro | Conteudo | Origem |
| --- | --- | --- |
| [`AC-Raiz-ICP-Brasil-fetch.ps1`](AC-Raiz-ICP-Brasil-fetch.ps1) | Script PowerShell para baixar AC-Raiz v1..v10 do ITI | CSL fork v41.6 (S9) |
| `ac-raiz-icp-brasil.pem` (gerado) | Bundle PEM concatenado de todas as AC-Raiz | Output do script — **nao commitado** |
| `ac-raiz-icp-brasil-v<NN>.pem` (gerado) | Cert individual por versao (auditoria) | Output do script |

> **Nota:** os ficheiros `.pem` **nao** sao commitados — sao gerados pelo
> script. Isso evita drift quando o ITI atualiza certificados.

## Uso

### Refresh do bundle (executar antes de validacao em producao)

```powershell
pwsh -File bundles/AC-Raiz-ICP-Brasil-fetch.ps1 -Verbose
```

Saida tipica:

```text
[V01] Downloading https://estrutura.iti.gov.br/repositorio/v1/ACRaiz_v1.crt
[V01] Subject: CN=Autoridade Certificadora Raiz Brasileira, O=ICP-Brasil, ...
[V01] Salvou bundles/ac-raiz-icp-brasil-v1.pem
...
[V10] ...

Bundle gerado: bundles/ac-raiz-icp-brasil.pem
ACs baixadas com sucesso: 10
```

### Consumir em codigo Pascal

```pascal
uses
  ssl_openssl_chain_verify;

var
  LVerifier: TX509ChainVerifier;
  LResult:   TVerifyResult;
  LCertCount: Integer;
begin
  LVerifier := TX509ChainVerifier.Create;
  try
    LCertCount := LVerifier.LoadStoreFromPEM('bundles/ac-raiz-icp-brasil.pem');
    if LCertCount <= 0 then
      raise Exception.Create('Bundle vazio ou nao encontrado.');
    WriteLn('ACs carregadas: ', LCertCount);

    // ACert = PX509 obtido de ssl_openssl_x509_ext.PKCS12ReadFromBytes
    LResult := LVerifier.Verify(ACert);
    if LResult.OK then
      WriteLn('Cadeia valida! Profundidade: ', LResult.ChainProfundidade)
    else
      WriteLn('Cadeia invalida. Erro [', LResult.ErrCode, ']: ', LResult.ErrText);
  finally
    LVerifier.Free;
  end;
end;
```

## Refresh policy

- **Mensal:** rodar via CI agendado (cron, GitHub Actions, etc.).
- **Ad-hoc:** quando o ITI publicar nova AC-Raiz (V11+) ou revogar uma
  existente — checar [https://estrutura.iti.gov.br](https://estrutura.iti.gov.br)
  ou [boletins ITI](https://www.gov.br/iti/pt-br/assuntos).
- **Pre-commit em producao:** algum consumidor pode preferir bundle pinned
  (commitado) — nesse caso, commitar `ac-raiz-icp-brasil.pem` e adicionar
  ao git, mas com auditoria periodica.

## URLs e seguranca

O script faz HTTPS para `estrutura.iti.gov.br`. Se o cert do site mudar e
o handshake falhar, o script aborta — investigar antes de "ignorar warning".

**Não** usar este bundle se nao foi baixado de fonte autoritativa (ITI).
Bundle adulterado = chain validation comprometida = aceitacao de cert
malicioso.

## Embedding em build (alternativa avancada)

Para aplicacoes que precisam funcionar offline desde o primeiro boot
(sem rodar o script), o bundle pode ser embarcado:

```pascal
{$R bundles/ac-raiz-icp-brasil.res}   // RC compila .pem como recurso

// ou load via {$INCLUDE} numa .inc file convertida:
const
  AC_RAIZ_BUNDLE: array of string = (
    {$I ac-raiz-icp-brasil-v1.inc}
    ...
  );
LVerifier.LoadStoreFromCertList(AC_RAIZ_BUNDLE);
```

Convencao: scripts de embedding ficam em `bundles/` mas as `.inc` ficam
em `bundles/embed/` (gerar via `convert-pem-to-inc.ps1` — futuro).

## Roadmap

- **S9 (atual):** suporte ao bundle PEM externo via `LoadStoreFromPEM`.
- **S10:** integracao automatica de chain + CRL (carregar CRL paralela ao
  cert raiz).
- **Futuro:** modo embedded com refresh assistido (verificar `nextUpdate`
  do bundle e avisar consumidor para rodar fetch).
