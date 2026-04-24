# TSSLNone / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe concreta (plugin SSL NOP) | **Origem:** Upstream Synapse

---

## 1. O que e?

`TSSLNone` e o plugin SSL default do Synapse: uma implementacao **no-op** que nao oferece criptografia real. Herda de `TCustomSSL` e e usado quando nenhum plugin SSL concreto (OpenSSL, CryptLib, etc.) foi importado no `uses` do projeto.

A classe serve para que o codigo compile e funcione em modo plaintext sem ter de adicionar condicionais `{$IFDEF USE_SSL}` em toda parte. Qualquer tentativa de chamar `Connect` / `Accept` em um `TSSLNone` retorna `False` imediatamente — o `TTCPBlockSocket.SSLDoConnect` pode ser chamado mas nao eleva o socket a TLS.

A variavel global `SSLImplementation: TSSLClass = TSSLNone;` e a configuracao default. Adicionar `uses ssl_openssl3` ao projeto muda essa variavel para `TSSLOpenSSL3` no `initialization` da unit, activando TLS real automaticamente.

---

## 2. Caracteristicas

* Plugin no-op (sem SSL real).
* Default `SSLImplementation` se nenhum outro plugin for importado.
* Herda todos os metodos virtuais de `TCustomSSL` com implementacao default (return `False` / string vazia).
* Permite compilacao limpa do projecto sem OpenSSL disponivel.
* Util para testes offline / development onde TLS nao e requerido.

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| [TCustomSSL](TCustomSSL.md) | Heranca directa |
| `SSLImplementation: TSSLClass = TSSLNone` (var global) | Registra-se como default |

---

## 4. Funcionalidades

### 4.1 Metodos sobrescritos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LibVersion` | `function LibVersion: String; override` | Retorna `''` (vazio) ou texto identificando plugin NOP |
| `LibName` | `function LibName: String; override` | Retorna `'ssl_none'` ou similar |

### 4.2 Metodos herdados (com default NOP)

Todos os metodos virtuais de `TCustomSSL` mantem o comportamento default da classe base:

| Metodo | Comportamento |
| --- | --- |
| `Connect` | Retorna `False` |
| `Accept` | Retorna `False` |
| `Shutdown` / `BiShutdown` | Retorna `True` (nada a fazer) |
| `SendBuffer` / `RecvBuffer` | Delegam ao socket plain (nao ha camada TLS) |
| `GetSSLVersion` / `GetPeerSubject` / etc. | Retornam `''` ou zero |
| `GetVerifyCert` | Retorna 0 (sem verificacao) |

---

## 5. Aplicabilidades

1. **Compilacao sem dependencia OpenSSL** — permite build onde libeay/ssleay ausentes.
2. **LDAP plaintext (porta 389 sem StartTLS)** — desenvolvimento local / testes.
3. **Fallback para plugins opcionais** — se consumidor quiser decidir em runtime.
4. **Testes unitarios** — evitar boot de OpenSSL em testes de integracao de protocolo.
5. **Fluxos onde TLS nao e requerido** — redes isoladas, canais internos ja cifrados por outra camada.

---

## 6. Exemplos de uso

### 6.1 LDAP sem TLS (apenas para testes locais)

```pascal
uses SysUtils, ldapsend;
// NAO importar ssl_openssl3/4 aqui -- SSLImplementation sera TSSLNone

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc-lab.local';
    LLDAP.TargetPort := '389';
    LLDAP.FullSSL    := False;
    LLDAP.AutoTLS    := False;

    if LLDAP.Login then
      Writeln('Plugin SSL ativo: ', LLDAP.Sock.SSL.LibName,
              ' (', LLDAP.Sock.SSL.ClassName, ')');
    // Esperado: plugin=TSSLNone
  finally
    LLDAP.Free;
  end;
end;
```

### 6.2 Checar se TLS real esta disponivel

```pascal
uses blcksock;

begin
  if SSLImplementation = TSSLNone then
    Writeln('Aviso: nenhum plugin SSL carregado; LDAPS nao funcionara')
  else
    Writeln('Plugin SSL activo: ', SSLImplementation.ClassName);
end.
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TCustomSSL](TCustomSSL.md) | Heranca directa | Plugin interface |
| `SSLImplementation` (var global) | Default | Inicializado como `TSSLNone` |
| `TSSLOpenSSL`/`TSSLOpenSSL3`/`TSSLOpenSSL4` | Substitutos | Plugins reais que sobrescrevem `SSLImplementation` no `initialization` |
| [TTCPBlockSocket](TTCPBlockSocket.md) | Composicao | Criado automaticamente como `TSSLNone` se nenhum plugin registrado |
