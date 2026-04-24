# TBlockSocket / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe abstrata | **Origem:** Upstream Synapse

---

## 1. O que e?

`TBlockSocket` e a classe base abstrata de toda a hierarquia de sockets da Ararat Synapse. Herda directamente de `TObject` e fornece a infraestrutura comum para I/O sincrono, hooks de observabilidade, resolucao DNS, gestao de timeouts, bandwidth limiting e opcoes de socket. Nao deve ser instanciada directamente — o consumidor usa uma das subclasses concretas: `TTCPBlockSocket`, `TUDPBlockSocket`, `TICMPBlockSocket`, `TRAWBlockSocket`, `TPGMMessageBlockSocket`, `TPGMStreamBlockSocket`.

Toda a comunicacao real com o sistema operacional e feita atraves da unit `synsock` (camada plataforma-agnostica que inclui condicionalmente `sswin32.inc`, `ssfpc.inc`, `ssposix.inc` ou `sslinux.inc`). `TBlockSocket` e a fachada Pascal sobre essa camada, mapeando primitivas POSIX/Winsock (`socket`, `connect`, `bind`, `listen`, `accept`, `send`, `recv`, `select`, `setsockopt`) em metodos tipados com tratamento de erro coerente (`LastError` + hook `HR_Error`).

---

## 2. Caracteristicas

* Classe base de toda a hierarquia Synapse de sockets.
* Suporte IPv4 + IPv6 dinamico via `TSocketFamily`.
* Sistema de hooks ricos (status, monitor, heartbeat, data filter, create socket).
* Bandwidth limiting (send + recv) em bytes/s.
* Delayed options (opcoes aplicadas apos criacao do socket).
* Thread-safe para sockets distintos (cada socket deve ser usado por 1 thread).
* Sem dependencia directa de SSL (isso e feito por `TTCPBlockSocket`).
* Cross-platform via `synsock`.

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| `{$DEFINE ONCEWINSOCK}` | Inicializa Winsock uma vez por processo |
| `synsock` | Camada plataforma-agnostica; todas as syscalls passam por ela |
| `TFDSet` / `TWSADATA` / `TSocket` | Tipos nativos expostos via `synsock` |
| `{$IFDEF POSIX}` | `TOptionList = TList<TSynaOption>` (generico) |
| `{$ELSE}` | `TOptionList = TList` (Delphi non-POSIX) |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create` | Cria objeto sem socket nativo (socket e criado em `Connect` ou `Bind`) |
| `CreateAlternate` | `constructor CreateAlternate(Stub: string)` | Cria carregando biblioteca de socket custom; `Stub` vazio = default |
| `Destroy` | `destructor Destroy; override` | Libera socket e limpa `FDelayedOptions` |
| `CreateSocket` | `procedure CreateSocket` | Cria socket nativo conforme `Family` e aplica `FDelayedOptions` |
| `CreateSocketByName` | `procedure CreateSocketByName(const Value: String)` | Cria socket inferindo familia pela resolucao de `Value` |
| `CloseSocket` | `procedure CloseSocket; virtual` | Fecha o socket; dispara `HR_SocketClose` |
| `AbortSocket` | `procedure AbortSocket; virtual` | Aborta operacoes pendentes |

### 4.2 Conexao e binding

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Bind` | `procedure Bind(const IP, Port: string)` | Bind local; `'0.0.0.0'`/`'0'` = implicit bind |
| `Connect` | `procedure Connect(IP, Port: string); virtual` | Conecta ao IP/porta remoto; cria socket se necessario |
| `Listen` | `procedure Listen; virtual` | Modo escuta (requer `Bind` previo) |
| `Accept` | `function Accept: TSocket; virtual` | Aceita conexao entrante |
| `SetRemoteSin` | `procedure SetRemoteSin(IP, Port: string)` | Define `RemoteSin` sem connect (UDP) |
| `GetSinLocal` / `GetSinRemote` / `GetSins` | procedures | Refrescam estruturas `Sin` |
| `EnableReuse` | `procedure EnableReuse(Value: Boolean)` | `SO_REUSEADDR` |

### 4.3 I/O

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(const Buffer: TMemory; Length: Integer): Integer; virtual` | Envia bytes |
| `SendByte` | `procedure SendByte(Data: Byte); virtual` | Envia 1 byte |
| `SendString` | `procedure SendString(Data: AnsiString); virtual` | Envia string inteira |
| `SendInteger` | `procedure SendInteger(Data: integer); virtual` | Envia 4 bytes |
| `SendBlock` | `procedure SendBlock(const Data: AnsiString); virtual` | Bloco tamanho-prefixado (4 bytes) |
| `SendStream` / `SendStreamRaw` / `SendStreamIndy` | procedures | Variacoes envio de stream |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Length: Integer): Integer; virtual` | Recebe bytes |
| `RecvBufferEx` | `function RecvBufferEx(Buffer: TMemory; Len: Integer; Timeout: Integer): Integer; virtual` | Le `Len` bytes exatos |
| `RecvBufferStr` | `function RecvBufferStr(Len: Integer; Timeout: Integer): AnsiString; virtual` | Le `Len` bytes como string |
| `RecvByte` | `function RecvByte(Timeout: Integer): Byte; virtual` | Le 1 byte |
| `RecvInteger` | `function RecvInteger(Timeout: Integer): Integer; virtual` | Le 4 bytes |
| `RecvTerminated` | `function RecvTerminated(Timeout: Integer; const Terminator: AnsiString): AnsiString; virtual` | Le ate terminator custom |
| `RecvString` | `function RecvString(Timeout: Integer): AnsiString; virtual` | Le linha CRLF |
| `RecvPacket` | `function RecvPacket(Timeout: Integer): AnsiString; virtual` | Pacote completo |
| `RecvBlock` | `function RecvBlock(Timeout: Integer): AnsiString; virtual` | Bloco tamanho-prefixado |
| `RecvStream` / `RecvStreamSize` / `RecvStreamRaw` / `RecvStreamIndy` | procedures | Variacoes recepcao para stream |
| `PeekBuffer` | `function PeekBuffer(Buffer: TMemory; Length: Integer): Integer; virtual` | Peek sem consumir |
| `PeekByte` | `function PeekByte(Timeout: Integer): Byte; virtual` | Peek 1 byte |
| `Purge` | `procedure Purge` | Limpa buffers |

### 4.4 UDP/Datagrama

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBufferTo` | `function SendBufferTo(const Buffer: TMemory; Length: Integer): Integer; virtual` | `sendto()` |
| `RecvBufferFrom` | `function RecvBufferFrom(Buffer: TMemory; Length: Integer): Integer; virtual` | `recvfrom()` |

### 4.5 Estado

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `WaitingData` | `function WaitingData: Integer; virtual` | Bytes disponiveis no socket |
| `WaitingDataEx` | `function WaitingDataEx: Integer` | Incluindo `LineBuffer` |
| `CanRead` / `CanReadEx` / `CanWrite` | `function CanXxx(Timeout: Integer): Boolean; virtual` | Wait + `select()` |
| `GroupCanRead` | `function GroupCanRead(const SocketList: TSocketList; Timeout: Integer; ...): Boolean` | `select()` em grupo |

### 4.6 Resolucao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `ResolveName` | `function ResolveName(Name: string): string` | DNS -> IP |
| `ResolveNameToIP` | `procedure ResolveNameToIP(Name: string; const IPList: TStrings)` | Todos IPs |
| `ResolveIPToName` | `function ResolveIPToName(IP: string): string` | Reverse DNS |
| `ResolvePort` | `function ResolvePort(Port: string): Word` | `'http'` -> 80 |
| `LocalName` | `function LocalName: string` | Hostname local |

### 4.7 Timeouts + linger

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SetTimeout` | `procedure SetTimeout(Timeout: Integer)` | Send+recv timeouts iguais |
| `SetSendTimeout` | `procedure SetSendTimeout(Timeout: Integer)` | Apenas send |
| `SetRecvTimeout` | `procedure SetRecvTimeout(Timeout: Integer)` | Apenas recv |
| `SetLinger` | `procedure SetLinger(Enable: Boolean; Linger: Integer)` | `SO_LINGER` |

### 4.8 Erro e controle

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `ResetLastError` | `procedure ResetLastError` | Zera `FLastError` |
| `SockCheck` | `function SockCheck(SockResult: Integer): Integer; virtual` | Converte resultado Winsock em `LastError` |
| `ExceptCheck` | `procedure ExceptCheck` | Levanta `ESynapseError` se `RaiseExcept = True` |
| `GetErrorDescEx` | `function GetErrorDescEx: string; virtual` | Descricao humana |
| `GetErrorDesc` | `class function GetErrorDesc(ErrorCode: Integer): string` | Mapa codigo -> texto |

### 4.9 Properties importantes

| Property | Tipo | Descricao |
| --- | --- | --- |
| `Socket` | `TSocket` | Descritor nativo |
| `LastError` | `Integer` | Codigo Winsock |
| `LastErrorDesc` | `string` | Texto |
| `LocalSin` / `RemoteSin` | `TVarSin` | Enderecos |
| `Family` / `PreferIP4` / `IP6used` | IPv4/IPv6 config |
| `NonBlockMode` / `ConnectionTimeout` / `NonblockSendTimeout` | Modo e timeouts |
| `MaxSendBandwidth` / `MaxRecvBandwidth` / `MaxBandwidth` | Limites |
| `HeartbeatRate` + `OnHeartbeat` | Callback periodico |
| `RaiseExcept` | `Boolean` — levanta `ESynapseError` ou usa `LastError` |
| `RecvCounter` / `SendCounter` | Contadores totais |
| `StopFlag` | Aborta loops |
| `Tag` / `Owner` | Uso do consumidor |
| `TTL` / `SizeRecvBuffer` / `SizeSendBuffer` | Opcoes delayadas |
| `OnStatus` / `OnReadFilter` / `OnCreateSocket` / `OnMonitor` | Hooks |

---

## 5. Aplicabilidades

1. **Nao instanciar directamente** — usar `TTCPBlockSocket`, `TUDPBlockSocket`, etc.
2. **Extensao custom** — criar subclasse para protocolos exoticos (raw, PGM).
3. **Monitoramento global** — atribuir `OnStatus` a uma instancia recebe todos os eventos `HR_*` para telemetria.
4. **Bandwidth throttling** — configurar `MaxSendBandwidth`/`MaxRecvBandwidth` para simular latencia ou respeitar politicas.
5. **Multiplexing** — `GroupCanRead` sobre `TSocketList` permite `select()` em varios sockets (servidor simples).

---

## 6. Exemplos de uso

### 6.1 Observabilidade via OnStatus

```pascal
uses SysUtils, blcksock, ldapsend, ssl_openssl3;

procedure LogStatus(Sender: TObject; Reason: THookSocketReason;
                    const Value: String);
var
  LReasonStr: string;
begin
  case Reason of
    HR_Connect:    LReasonStr := 'Connect';
    HR_SocketClose:LReasonStr := 'Close';
    HR_ReadCount:  LReasonStr := 'Read';
    HR_WriteCount: LReasonStr := 'Write';
    HR_Error:      LReasonStr := 'Error';
  else
    LReasonStr := 'Other';
  end;
  Writeln('[', LReasonStr, '] ', Value);
end;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Sock.OnStatus := LogStatus;
    LLDAP.Login;
    LLDAP.Bind;
  finally
    LLDAP.Free;
  end;
end;
```

### 6.2 Bandwidth throttling

```pascal
uses blcksock, ldapsend;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Sock.MaxBandwidth := 512 * 1024;  // 512 KB/s total
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
| `TObject` | Heranca | Base Delphi |
| [Synsock](Synsock.md) | Dependencia | Camada plataforma-agnostica |
| [TSocksBlockSocket](TSocksBlockSocket.md) | Subclasse | Adiciona SOCKS4/5 |
| [TTCPBlockSocket](TTCPBlockSocket.md) | Subclasse (2 niveis) | Adiciona SSL + HTTP tunnel |
| [TDgramBlockSocket](TDgramBlockSocket.md) | Subclasse | UDP/datagrama |
| [TUDPBlockSocket](TUDPBlockSocket.md) | Subclasse (3 niveis) | UDP |
| [TICMPBlockSocket](TICMPBlockSocket.md) | Subclasse | ICMP |
| [TRAWBlockSocket](TRAWBlockSocket.md) | Subclasse | RAW |
| [TPGMMessageBlockSocket](TPGMMessageBlockSocket.md) | Subclasse | PGM message |
| [TPGMStreamBlockSocket](TPGMStreamBlockSocket.md) | Subclasse | PGM stream |
| [TSynaOption](TSynaOption.md) | Uso interno | Delayed socket options |
| `ESynapseError` | Excecao | Levantada com `RaiseExcept = True` |
