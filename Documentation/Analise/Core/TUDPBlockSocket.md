# TUDPBlockSocket / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe concreta | **Origem:** Upstream Synapse

---

## 1. O que e?

`TUDPBlockSocket` e a implementacao concreta de socket UDP do Synapse. Herda de `TDgramBlockSocket` e adiciona suporte nativo a broadcasts, multicast groups (IPv4 + IPv6), Multicast TTL (Time-to-Live) e SOCKS5 UDP Association.

Em UDP nao ha conceito de "conexao persistente": cada datagrama pode ser enviado a um destino diferente. O mecanismo de `TDgramBlockSocket.Connect` apenas associa um `RemoteSin` default. UDP e adequado para DNS, NTP, SNMP, telemetria de baixa latencia, voz, video e descoberta de rede.

No contexto ActiveDirectoryORM, `TUDPBlockSocket` nao e directamente consumido (LDAP usa TCP/TLS), mas aparece como uma classe irmaozinha na hierarquia. Outros protocolos como `sntpsend` (NTP), `snmpsend` (SNMP) e `dnssend` (DNS) herdam-no.

---

## 2. Caracteristicas

* Socket UDP IPv4 e IPv6.
* Broadcast unilateral via `EnableBroadcast`.
* Multicast (join/leave groups) com TTL configuravel.
* SOCKS5 UDP Association (usa `FSocksControlSock: TTCPBlockSocket` interno).
* Cross-platform (IPv6 requer sistema com suporte nativo).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| `{$IFNDEF CIL}` | `AddMulticast`/`DropMulticast` so em Delphi/FPC (nao .NET) |
| [TDgramBlockSocket](TDgramBlockSocket.md) | Heranca |
| `synsock` | Primitivas UDP |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Destroy` | `destructor Destroy; override` | Libera `FSocksControlSock` e socket UDP |

### 4.2 Broadcast

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `EnableBroadcast` | `procedure EnableBroadcast(Value: Boolean)` | `SO_BROADCAST`; nao suportado em SOCKS5 nem IPv6 |

### 4.3 Multicast

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `AddMulticast` | `procedure AddMulticast(MCastIP: string)` | Join multicast group |
| `DropMulticast` | `procedure DropMulticast(MCastIP: string)` | Leave multicast group |
| `EnableMulticastLoop` | `procedure EnableMulticastLoop(Value: Boolean)` | Loopback local de datagramas enviados |
| `SetMulticastTTL` (protected) | `procedure SetMulticastTTL(TTL: integer)` | TTL para multicast |
| `GetMulticastTTL` (protected) | `function GetMulticastTTL: integer` | |
| `MulticastTTL` (property) | `Integer` R/W | Interface publica para TTL |

### 4.4 UDP sobre SOCKS5

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `UdpAssociation` (protected) | `function UdpAssociation: Boolean` | Negocia UDP ASSOCIATE com SOCKS5 |

### 4.5 I/O sobrescrito

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBufferTo` | `function SendBufferTo(const Buffer: TMemory; Length: Integer): Integer; override` | Inclui trip UDP ASSOCIATE se em SOCKS5 |
| `RecvBufferFrom` | `function RecvBufferFrom(Buffer: TMemory; Length: Integer): Integer; override` | Idem |

### 4.6 Socket type/protocol

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSocketType` | `function GetSocketType: integer; override` | `SOCK_DGRAM` |
| `GetSocketProtocol` | `function GetSocketProtocol: integer; override` | `IPPROTO_UDP` |

---

## 5. Aplicabilidades

1. **Consulta DNS manual** (`dnssend` herda indirectamente).
2. **NTP/SNTP** (`sntpsend`).
3. **SNMP** (`snmpsend`).
4. **Descoberta LAN via multicast** — ex.: WS-Discovery, SSDP, mDNS.
5. **Logging UDP / Syslog** (`slogsend`).
6. **Telemetria** — metricas, statsd.

---

## 6. Exemplos de uso

### 6.1 Multicast listener (group 239.255.0.1)

```pascal
uses SysUtils, blcksock;

var
  LUDP: TUDPBlockSocket;
  LBuf: array[0..1023] of Byte;
  LLen: Integer;
begin
  LUDP := TUDPBlockSocket.Create;
  try
    LUDP.Bind('0.0.0.0', '5353');
    LUDP.AddMulticast('239.255.0.1');
    LUDP.EnableMulticastLoop(True);

    while True do
    begin
      LLen := LUDP.RecvBufferFrom(@LBuf[0], SizeOf(LBuf));
      if LLen > 0 then
        Writeln('Pacote de ', LUDP.GetRemoteSinIP, ': ', LLen, ' bytes');
    end;
  finally
    LUDP.DropMulticast('239.255.0.1');
    LUDP.Free;
  end;
end;
```

### 6.2 Broadcast + timeout

```pascal
uses SysUtils, blcksock;

var
  LUDP: TUDPBlockSocket;
  LPayload: AnsiString;
begin
  LUDP := TUDPBlockSocket.Create;
  try
    LUDP.EnableBroadcast(True);
    LPayload := 'DISCOVER?';
    LUDP.Connect('255.255.255.255', '10000');
    LUDP.SendBuffer(PAnsiChar(LPayload), Length(LPayload));

    if LUDP.CanRead(2000) then
      Writeln('Resposta: ', LUDP.RecvPacket(500));
  finally
    LUDP.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TDgramBlockSocket](TDgramBlockSocket.md) | Heranca directa | |
| [TSocksBlockSocket](TSocksBlockSocket.md) | Heranca (2) | SOCKS5 UDP support |
| [TBlockSocket](TBlockSocket.md) | Heranca (3) | Base |
| [TTCPBlockSocket](TTCPBlockSocket.md) | Composicao (via `FSocksControlSock`) | Controle SOCKS5 |
| `TUDPSocket`-like em `dnssend`/`sntpsend`/`snmpsend`/`slogsend` | Consumidor | |
