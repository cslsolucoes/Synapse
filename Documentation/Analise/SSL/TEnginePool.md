# TEnginePool / ssl_openssl_capi.pas

**Unit:** `ssl_openssl_capi.pas` (linha ~579) | **Versao:** 001.003.000 | **Tipo:** Classe auxiliar (private) | **Origem:** Upstream Synapse (Pepak, 2018)

---

## 1. O que e?

`TEnginePool` e uma classe auxiliar interna de `ssl_openssl_capi.pas` que mantem um pool de engines OpenSSL CAPI reutilizaveis entre sessoes TLS. Resolve um problema de performance: `ENGINE_by_id('capi')` + `ENGINE_init` + `ENGINE_load_private_key` sao operacoes caras (lookups no Certificate Store, inicializacao de CSP), ha que evita-las em cada handshake e TLS novo.

Activa sob `{$DEFINE USE_ENGINE_POOL}` (default em `ssl_openssl_capi.pas`). Uma unica instancia global `FEnginePool: TEnginePool` e criada na `initialization` da unit. Cada `TSSLOpenSSLCapi.GetEngine` faz `FEnginePool.Acquire` no inicio da conexao e `FEnginePool.Release` no destroy — reutilizando engines ociosos em vez de recria-los.

A sincronizacao usa `TCriticalSection` (SyncObjs) para thread-safety. Engines libertados no `Destroy` da pool fazem `ENGINE_finish` + `ENGINE_free`.

---

## 2. Caracteristicas

- **Pool thread-safe:** `TCriticalSection` protege `fAvailableList` (`TList` de `PENGINE`).
- **Lazy init:** primeiro `Acquire` invoca `InitCapiEngine` + `PrepareCapiEngine` se a pool estiver vazia.
- **Singleton global:** `FEnginePool` criada em `initialization`, destruida em `finalization` da unit.
- **LIFO:** `Acquire` faz `fAvailableList.Delete(Count-1)` — ultimo libertado e o primeiro reutilizado (cache-warm).
- **Cleanup limpo:** `Clear` itera todos os engines e chama `ENGINE_finish` + `ENGINE_free` antes de esvaziar a lista.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$DEFINE USE_ENGINE_POOL}` | Liga compilacao de `TEnginePool` e uso em `TSSLOpenSSLCapi` |
| `SyncObjs` (RTL) | `TCriticalSection` para lock |
| `Classes` (RTL) | `TList` para armazenar pointers |
| `ssl_openssl_lib` | `ENGINE_finish`, `ENGINE_free` (funcoes OpenSSL) |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create` | Cria `TCriticalSection` e `TList` vazios |
| `Destroy` | `destructor Destroy; override` | Invoca `Clear`, liberta lock e lista |

### 4.2 Operacoes de pool

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Acquire` | `function Acquire(out Engine: PENGINE): boolean` | Tenta reutilizar engine ocioso; se pool vazia invoca `InitCapiEngine`+`PrepareCapiEngine`. Retorna True se obteve engine |
| `Release` | `procedure Release(var Engine: PENGINE)` | Devolve engine a pool (nao faz `ENGINE_finish`) e zera ponteiro passado por referencia |
| `Clear` | `procedure Clear` | Liberta todos os engines pendentes (`ENGINE_finish`+`ENGINE_free`) e limpa a lista |

### 4.3 Lock interno

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Lock` | `procedure Lock` | `fLock.Enter` (entra na critical section) |
| `Unlock` | `procedure Unlock` | `fLock.Leave` |

### 4.4 Variavel global

| Identificador | Tipo | Descricao |
| --- | --- | --- |
| `FEnginePool` | `TEnginePool` | Singleton global; inicializada em `initialization` da unit; liberta em `finalization` |

---

## 5. Aplicabilidades

1. **Reducao de latencia em servidores HTTPS com mTLS:** cada handshake cliente reutiliza engine em vez de re-carregar CAPI.
2. **Workers multi-thread:** conexoes paralelas nao competem por inicializacao do engine — cada thread faz `Acquire` do seu engine livre.
3. **Long-running clients:** aplicacoes que fazem muitas conexoes HTTPS/LDAPS em sequencia (batch, polling) amortizam o custo de init entre chamadas.
4. **Diagnostico:** `Clear` em resposta a mudanca de politica de cert forca reset completo dos engines.

---

## 6. Exemplos de uso

### 6.1 Uso transparente (pool gerida pelo TSSLOpenSSLCapi)

```pascal
uses
  httpsend, ssl_openssl_capi;

var
  i: Integer;
begin
  // 100 conexoes sequenciais aproveitam o mesmo pool
  for i := 1 to 100 do
  begin
    with THTTPSend.Create do
    try
      Sock.SSL := TSSLOpenSSLCapi.Create(Sock);
      (Sock.SSL as TSSLOpenSSLCapi).SigningCertificateID := 'Joao Silva';
      HTTPMethod('GET', 'https://api.empresa.local/v1/ping');
      // Destroy devolve engine a pool automaticamente
    finally
      Free;
    end;
  end;
end;
```

### 6.2 Forcar reset da pool apos renovacao de cert

```pascal
uses
  ssl_openssl_capi;

begin
  // Apos renovacao do cert no Store, engines antigos ficam stale
  FEnginePool.Clear;
  // Proxima conexao inicializa novo engine com cert fresco
end;
```

### 6.3 Disable pool (rebuild com USE_ENGINE_POOL off)

```pascal
{$UNDEF USE_ENGINE_POOL}

uses
  ssl_openssl_capi;

// Sem pool: cada conexao faz ENGINE_init + ENGINE_finish
// Trade-off: menos memoria retida, mais CPU por handshake
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Consumida por | `TSSLOpenSSLCapi.GetEngine` | Lazy-load do engine corrente |
| Consumida por | `TSSLOpenSSLCapi.Destroy` | `FEnginePool.Release(FEngine)` devolve engine ao pool |
| Depende de | `TCriticalSection` (SyncObjs) | Lock thread-safe |
| Depende de | `TList` (Classes) | Storage dos pointers |
| Depende de | `ENGINE_finish`, `ENGINE_free` (ssl_openssl_lib) | Destrutor de engines |
| Visibilidade | Private da unit | Nao e exposta na interface publica; acedida via variavel global `FEnginePool` |
| Condicional | `{$DEFINE USE_ENGINE_POOL}` | Se indefinido, `TSSLOpenSSLCapi` chama directo `ENGINE_finish`+`ENGINE_free` em cada `Destroy` |
