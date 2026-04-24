# TICMPBlockSocket / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe concreta | **Origem:** Upstream Synapse

---

## 1. O que e?

`TICMPBlockSocket` e o socket para envio e recepcao de pacotes ICMP (Internet Control Message Protocol), o protocolo usado por `ping`, `traceroute` e mensagens de erro de rede IP. Herda de `TDgramBlockSocket`, retornando `SOCK_RAW` como tipo de socket e `IPPROTO_ICMP` (ou `IPPROTO_ICMPV6`) como protocolo.

Criar sockets ICMP requer privilegios elevados na maioria dos sistemas operacionais: em Windows requer Administrator; em Linux/macOS requer `CAP_NET_RAW` ou `setuid root`. Sem esses privilegios, a criacao do socket falha com erro permissao negada.

No contexto ActiveDirectoryORM, ICMP nao e usado directamente. A unit `pingsend.pas` (Synapse) consome `TICMPBlockSocket` para implementar ping ICMP, e pode servir como health check para disponibilidade do DC antes de tentar LDAP.

---

## 2. Caracteristicas

* Socket RAW ICMP.
* Requer privilegios elevados.
* Suporta ICMPv4 e ICMPv6 (conforme `Family`).
* Herda datagrama de `TDgramBlockSocket`.
* Cross-platform com limitacoes de OS.

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| [TDgramBlockSocket](TDgramBlockSocket.md) | Heranca |
| Winsock / POSIX | Requer privilegio para RAW socket |

---

## 4. Funcionalidades

### 4.1 Identificacao do socket

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSocketType` | `function GetSocketType: integer; override` | `SOCK_RAW` |
| `GetSocketProtocol` | `function GetSocketProtocol: integer; override` | `IPPROTO_ICMP` (IPv4) ou `IPPROTO_ICMPV6` (IPv6) conforme `Family` |

### 4.2 Metodos herdados

| Metodo | Descricao |
| --- | --- |
| `SendBufferTo` / `RecvBufferFrom` | Enviar/receber ICMP payload bruto |
| `Bind(IP, Port: string)` | Vincula interface local; Port e ignorado para ICMP |

---

## 5. Aplicabilidades

1. **Ping ICMP** — usado por `pingsend.pas` para echo request/reply.
2. **Health check de DC antes de LDAP** — testar disponibilidade via ping.
3. **Traceroute** — envio TTL-incremental de ICMP.
4. **Diagnostico de rede** — detectar "Destination Unreachable".

---

## 6. Exemplos de uso

### 6.1 Ping simples via pingsend (consumidor oficial)

```pascal
uses SysUtils, pingsend;

var
  LPing: TPingSend;
begin
  LPing := TPingSend.Create;
  try
    LPing.Timeout := 3000;
    if LPing.Ping('dc01.empresa.local') then
      Writeln('DC ativo, RTT=', LPing.PingTime, 'ms')
    else
      Writeln('DC inativo ou sem privilegio ICMP');
  finally
    LPing.Free;
  end;
end;
```

### 6.2 Health check antes de conectar LDAP

```pascal
uses SysUtils, pingsend, ldapsend, ssl_openssl3;

function DCDisponivel(const AHost: string): Boolean;
var
  LPing: TPingSend;
begin
  LPing := TPingSend.Create;
  try
    LPing.Timeout := 2000;
    Result := LPing.Ping(AHost);
  finally
    LPing.Free;
  end;
end;

var
  LLDAP: TLDAPSend;
begin
  if not DCDisponivel('dc01.empresa.local') then
  begin
    Writeln('DC offline; tentando secundario');
    Exit;
  end;
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Login;
    LLDAP.Bind;
  finally
    LLDAP.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TDgramBlockSocket](TDgramBlockSocket.md) | Heranca directa | |
| [TBlockSocket](TBlockSocket.md) | Heranca (2 niveis) | |
| `TPingSend` (pingsend.pas) | Consumidor principal | |
| [TRAWBlockSocket](TRAWBlockSocket.md) | Irmao | Tambem `SOCK_RAW` mas `IPPROTO_RAW` |
