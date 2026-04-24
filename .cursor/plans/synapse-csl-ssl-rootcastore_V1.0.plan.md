---
name: synapse-csl-ssl-rootcastore
version: 1.0.0
date: 2026-04-22
author: CSL Softwares
status: draft
scope: >
  Onda 1 — Trust store TLS centralizado (TSslRootCAStore) em blcksock.pas.
  Inspirado em ICS OverByte `TSslRootCAStore` (design pattern apenas —
  codigo e 100% BSD 3-Clause escrito de raiz). Reuso de CAs entre
  ldapsend, httpsend, smtpsend, imapsend sem duplicar CertCAFile em cada
  consumidor.
depends-on:
  - Synapse CSL fork 001.007.004 / V41.2
  - Master plan: synapse-csl-ics-modernization-master_V1.0.plan.md
target-file: Packege/synapse/blcksock.pas
target-version: 009.011.001 → 009.012.000
target-package-version: V41.2 → V41.3
protected-area: Packege/synapse/ — requer aprovacao antes de execucao
impact-on-adorm: NULO — ADORM usa `CAFile` string directo; TSslRootCAStore e opt-in via nova property
target-compilers:
  - Delphi 12.x (Win32 / Win64)
  - FPC 3.3.1+ (i386-win32 / x86_64-win64)
out-of-scope:
  - Revogacao CRL / OCSP (agendar V41.3.1 se necessario)
  - Pinning SPKI (TOFU) — agendar futuro
  - Certstore Windows nativo (ja coberto por ssl_openssl_capi.pas)
  - Auto-update automatico de CA bundles (trabalho de sysadmin)
licensing: >
  Reimplementacao conceitual do padrao ICS. Zero linhas de codigo ICS copiadas.
  Apenas RFC 5280 (X.509 PKI) e OpenSSL X509_STORE API (publica) sao referencias.
---

# V41.3 — TSslRootCAStore (Onda 1 de 4)

> **Status:** draft — area protegida `Packege/synapse/` requer aprovacao.
> Ler plano mestre primeiro: [synapse-csl-ics-modernization-master_V1.0.plan.md](synapse-csl-ics-modernization-master_V1.0.plan.md).

---

## 1. Contexto

Actualmente, cada unidade Synapse que usa TLS tem que apontar o CAFile
manualmente:

```pascal
LLDAP := TLDAPSend.Create;
LLDAP.Sock.SSL.CertCAFile := 'E:\certs\corporate_ca.pem';  // duplicado

LHTTP := THTTPSend.Create;
LHTTP.Sock.SSL.CertCAFile := 'E:\certs\corporate_ca.pem';  // duplicado

LSMTP := TSMTPSend.Create;
LSMTP.Sock.SSL.CertCAFile := 'E:\certs\corporate_ca.pem';  // duplicado
```

Problemas:

1. **Duplicacao** — mesma CA bundle referida em N pontos.
2. **Pooling impossivel** — cada `SSLImplementation` re-parse o PEM em cada `Create`.
3. **Actualizacao por app** — mudanca de CA exige refactor em todos os consumidores.
4. **Zero introspeccao** — nao se sabe quantas CAs foram carregadas, nem se o bundle parseou OK.

ICS resolve isto com `TSslRootCAStore` singleton que carrega o bundle uma vez
e todas as classes SSL consultam. A V41.3 traz esse padrao para o Synapse CSL.

---

## 2. Objectivo

Introduzir em `blcksock.pas` um **trust store singleton opt-in** que:

1. Carrega um bundle PEM uma vez (com cache).
2. Expoe `TGlobalRootCAStore.Instance` consultavel por `TCustomSSL`.
3. Permite `Sock.SSL.UseGlobalRootCAStore := True;` em vez de `CertCAFile := '...';`.
4. **Mantem API actual** — `CertCAFile` continua a funcionar.
5. Suporta **multiplos bundles** (corporate + Mozilla) por prioridade.
6. Cache thread-safe com `TCriticalSection`.

---

## 3. API nova (interface)

### 3.1 Classe `TSslRootCAStore`

```pascal
type
  {:@abstract(V41.3 — Trust store TLS centralizado.
     Carrega bundles PEM e disponibiliza-os globalmente para consumo por
     qualquer TCustomSSL via property UseGlobalRootCAStore. Inspirado em
     padrao ICS (codigo proprio BSD — zero copia).)}
  TSslRootCAStore = class
  private
    FBundles: TStringList;                // caminhos PEM por ordem de prioridade
    FParsedBundle: AnsiString;            // PEM concatenado apos parse bem-sucedido
    FLastError: string;
    FLoadedCertCount: Integer;
    FLoadTimestamp: TDateTime;
    FLock: TRTLCriticalSection;
    procedure Reload;
  public
    constructor Create;
    destructor Destroy; override;

    {: Adiciona bundle PEM a lista. Prioridade = ordem de insercao. }
    procedure AddBundle(const APath: string);

    {: Remove bundle. }
    procedure RemoveBundle(const APath: string);

    {: Forca reload; chamado automaticamente quando AddBundle/RemoveBundle. }
    procedure Refresh;

    {: Retorna o PEM concatenado apos parse. Vazio se Load falhou. }
    function GetParsedPEM: AnsiString;

    {: Numero de certificados X.509 carregados com sucesso. }
    property LoadedCertCount: Integer read FLoadedCertCount;

    {: Ultimo erro de parse (vazio se OK). }
    property LastError: string read FLastError;

    {: Timestamp do ultimo load bem-sucedido. }
    property LoadTimestamp: TDateTime read FLoadTimestamp;
  end;
```

### 3.2 Singleton

```pascal
{: Instancia global — criada on-demand, liberada em finalization. }
function GlobalRootCAStore: TSslRootCAStore;
```

### 3.3 Extensao em `TCustomSSL`

```pascal
TCustomSSL = class(...)
  // ... membros existentes ...
private
  FUseGlobalRootCAStore: Boolean;        // V41.3 — novo
published
  {: V41.3 — Se True, TLS usa GlobalRootCAStore em vez de CertCAFile.
     CertCAFile tem prioridade se ambos definidos (backward compat). }
  property UseGlobalRootCAStore: Boolean read FUseGlobalRootCAStore write FUseGlobalRootCAStore;
end;
```

### 3.4 Uso em `ssl_openssl*.pas`

Cada plugin SSL (`TSSLOpenSSL`, `TSSLOpenSSL3`, `TSSLOpenSSL4`) checa no `Connect`:

```pascal
if FUseGlobalRootCAStore and (FCertCAFile = '') then
begin
  LPEM := GlobalRootCAStore.GetParsedPEM;
  if LPEM <> '' then
    // carregar LPEM no SSL_CTX via SSL_CTX_load_verify_mem (OpenSSL 1.1+)
    // ou escrever em tmpfile e SSL_CTX_load_verify_locations
end;
```

---

## 4. API de conveniencia

### 4.1 Funcao global de setup

```pascal
{: V41.3 — Atalho para configurar o store na inicializacao da app.
   Equivalente a 'GlobalRootCAStore.AddBundle(APath);' + 'Refresh'. }
procedure SetupGlobalRootCA(const APath: string);
```

### 4.2 Uso tipico do consumidor

```pascal
uses blcksock;

initialization
  SetupGlobalRootCA('certs/corporate.pem');
  SetupGlobalRootCA('certs/mozilla.pem');

procedure DoSomething;
var
  LHTTP: THTTPSend;
begin
  LHTTP := THTTPSend.Create;
  try
    LHTTP.Sock.SSL.UseGlobalRootCAStore := True;   // <<< uma linha
    LHTTP.HTTPMethod('GET', 'https://api.empresa.local/data');
  finally
    LHTTP.Free;
  end;
end;
```

---

## 5. Alteracoes em `blcksock.pas`

| Bloco | Conteudo | LoC |
|---|---|---:|
| Interface — `TSslRootCAStore` declarada | Classe completa + property na `TCustomSSL` | ~80 |
| Interface — `GlobalRootCAStore` + `SetupGlobalRootCA` | Forward declarations | ~10 |
| Implementation — `TSslRootCAStore.Create/Destroy/Reload` | Parse concatenado dos bundles | ~150 |
| Implementation — singleton + finalization cleanup | `FGlobalStore: TSslRootCAStore` + `TCriticalSection` | ~30 |
| Implementation — hooks em `ssl_openssl3`/`ssl_openssl4` | Leitura do store no `Connect` | ~60 em cada plugin |
| Header — bloco CSL V41.3 + bump 009.011.001 → 009.012.000 | Documentacao do patch | ~20 |

**Total:** ~400 LoC novo, ~80 modificado.

---

## 6. Backup obrigatorio

Antes de editar:

```powershell
$backDir = 'Packege\synapse\bak'
$ts = (Get-Date).ToString('yyyyMMdd_HHmm')
Copy-Item 'Packege\synapse\blcksock.pas'      -Destination "$backDir\blcksock.$ts.bak"
Copy-Item 'Packege\synapse\ssl_openssl.pas'   -Destination "$backDir\ssl_openssl.$ts.bak"
Copy-Item 'Packege\synapse\ssl_openssl3.pas'  -Destination "$backDir\ssl_openssl3.$ts.bak"
Copy-Item 'Packege\synapse\ssl_openssl4.pas'  -Destination "$backDir\ssl_openssl4.$ts.bak"
```

Se houver colisao de minuto, acrescentar sufixo `_a`/`_b`.

---

## 7. Compatibilidade

| Caso | Comportamento |
|---|---|
| `Sock.SSL.CertCAFile := 'X.pem';` (codigo actual) | Igual a antes — funciona sem tocar no store. |
| `Sock.SSL.UseGlobalRootCAStore := False;` (default) | Igual a antes — store ignorado. |
| `UseGlobalRootCAStore := True;` + `CertCAFile = ''` | Usa store global. |
| `UseGlobalRootCAStore := True;` + `CertCAFile = 'Y.pem';` | **CertCAFile tem prioridade** (compat). |
| `UseGlobalRootCAStore := True;` + store vazio | Usa `SSL_CTX_set_default_verify_paths` (OpenSSL padrao). |

ADORM actual (`ActiveDirectory.Service.pas`) continua a usar `FConfig.CAFile`
directamente — zero alteracao necessaria.

---

## 8. Documentacao a actualizar

- `Packege/synapse/VERSION.md` — bump V41.2 → V41.3 + seccao changelog V41.3.
- `Packege/synapse/Synapse.Version.inc` — +`SYNAPSE_V41_3_OR_HIGHER` + `SYNAPSE_SSL_ROOT_CA_STORE`.
- `Packege/synapse/README.md` — seccao "Fork sessao <data> (V1.7.3)".
- `Packege/synapse/Documentation/README.md` — hub.
- `Packege/synapse/Documentation/TCPBlockSocket.md` — mencionar trust store.
- **NOVO** `Packege/synapse/Documentation/Analise/Core/TSslRootCAStore.md` — analise completa (7 seccoes padrao).
- `Packege/synapse/Documentation/Analise/Core/TCustomSSL.md` — property `UseGlobalRootCAStore` nova.
- `Packege/synapse/Documentation/Analise/README.md` — indice.

---

## 9. Verificacao

### 9.1 Compilacao

```powershell
dcc32 ActiveDirectoryORM.dpr
dcc64 ActiveDirectoryORM.dpr
```

Gate: 2/2 Delphi verde, zero warnings novos.

### 9.2 Smoke test

Criar `tests/SslRootCAStore.Smoke.dpr`:

1. `SetupGlobalRootCA('Windows\System32\curl-ca-bundle.crt')` ou equivalente disponivel no sistema CI.
2. `LHTTP.Sock.SSL.UseGlobalRootCAStore := True;`
3. `LHTTP.HTTPMethod('GET', 'https://badssl.com/');` — deve succeder.
4. `LHTTP.HTTPMethod('GET', 'https://expired.badssl.com/');` — deve falhar (expirado).
5. `LHTTP.HTTPMethod('GET', 'https://self-signed.badssl.com/');` — deve falhar (nao confiavel).
6. Imprimir `SMOKE_OK` no final.

### 9.3 Teste de compat retroactivo

`tests/SslBackCompat.Smoke.dpr`:

1. Codigo velho `LLDAP.Sock.SSL.CertCAFile := 'corporate.pem';` sem tocar no store.
2. Bind bem-sucedido → `SMOKE_OK`.

---

## 10. Criterios de aceitacao

- [ ] Backup `Packege/synapse/bak/blcksock.<YYYYMMDD_HHMM>.bak` + ssl_openssl*.bak criados.
- [ ] `blcksock.pas` bump 009.011.001 → 009.012.000 com bloco CSL V41.3 documentado.
- [ ] `TSslRootCAStore` publica completa com parse de bundles + singleton thread-safe.
- [ ] `TCustomSSL.UseGlobalRootCAStore` nova + integracao em ssl_openssl3/4.
- [ ] `SetupGlobalRootCA` helper funcional.
- [ ] `CertCAFile` mantem prioridade sobre store (compat).
- [ ] Matriz Delphi Win32+Win64 verde.
- [ ] Smoke `SslRootCAStore.Smoke.dpr` imprime `SMOKE_OK`.
- [ ] Backcompat smoke passa.
- [ ] Zero codigo ICS copiado — auditoria textual `grep -i 'ICS' Packege/synapse/blcksock.pas` so devolve linha de header "Inspired by ICS — no code copied".
- [ ] `VERSION.md` + `Synapse.Version.inc` + README actualizados.
- [ ] `Documentation/Analise/Core/TSslRootCAStore.md` criado (7 secoes).

---

## 11. Roadmap pos-V41.3

- **V41.3.1** — OCSP stapling check no store (RFC 6066).
- **V41.3.2** — CRL revogacao periodica.
- **V41.3.3** — SPKI pinning (TOFU) opcional.

---

**Changelog (este arquivo):**

- 1.0.0 (22/04/2026): Criacao. Onda 1 de 4 ICS-inspired modernization. Status draft — requer aprovacao.
