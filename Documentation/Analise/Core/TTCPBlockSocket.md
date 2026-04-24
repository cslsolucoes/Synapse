# TTCPBlockSocket / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe | **Origem:** Upstream 009.011.000 + CSL fork (`GetPeerCertSHA256Hash`, fixes WSAECONNRESET)

---

## 1. O que e?

`TTCPBlockSocket` e a implementacao principal do socket TCP bloqueante da Ararat Synapse. Herda de `TSocksBlockSocket` (suporte a SOCKS4/5), que por sua vez herda de `TBlockSocket` (classe base). Adiciona sobre a pilha de sockets genericos do Synapse tres funcionalidades criticas: (1) suporte SSL/TLS via plugin intercambiavel (`TCustomSSL`), (2) tunelamento HTTP CONNECT para proxies corporativos e (3) hooks de `OnAfterConnect`.

No contexto ActiveDirectoryORM, `TTCPBlockSocket` e o transporte TCP subjacente de `TLDAPSend`. O socket e acessivel externamente via `TLDAPSend.Sock`, o que permite configurar `SNIHost`, `CertCAFile`, `VerifyCert`, proxies e timeouts antes do `Login` para garantir LDAPS autenticado conforme politicas AD WS 2025.

A versao 009.011.001 (CSL fork) adicionou o metodo `GetPeerCertSHA256Hash` (via cast para `TSSLOpenSSL`/`TSSLOpenSSL3`/`TSSLOpenSSL4`) necessario para implementar Channel Binding Token (RFC 5929) e incluiu tratamento explicito de `WSAECONNRESET` em `RecvBuffer`, `RecvPacket` e `SendBuffer` — fix para conexoes LDAPS de longa duracao onde o DC pode fechar o canal apos periodos de inatividade.

---

## 2. Caracteristicas

* **Bloqueante por padrao**: operacoes I/O bloqueiam a thread ate conclusao ou timeout; modo nao-bloqueante via `NonBlockMode`.
* **Plugin SSL intercambiavel**: `TCustomSSL` criado via `SSLImplementation` (default global) ou construtor `CreateWithSSL(class)`.
* **IPv4 e IPv6 dinamicos**: `Family` (`SF_Any`, `SF_IP4`, `SF_IP6`) determina modo do socket; `SF_Any` decide pela resolucao DNS.
* **Proxy SOCKS4/4a/5**: heranca de `TSocksBlockSocket`; configurar `SocksIP`, `SocksPort`, `SocksType`, `SocksUsername`, `SocksPassword`.
* **HTTP CONNECT tunnel**: propriedades `HTTPTunnelIP`/`HTTPTunnelPort`/`HTTPTunnelUser`/`HTTPTunnelPass` ativam tunelamento.
* **Tratamento WSAECONNRESET (CSL fork)**: evita crash silencioso em LDAPS longas.
* **Bandwidth limiting**: `MaxSendBandwidth` e `MaxRecvBandwidth` (bytes/s).
* **Heartbeat**: `HeartbeatRate` + `OnHeartbeat` para callback periodico durante I/O longo.
* **Hooks extensivos**: `OnStatus`, `OnReadFilter`, `OnCreateSocket`, `OnMonitor`, `OnAfterConnect`, `OnVerifyCert`.
* **CSL extension**: `(Sock.SSL as TSSLOpenSSL).GetPeerCertSHA256Hash` para CBT RFC 5929.
* **Cross-platform**: Windows (Winsock via `sswin32.inc`), Linux/BSD (POSIX via `ssfpc.inc`/`ssposix.inc`).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$DEFINE ONCEWINSOCK}` | Inicializa Winsock uma unica vez no processo (performance com muitos sockets) |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| `{$IFDEF MSWINDOWS}` | Winsock, `secur32` (via ldapsend), Windows API |
| `{$IFDEF POSIX}` | Usa `System.Generics.Collections` para `TOptionList`/`TSocketList` |
| `{$IFDEF CIL}` | Blocos alternativos .NET (`System.Net.Sockets`) |
| `{$Q-}` | Desabilita overflow checks (performance) |
| `synsock` (uses) | Camada plataforma-agnostica de sockets (ver [Synsock.md](Synsock.md)) |
| `ssl_openssl.pas` (plugin padrao) | Registrado em `SSLImplementation` se OpenSSL disponivel |
| `SSLImplementation: TSSLClass = TSSLNone` (var global) | Default quando nenhum plugin e ativado |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create` | Cria socket TCP com plugin SSL padrao (`SSLImplementation`) |
| `CreateWithSSL` | `constructor CreateWithSSL(SSLPlugin: TSSLClass)` | Cria socket com plugin SSL especifico (ex.: `TSSLOpenSSL3`) |
| `Destroy` | `destructor Destroy; override` | Libera plugin SSL e fecha socket |
| `CloseSocket` | `procedure CloseSocket; override` | Fecha o socket; dispara hook `HR_SocketClose` |
| `AbortSocket` (herdado) | `procedure AbortSocket; virtual` | Aborta operacoes pendentes e destroi o socket |

### 4.2 Conexao e TLS

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Connect` | `procedure Connect(IP, Port: string); override` | Conecta ao host/porta; resolve DNS; aplica SOCKS/HTTP tunnel se configurado; dispara `OnAfterConnect` |
| `Bind` (herdado) | `procedure Bind(const IP, Port: string)` | Bind local; `'0.0.0.0'`/`'0'` = implicit system bind |
| `Listen` | `procedure Listen; override` | Coloca socket em modo escuta (servidor TCP); suporta SOCKS BIND |
| `Accept` | `function Accept: TSocket; override` | Aguarda e aceita conexao entrante; retorna descritor |
| `SSLDoConnect` | `procedure SSLDoConnect` | Upgrade TLS sobre TCP plaintext (usado por StartTLS LDAP) |
| `SSLDoShutdown` | `procedure SSLDoShutdown` | Downgrade TLS -> TCP plaintext |
| `SSLAcceptConnection` | `function SSLAcceptConnection: Boolean` | Inicia handshake TLS no lado servidor apos `Accept` |
| `EnableReuse` (herdado) | `procedure EnableReuse(Value: Boolean)` | `SO_REUSEADDR` |

### 4.3 Transferencia de dados

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(const Buffer: TMemory; Length: Integer): Integer; override` | Envia buffer; trata `WSAECONNRESET` silenciosamente (CSL fix) |
| `SendString` (herdado) | `procedure SendString(Data: AnsiString); virtual` | Envia string inteira sem adicionar terminador |
| `SendByte` (herdado) | `procedure SendByte(Data: Byte); virtual` | Envia 1 byte |
| `SendInteger` (herdado) | `procedure SendInteger(Data: integer); virtual` | Envia 4 bytes |
| `SendBlock` (herdado) | `procedure SendBlock(const Data: AnsiString); virtual` | Envia bloco com 4 bytes de tamanho prefixado |
| `SendStream` (herdado) | `procedure SendStream(const Stream: TStream); virtual` | Envia conteudo do stream via `SendBlock` |
| `SendStreamRaw` (herdado) | `procedure SendStreamRaw(const Stream: TStream); virtual` | Envia stream sem tamanho prefixado |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Recebe dados; trata `WSAECONNRESET` + `SSL_ERROR_ZERO_RETURN` |
| `RecvBufferEx` (herdado) | `function RecvBufferEx(Buffer: TMemory; Len: Integer; Timeout: Integer): Integer` | Recebe `Len` bytes exatos com timeout |
| `RecvBufferStr` (herdado) | `function RecvBufferStr(Len: Integer; Timeout: Integer): AnsiString` | Recebe `Len` bytes como string |
| `RecvPacket` | `function RecvPacket(Timeout: Integer): AnsiString; override` | Recebe pacote completo (tudo disponivel) com timeout |
| `RecvString` (herdado) | `function RecvString(Timeout: Integer): AnsiString; virtual` | Recebe linha terminada por CRLF |
| `RecvTerminated` (herdado) | `function RecvTerminated(Timeout: Integer; const Terminator: AnsiString): AnsiString; virtual` | Recebe ate encontrar terminador custom |
| `RecvByte` (herdado) | `function RecvByte(Timeout: Integer): Byte; virtual` | Recebe 1 byte |
| `RecvInteger` (herdado) | `function RecvInteger(Timeout: Integer): Integer; virtual` | Recebe 4 bytes |
| `RecvBlock` (herdado) | `function RecvBlock(Timeout: Integer): AnsiString; virtual` | Recebe bloco `SendBlock`-prefixado |
| `RecvStream` (herdado) | `procedure RecvStream(const Stream: TStream; Timeout: Integer); virtual` | Recebe stream (block-prefixado) |
| `PeekBuffer` (herdado) | `function PeekBuffer(Buffer: TMemory; Length: Integer): Integer; virtual` | Peek sem remover do buffer |
| `PeekByte` (herdado) | `function PeekByte(Timeout: Integer): Byte; virtual` | Peek 1 byte |
| `Purge` (herdado) | `procedure Purge` | Limpa buffers pendentes |

### 4.4 Estado e disponibilidade

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `WaitingData` | `function WaitingData: Integer; override` | Bytes disponiveis para leitura (considera buffer SSL) |
| `WaitingDataEx` (herdado) | `function WaitingDataEx: Integer` | Incluindo bytes em `LineBuffer` |
| `CanRead` (herdado) | `function CanRead(Timeout: Integer): Boolean; virtual` | Aguarda dados legiveis |
| `CanReadEx` (herdado) | `function CanReadEx(Timeout: Integer): Boolean; virtual` | Incluindo `LineBuffer` |
| `CanWrite` (herdado) | `function CanWrite(Timeout: Integer): Boolean; virtual` | Aguarda socket pronto para escrita |
| `GetSocketType` | `function GetSocketType: integer; override` | Retorna `SOCK_STREAM` |
| `GetSocketProtocol` | `function GetSocketProtocol: integer; override` | Retorna `IPPROTO_TCP` |

### 4.5 Resolucao de nomes

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `ResolveName` (herdado) | `function ResolveName(Name: string): string` | DNS A/AAAA -> IP |
| `ResolveIPToName` (herdado) | `function ResolveIPToName(IP: string): string` | Reverse DNS |
| `ResolvePort` (herdado) | `function ResolvePort(Port: string): Word` | `'http'` -> 80 etc. |
| `ResolveNameToIP` (herdado) | `procedure ResolveNameToIP(Name: string; const IPList: TStrings)` | Todos os IPs de um host |

### 4.6 Informacoes de conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetLocalSinIP` | `function GetLocalSinIP: string; override` | IP local |
| `GetRemoteSinIP` | `function GetRemoteSinIP: string; override` | IP remoto |
| `GetLocalSinPort` | `function GetLocalSinPort: Integer; override` | Porta local |
| `GetRemoteSinPort` | `function GetRemoteSinPort: Integer; override` | Porta remota |
| `GetSinIP` (herdado, protected) | `function GetSinIP(Sin: TVarSin): string` | Helper |
| `GetSinPort` (herdado, protected) | `function GetSinPort(Sin: TVarSin): Integer` | Helper |
| `GetErrorDescEx` | `function GetErrorDescEx: string; override` | Descricao erro (inclui SSL) |
| `GetErrorDesc` (class, herdado) | `class function GetErrorDesc(ErrorCode: Integer): string` | Mapeia codigo para texto |
| `LocalName` (herdado) | `function LocalName: string` | Hostname local |

### 4.7 Timeouts e opcoes

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SetTimeout` (herdado) | `procedure SetTimeout(Timeout: Integer)` | Define send+recv timeouts iguais |
| `SetSendTimeout` (herdado) | `procedure SetSendTimeout(Timeout: Integer)` | Apenas send |
| `SetRecvTimeout` (herdado) | `procedure SetRecvTimeout(Timeout: Integer)` | Apenas recv |
| `SetLinger` (herdado) | `procedure SetLinger(Enable: Boolean; Linger: Integer)` | `SO_LINGER` |

### 4.8 Properties SSL/TLS (via Sock.SSL)

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `SSL` | `TCustomSSL` | R | Instancia do plugin SSL; cast para `TSSLOpenSSL` para `GetPeerCertSHA256Hash` |
| `HTTPTunnel` | `Boolean` | R | `True` quando HTTP tunnel ativo |

### 4.9 Properties HTTP Tunnel

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `HTTPTunnelIP` | `string` | R/W | IP do proxy HTTP (atribuir ativa tunnel) |
| `HTTPTunnelPort` | `string` | R/W | Porta do proxy HTTP |
| `HTTPTunnelUser` | `string` | R/W | Usuario para Basic Auth no proxy |
| `HTTPTunnelPass` | `string` | R/W | Senha para Basic Auth no proxy |
| `HTTPTunnelTimeout` | `Integer` | R/W | Timeout de negociacao CONNECT |
| `OnAfterConnect` | `THookAfterConnect` | R/W | Callback apos conexao TCP bem-sucedida |

### 4.10 Properties de socket (herdadas de TBlockSocket)

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `LastError` | `Integer` | R | Codigo do ultimo erro (Winsock ou SSL) |
| `LastErrorDesc` | `string` | R | Descricao textual |
| `Socket` | `TSocket` | R/W | Descritor nativo |
| `LocalSin` | `TVarSin` | R/W | Endereco local |
| `RemoteSin` | `TVarSin` | R/W | Endereco remoto |
| `LineBuffer` | `AnsiString` | R/W | Buffer interno de `RecvString` |
| `MaxLineLength` | `Integer` | R/W | Tamanho maximo de linha |
| `MaxSendBandwidth` | `Integer` | R/W | bytes/s envio (0 = sem limite) |
| `MaxRecvBandwidth` | `Integer` | R/W | bytes/s recepcao |
| `MaxBandwidth` | `Integer` | W | Setter que aplica a ambos |
| `ConvertLineEnd` | `Boolean` | R/W | Normaliza CRLF |
| `Family` | `TSocketFamily` | R/W | `SF_Any`, `SF_IP4`, `SF_IP6` |
| `PreferIP4` | `Boolean` | R/W | Em `SF_Any`, prefere IPv4 |
| `InterPacketTimeout` | `Boolean` | R/W | Timeout entre pacotes |
| `SendMaxChunk` | `Integer` | R/W | Chunk maximo de envio |
| `StopFlag` | `Boolean` | R/W | Aborta loops de I/O |
| `NonBlockMode` | `Boolean` | R/W | Modo nao-bloqueante |
| `NonblockSendTimeout` | `Integer` | R/W | Timeout adicional em nao-bloqueante |
| `ConnectionTimeout` | `Integer` | R/W | Timeout de handshake/connect |
| `TTL` | `Integer` | R/W | IP TTL |
| `IP6used` | `Boolean` | R | `True` se socket atual e IPv6 |
| `RecvCounter` | `Int64` | R | Total bytes recebidos |
| `SendCounter` | `Int64` | R | Total bytes enviados |
| `Tag` | `Integer` | R/W | Para uso do consumidor |
| `RaiseExcept` | `Boolean` | R/W | `True` levanta `ESynapseError`; `False` usa `LastError` |
| `SizeRecvBuffer` | `Integer` | R/W | `SO_RCVBUF` |
| `SizeSendBuffer` | `Integer` | R/W | `SO_SNDBUF` |
| `FDset` | `TFDSet` | R | `select()` set |
| `WSAData` | `TWSADATA` | R | Dados Winsock |
| `HeartbeatRate` | `Integer` | R/W | ms entre callbacks OnHeartbeat |
| `Owner` | `TObject` | R/W | Classe dona (ex.: `TLDAPSend`) |

### 4.11 Hooks (events)

| Property | Tipo | Descricao |
| --- | --- | --- |
| `OnStatus` | `THookSocketStatus` | Monitoramento de eventos de status (`HR_Connect`, `HR_ReadCount`, etc.) |
| `OnReadFilter` | `THookDataFilter` | Filtra dados recebidos antes de entregar ao consumidor |
| `OnCreateSocket` | `THookCreateSocket` | Chamado apos criacao do socket (para `setsockopt` extras) |
| `OnMonitor` | `THookMonitor` | Notifica leitura/escrita de buffer (debug) |
| `OnHeartbeat` | `THookHeartbeat` | Callback periodico durante I/O longo |
| `OnAfterConnect` | `THookAfterConnect` | Apos `Connect` bem-sucedido |

### 4.12 Extensao CSL (via cast para TSSLOpenSSL)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetPeerCertSHA256Hash` | `function GetPeerCertSHA256Hash: AnsiString` | Retorna hash SHA-256 (32 bytes raw) do certificado do peer — usado em CBT RFC 5929. Acesso: `(Sock.SSL as TSSLOpenSSL).GetPeerCertSHA256Hash` |

---

## 5. Aplicabilidades

1. **Transporte LDAPS para `TLDAPSend`** — `TLDAPSend.Sock` ja e um `TTCPBlockSocket`; configurar `SNIHost`, `CertCAFile`, `VerifyCert` antes de `Login` para LDAPS autenticado.
2. **LDAPS de longa duracao** — fix `WSAECONNRESET` (009.011.001) evita crash quando DC fecha a conexao por inatividade.
3. **LDAP atraves de proxy HTTP corporativo** — `HTTPTunnelIP`/`Port`/`User`/`Pass` permitem tunelamento CONNECT.
4. **CBT RFC 5929** — apos `SSLDoConnect`, extrair `(Sock.SSL as TSSLOpenSSL).GetPeerCertSHA256Hash` e passar a `BindGSSAPIWithCBT`.
5. **Diagnostico TLS** — apos handshake, `SSL.GetSSLVersion`, `SSL.GetCipherName`, `SSL.GetVerifyCert` permitem auditoria.
6. **Multi-protocolo Synapse** — mesma classe transporta HTTP (`httpsend`), SMTP, IMAP, FTP; plugin SSL e trocavel sem alterar o protocolo.

---

## 6. Exemplos de uso

### 6.1 LDAPS autenticado via TLDAPSend.Sock

```pascal
uses SysUtils, ldapsend, blcksock, ssl_openssl3;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL    := True;
    LLDAP.Timeout    := 15000;

    LLDAP.Sock.SNIHost    := 'dc01.empresa.local';
    LLDAP.Sock.CertCAFile := 'certs/empresa-ca.pem';
    LLDAP.Sock.VerifyCert := True;
    LLDAP.Sock.ConnectionTimeout := 5000;

    if not LLDAP.Login then
      raise Exception.Create('LDAPS falhou: ' + string(LLDAP.ResultString));

    Writeln('Cipher: ', LLDAP.Sock.SSL.GetCipherName);
    Writeln('Cert: ', LLDAP.Sock.SSL.GetPeerSubject);
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 Uso directo com plugin SSL explicito

```pascal
uses SysUtils, blcksock, ssl_openssl3;

var
  LSock: TTCPBlockSocket;
begin
  LSock := TTCPBlockSocket.CreateWithSSL(TSSLOpenSSL3);
  try
    LSock.SNIHost    := 'dc01.empresa.local';
    LSock.VerifyCert := True;
    LSock.ConnectionTimeout := 5000;

    LSock.Connect('dc01.empresa.local', '636');
    if LSock.LastError <> 0 then
      raise Exception.Create('TCP: ' + LSock.GetErrorDescEx);

    LSock.SSLDoConnect;
    if LSock.LastError <> 0 then
      raise Exception.Create('TLS: ' + LSock.GetErrorDescEx);

    Writeln('TLS version: ', LSock.SSL.GetSSLVersion);
  finally
    LSock.Free;
  end;
end;
```

### 6.3 LDAPS via proxy HTTP corporativo

```pascal
uses SysUtils, ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL    := True;

    LLDAP.Sock.HTTPTunnelIP      := '10.0.0.1';
    LLDAP.Sock.HTTPTunnelPort    := '3128';
    LLDAP.Sock.HTTPTunnelUser    := 'proxyuser';
    LLDAP.Sock.HTTPTunnelPass    := 'proxypass';
    LLDAP.Sock.HTTPTunnelTimeout := 10000;
    LLDAP.Sock.SNIHost           := 'dc01.empresa.local';
    LLDAP.Sock.VerifyCert        := True;

    if not LLDAP.Login then
      raise Exception.Create('Falha via proxy: ' + string(LLDAP.ResultString));
    LLDAP.Bind;
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TSocksBlockSocket](TSocksBlockSocket.md) | Heranca directa | Adiciona SOCKS4/5 |
| [TBlockSocket](TBlockSocket.md) | Heranca (2 niveis) | I/O, hooks, bandwidth limiting, counters |
| [TCustomSSL](TCustomSSL.md) | Composicao (SSL) | Plugin SSL acessivel via property `SSL` |
| [TSSLNone](TSSLNone.md) | Plugin default | Usado quando nenhum plugin real e activado |
| `TSSLOpenSSL` / `TSSLOpenSSL3` / `TSSLOpenSSL4` | Plugin activo | Via `SSLImplementation` ou `CreateWithSSL` |
| [TSynaOption](TSynaOption.md) | Uso interno | Opcoes de socket delayed |
| [Synsock](Synsock.md) | Dependencia | Camada plataforma-agnostica |
| [TLDAPSend](TLDAPSend.md) | Consumidor principal | `TLDAPSend.Sock: TTCPBlockSocket` |
| `TUDPBlockSocket` | Cria TCP auxiliar | Para controle SOCKS5 |
| `ESynapseError` | Excecao | Levantada quando `RaiseExcept = True` |
| `THookSocketStatus`, `THookAfterConnect`, `THookMonitor`, `THookHeartbeat`, `THookVerifyCert`, `THookCreateSocket`, `THookDataFilter` | Procedural types | Eventos disponiveis |
