# TSocksBlockSocket / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe | **Origem:** Upstream Synapse

---

## 1. O que e?

`TSocksBlockSocket` e uma classe intermediaria da hierarquia de sockets Synapse que adiciona suporte a proxies SOCKS4, SOCKS4a e SOCKS5. Herda de `TBlockSocket` e e herdada por `TTCPBlockSocket` e `TDgramBlockSocket` — qualquer protocolo TCP ou UDP do Synapse pode, portanto, ser tunelado atraves de SOCKS sem modificar o codigo do consumidor.

A classe nao deve ser instanciada directamente. Para ativar SOCKS, o consumidor atribui valor a `SocksIP` (atribuicao nao-vazia habilita o modo) + opcionalmente `SocksPort`, `SocksUsername`/`SocksPassword` (SOCKS5 auth), `SocksType` (SOCKS5 default; SOCKS4) e `SocksResolver` (se `True`, resolucao DNS e feita pelo proxy — SOCKS4a quando aplicavel).

Em contexto ActiveDirectoryORM, SOCKS nao e o cenario principal (LDAP tipicamente usa HTTP tunnel ou conexao directa), mas esta disponivel para ambientes onde o GestorERP precise alcancar um DC atraves de SOCKS5 corporativo (raro, mas suportado).

---

## 2. Caracteristicas

* Classe intermediaria (nao instancie directamente).
* Suporte SOCKS4, SOCKS4a (via `SocksResolver`), SOCKS5.
* Autenticacao user/password opcional (SOCKS5).
* Timeout configuravel para comunicacao com o proxy.
* Mutuamente exclusivo com HTTP tunnel (em `TTCPBlockSocket` nao combinar ambos).
* Cross-platform (via `TBlockSocket`).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| [TBlockSocket](TBlockSocket.md) | Heranca (infraestrutura I/O e hooks) |
| `TSocksType` | Enum `ST_Socks5`, `ST_Socks4` |
| `synsock` | Primitivas de socket |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create` | Inicializa; `SocksPort := '1080'`, `SocksTimeout := 60000`, `SocksResolver := True`, `SocksType := ST_Socks5` |

### 4.2 Protocolo SOCKS (internos expostos)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SocksOpen` | `function SocksOpen: Boolean` | Conecta ao proxy + autorizacao se `SocksUsername` setado (interno) |
| `SocksRequest` | `function SocksRequest(Cmd: Byte; const IP, Port: string): Boolean` | Envia request `CONNECT`/`BIND`/`UDP ASSOCIATE` |
| `SocksResponse` | `function SocksResponse: Boolean` | Le resposta; atualiza `SocksLastError` em falha |
| `SocksCode` (protected) | `function SocksCode(IP, Port: string): AnsiString` | Codifica endereco para protocolo SOCKS |
| `SocksDecode` (protected) | `function SocksDecode(Value: AnsiString): integer` | Decodifica resposta |

### 4.3 Properties

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `SocksIP` | `string` | R/W | IP do servidor SOCKS; atribuicao nao-vazia ativa o modo |
| `SocksPort` | `string` | R/W | Porta (default `'1080'`) |
| `SocksUsername` | `string` | R/W | User SOCKS5 auth |
| `SocksPassword` | `string` | R/W | Pass SOCKS5 auth |
| `SocksTimeout` | `Integer` | R/W | Timeout ms (default 60000) |
| `SocksResolver` | `Boolean` | R/W | `True` = DNS feito pelo proxy (SOCKS4a quando SOCKS4) |
| `SocksType` | `TSocksType` | R/W | `ST_Socks5` (default) ou `ST_Socks4` |
| `UsingSocks` | `Boolean` | R | `True` quando mode ativo |
| `SocksLastError` | `Integer` | R | Codigo erro retornado pelo proxy |

---

## 5. Aplicabilidades

1. **Tunel LDAPS via SOCKS5 corporativo** — configurar antes de `TLDAPSend.Login`.
2. **Auditoria de trafego** — apontar para proxy SOCKS inspeccionar.
3. **Teste de politicas** — simular conexoes de outras redes via SOCKS.
4. **Bypass de firewall** — quando IP directo e bloqueado mas SOCKS e permitido.

---

## 6. Exemplos de uso

### 6.1 LDAPS via SOCKS5 corporativo

```pascal
uses SysUtils, ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL := True;

    LLDAP.Sock.SocksIP       := '10.0.0.99';
    LLDAP.Sock.SocksPort     := '1080';
    LLDAP.Sock.SocksType     := ST_Socks5;
    LLDAP.Sock.SocksUsername := 'tunel';
    LLDAP.Sock.SocksPassword := 'secret';
    LLDAP.Sock.SocksResolver := True;

    LLDAP.Sock.SNIHost := 'dc01.empresa.local';
    LLDAP.Sock.VerifyCert := True;

    if LLDAP.Login and LLDAP.Bind then
      Writeln('OK');
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 Verificar se SOCKS ativo e trocar para SOCKS4

```pascal
uses blcksock, ldapsend;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.Sock.SocksIP := '10.0.0.99';
    LLDAP.Sock.SocksType := ST_Socks4;
    LLDAP.Sock.SocksResolver := True;   // SOCKS4a

    LLDAP.Login;
    Writeln('Using SOCKS? ', LLDAP.Sock.UsingSocks);
  finally
    LLDAP.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TBlockSocket](TBlockSocket.md) | Heranca directa | Infraestrutura base |
| [TTCPBlockSocket](TTCPBlockSocket.md) | Subclasse | TCP + SSL + HTTP tunnel |
| [TDgramBlockSocket](TDgramBlockSocket.md) | Subclasse | UDP/datagrama + SOCKS |
| `TSocksType` | Enum | `ST_Socks4`, `ST_Socks5` |
