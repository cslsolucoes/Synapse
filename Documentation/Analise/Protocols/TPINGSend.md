# TPINGSend

**Unit:** `pingsend.pas` | **Versao:** 004.000.004 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TPINGSend` e o cliente ICMP PING do Synapse, suportando ICMPv4 e ICMPv6. Duas implementacoes convivem: IpHlpApi (WinXP+) quando disponivel, e RAW sockets como fallback. Em Linux/Unix, SEMPRE usa RAW sockets, o que requer permissoes elevadas (root ou capability `CAP_NET_RAW`).

A classe envia um echo request com payload de `PacketSize` bytes e mede o RTT (`PingTime`) entre envio e recepcao. A resposta pode ser echo-reply (sucesso) ou mensagem de erro ICMP (time-exceeded, destination-unreachable -- host/admin/addr/port). `ReplyError: TICMPError` devolve a categoria do erro de forma portavel entre IPv4 e IPv6.

Tambem existe `TraceRouteHost` como funcao global: implementa traceroute por incremento de TTL + captura de time-exceeded.

## 2. Caracteristicas

- ICMPv4 (RFC-792) e ICMPv6 (RFC-2292/4443)
- Duas implementacoes: IpHlpApi (Windows) e RAW sockets (portavel)
- TTL configuravel para traceroute
- Medida de `PingTime` (ms)
- Categorizacao independente de IPv4/IPv6 via `TICMPError`
- Hosts identificados por hostname, IPv4 ou IPv6

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| ICMP_ECHO / ICMP_ECHOREPLY | 8 / 0 (IPv4) |
| ICMP6_ECHO / ICMP6_ECHOREPLY | 128 / 129 (IPv6) |
| ICMP_UNREACH | 3 (IPv4) / 1 (IPv6) |
| ICMP_TIME_EXCEEDED | 11 (IPv4) / 3 (IPv6) |
| Herda de | `TSynaClient` |
| PacketSize default | 32 bytes |

### 3.1 TICMPError

| Valor | Significado |
| --- | --- |
| `IE_NoError` | Echo-reply OK |
| `IE_Other` | Outro erro ICMP |
| `IE_TTLExceed` | TTL esgotado (usado em traceroute) |
| `IE_UnreachOther` | Destination unreachable -- razao desconhecida |
| `IE_UnreachRoute` | No route to host |
| `IE_UnreachAdmin` | Proibido administrativamente |
| `IE_UnreachAddr` | Host unreachable |
| `IE_UnreachPort` | Port unreachable |

## 4. Funcionalidades

### 4.1 Operacoes

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Aloca `TICMPBlockSocket` + buffer. |
| Destroy | `destructor Destroy; override;` | Liberta. |
| Ping | `function Ping(const Host: string): Boolean;` | Envia um echo request ICMP para `Host`. |

### 4.2 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| PacketSize | `property Integer;` | Bytes de payload (default 32). |
| PingTime | `property Integer;` | RTT em ms apos Ping com sucesso. |
| ReplyFrom | `property string;` | IP de onde veio a resposta (pode ser um router intermediario em TTL exceeded). |
| ReplyType | `property byte;` | Tipo ICMP (protocolo-dependente). |
| ReplyCode | `property byte;` | Codigo ICMP (protocolo-dependente). |
| ReplyError | `property TICMPError;` | Categoria portavel de erro. |
| ReplyErrorDesc | `property string;` | Texto humano. |
| TTL | `property byte;` | TTL usado na query (util para traceroute manual). |
| Sock | `property TICMPBlockSocket;` | Socket ICMP. |

### 4.3 Funcoes globais

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| PingHost | `function PingHost(const Host: string): Integer;` | One-shot: retorna ms ou -1. |
| TraceRouteHost | `function TraceRouteHost(const Host: string): string;` | Traceroute texto-formatado. |

## 5. Aplicabilidades

1. **Health-check de servicos** -- pinger em dashboard de monitorizacao (Nagios-style).
2. **Diagnostico de conectividade** -- deteccao de host down ou rota incorrecta.
3. **Traceroute** -- visualizar path via TTL incremental.
4. **SLA monitoring** -- registar RTT para operadora.
5. **Ferramentas de suporte ao utilizador** -- botao "testar rede" em aplicacoes desktop.

## 6. Exemplos de uso

### 6.1 Ping simples

```pascal
uses
  SysUtils, pingsend;

var
  LPing: TPINGSend;
begin
  LPing := TPINGSend.Create;
  try
    if LPing.Ping('google.com') then
      Writeln(Format('RTT %d ms (from %s)', [LPing.PingTime, LPing.ReplyFrom]))
    else
      Writeln(Format('ICMP error: %d - %s', [Ord(LPing.ReplyError), LPing.ReplyErrorDesc]));
  finally
    LPing.Free;
  end;
end.
```

### 6.2 Traceroute manual

```pascal
uses
  SysUtils, pingsend;

var
  LPing: TPINGSend;
  I: Integer;
begin
  LPing := TPINGSend.Create;
  try
    for I := 1 to 30 do
    begin
      LPing.TTL := I;
      LPing.Ping('example.com');
      Writeln(Format('%2d  %-18s  %d ms', [I, LPing.ReplyFrom, LPing.PingTime]));
      if LPing.ReplyError = IE_NoError then
        Break;
    end;
  finally
    LPing.Free;
  end;
end.
```

### 6.3 Monitor contínuo com janela

```pascal
uses
  SysUtils, pingsend;

var
  LPing: TPINGSend;
begin
  LPing := TPINGSend.Create;
  try
    while True do
    begin
      if LPing.Ping('10.0.0.1') then
        Writeln(FormatDateTime('hh:nn:ss', Now), '  OK  ', LPing.PingTime, 'ms')
      else
        Writeln(FormatDateTime('hh:nn:ss', Now), '  FAIL  ', LPing.ReplyErrorDesc);
      Sleep(1000);
    end;
  finally
    LPing.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/timeout. |
| `TICMPBlockSocket` (blcksock) | Composicao | Socket RAW ICMP. |
| `synaip` | Dependencia | Parse IPv4/IPv6. |
| `synautil` | Dependencia | Checksum / helpers. |
| Windows `IpHlpApi.dll` | Dependencia opcional | Implementacao sem RAW (requer nada). |
