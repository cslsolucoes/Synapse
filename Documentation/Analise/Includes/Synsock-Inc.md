# ss*.inc (socket platform layer)

**Ficheiros:** `sswin32.inc`, `ssfpc.inc`, `ssposix.inc`, `sslinux.inc`, `ssos2ws1.inc`, `ssdotnet.inc` | **Versoes:** 002.003.001 (sswin32), 001.001.008 (ssfpc) | **Tipo:** Include files | **Origem:** Upstream Synapse

---

## 1. O que e?

Os ficheiros `ss*.inc` formam a **camada de abstraccao de sockets por plataforma** do Synapse. Cada include fornece a implementacao concreta dos tipos (`TSocket`, `u_int`, `sockaddr_in`), constantes (`AF_*`, `SOCK_*`, `IPPROTO_*`, `INVALID_SOCKET`) e funcoes (`connect`, `accept`, `send`, `recv`, `bind`, `listen`) para uma API de socket especifica:

- **Windows nativo** -- `sswin32.inc` usa Winsock (`ws2_32.dll`).
- **FPC POSIX** -- `ssfpc.inc` usa sockets POSIX via FPC (Linux, macOS, FreeBSD).
- **Delphi POSIX (LINUX64/macOS64)** -- `ssposix.inc` usa sockets POSIX via RTL `Posix.SysSocket`.
- **Delphi Linux legacy** -- `sslinux.inc` (predecessor do `ssposix.inc`).
- **OS/2** -- `ssos2ws1.inc` (legacy).
- **.NET** -- `ssdotnet.inc` (Delphi .NET, raramente usado).

A selecao ocorre em `synsock.pas` via `{$IFDEF MSWINDOWS}` -> `ss*.inc` correspondente, escondendo toda a variacao por tras de uma API uniforme.

---

## 2. Caracteristicas

- **Separacao fisica de plataforma** -- cada include e um ficheiro independente, nao partilha codigo com os outros.
- **Contrato uniforme** -- todos expoem **o mesmo conjunto** de simbolos (types, constants, function pointers), o que permite que `blcksock.pas` use `TSocket` sem `{$IFDEF}` em cada chamada.
- **Carregamento dinamico em Windows** -- `sswin32.inc` usa `LoadLibrary('ws2_32.dll')` + `GetProcAddress` para algumas funcoes novas (IPv6). Permite fallback gracioso em Windows 2000/XP SP antigo sem IPv6.
- **Estatico em POSIX** -- `ssfpc.inc` e `ssposix.inc` fazem link directo com `libc` (ja ligada ao binario); nao ha `LoadLibrary` em runtime.
- **Sem dependencias externas alem da libc / ws2_32** -- zero dependencias de terceiros.
- **IPv4 + IPv6** -- todos os 3 principais (`sswin32`, `ssfpc`, `ssposix`) suportam IPv6 via `TVarSin` que abstrai `sockaddr_in` vs `sockaddr_in6`.

---

## 3. Engine

| Directiva em `synsock.pas` | Include activado |
|---|---|
| `{$IFDEF MSWINDOWS}` | `sswin32.inc` (Winsock 2.2) |
| `{$IFDEF FPC}` (e nao Windows) | `ssfpc.inc` (POSIX sockets via FPC) |
| `{$IFDEF POSIX}` (Delphi LINUX64/macOS64) | `ssposix.inc` (POSIX Delphi) |
| `{$IFDEF LINUX}` (Delphi Linux legacy) | `sslinux.inc` |
| `{$IFDEF OS2}` | `ssos2ws1.inc` |
| `{$IFDEF CIL}` | `ssdotnet.inc` (Delphi .NET) |

**Defines internos de cada include** (exemplos):

| Define em `sswin32.inc` | Efeito |
|---|---|
| `WINSOCK1` | Forca uso de Winsock 1.1 (legacy, so em Win95 sem update) |
| `FORCEOLDAPI` | Usa `gethostbyname` em vez de `getaddrinfo` (sem IPv6) |

| Define em `ssfpc.inc` | Efeito |
|---|---|
| `NoUnixsockets` | Desactiva `unix://` sockets (AF_UNIX) |

---

## 4. Funcionalidades

### 4.1 Simbolos comuns a todos os includes

| Simbolo | Tipo | Descricao |
|---|---|---|
| `TSocket` | Tipo escalar | Handle de socket (integer em Windows, integer em POSIX) |
| `TVarSin` | Record | Estrutura unificada de `sockaddr_in` + `sockaddr_in6` |
| `INVALID_SOCKET` | Constante | Valor invalido de socket (`-1` em POSIX, `$FFFFFFFF` em Windows) |
| `SOCKET_ERROR` | Constante | Retorno de erro de funcoes de socket (`-1`) |
| `AF_INET` | Constante | Address Family IPv4 |
| `AF_INET6` | Constante | Address Family IPv6 |
| `AF_UNIX` | Constante | Address Family Unix domain socket (POSIX only) |
| `SOCK_STREAM` | Constante | TCP |
| `SOCK_DGRAM` | Constante | UDP |
| `SOCK_RAW` | Constante | ICMP, RAW sockets |
| `IPPROTO_TCP` / `IPPROTO_UDP` / `IPPROTO_ICMP` | Constante | Protocolos |

### 4.2 Funcoes Socket basicas (API uniforme)

| Funcao | Uniforme em | Descricao |
|---|---|---|
| `socket(af, typ, proto): TSocket` | Win/FPC/POSIX | Cria socket |
| `connect(s, addr, len): Integer` | All | Estabelece conexao (cliente) |
| `accept(s, addr, addrlen): TSocket` | All | Aceita conexao (servidor) |
| `bind(s, addr, addrlen): Integer` | All | Liga socket a endereco local |
| `listen(s, backlog): Integer` | All | Coloca em modo escuta |
| `send(s, buf, len, flags): Integer` | All | Envia dados |
| `recv(s, buf, len, flags): Integer` | All | Recebe dados |
| `sendto(s, buf, len, flags, to, tolen): Integer` | All | Envia UDP/ICMP |
| `recvfrom(s, buf, len, flags, from, fromlen): Integer` | All | Recebe UDP/ICMP |
| `shutdown(s, how): Integer` | All | Fecha metade do canal (SEND/RECV/BOTH) |
| `closesocket(s): Integer` | Win | Fecha socket (em POSIX e `close`) |
| `close(s): Integer` | POSIX | Fecha socket |
| `select(n, readfds, writefds, exceptfds, timeout): Integer` | All | Poll de sockets |
| `getsockname(s, name, namelen): Integer` | All | Obtem endereco local |
| `getpeername(s, name, namelen): Integer` | All | Obtem endereco remoto |
| `setsockopt(s, level, optname, optval, optlen): Integer` | All | Seta opcao de socket |
| `getsockopt(s, level, optname, optval, optlen): Integer` | All | Le opcao de socket |

### 4.3 Name resolution

| Funcao | Descricao |
|---|---|
| `getaddrinfo(node, service, hints, res): Integer` | Resolucao DNS moderna (IPv4+IPv6) -- preferida |
| `freeaddrinfo(ai)` | Liberta lista de `getaddrinfo` |
| `gethostbyname(name): PHostEnt` | Resolucao legacy (IPv4 only); usada com `FORCEOLDAPI` |
| `gethostbyaddr(addr, len, typ): PHostEnt` | Reverse DNS legacy |

### 4.4 Helpers de conversao (network byte order)

| Funcao | Descricao |
|---|---|
| `htons(x): Word` | Host to network short (16-bit) |
| `ntohs(x): Word` | Network to host short |
| `htonl(x): Cardinal` | Host to network long (32-bit) |
| `ntohl(x): Cardinal` | Network to host long |

### 4.5 Inicializacao (Windows only)

| Funcao | Unico em | Descricao |
|---|---|---|
| `WSAStartup(version, lpData): Integer` | `sswin32.inc` | Inicializa Winsock |
| `WSACleanup: Integer` | `sswin32.inc` | Termina Winsock |

Em POSIX esta API nao existe -- a libc sockets esta sempre disponivel.

### 4.6 SSL kernel hooks (TLS-in-kernel, Linux 4.13+)

`ssfpc.inc` e `ssposix.inc` podem incluir defines para Kernel TLS (`SOL_TLS`, `TLS_TX`, `TLS_RX`) se disponiveis -- optimizacao onde o kernel faz encrypt/decrypt.

---

## 5. Aplicabilidades

1. **Portabilidade total sem recompilar `blcksock.pas`** -- `blcksock` importa `synsock` e ganha automaticamente a implementacao correcta para cada plataforma.
2. **Suporte a IPv6 transparente** -- `TVarSin` esconde se e IPv4 ou IPv6; caller usa APIs uniformes.
3. **Compatibilidade com sistemas antigos** -- `FORCEOLDAPI` permite compilar para Windows 2000 usando API IPv4-only.
4. **Evolucao independente** -- quando Synapse actualiza suporte a sockets no Linux 6.x com `io_uring`, so `ssfpc.inc` e `ssposix.inc` precisam mudar -- resto do package intocado.
5. **Stubs em plataformas sem SO real** -- `ssdotnet.inc` para Delphi .NET permite compilar (mesmo se perfomance inferior ao nativo).

---

## 6. Exemplos de uso

### 6.1 `synsock.pas` (ponto de inclusao)

```pascal
unit synsock;

{$I jedi.inc}

interface

{$IFDEF MSWINDOWS}
  {$I sswin32.inc}
{$ELSE}
  {$IFDEF FPC}
    {$I ssfpc.inc}
  {$ELSE}
    {$IFDEF POSIX}
      {$I ssposix.inc}
    {$ELSE}
      {$IFDEF LINUX}
        {$I sslinux.inc}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

implementation
end.
```

### 6.2 Uso directo em `blcksock.pas` (sem condicionais)

```pascal
uses synsock;

procedure TTCPBlockSocket.Connect(IP, Port: string);
var
  Sin: TVarSin;
begin
  FSocket := synsock.Socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if FSocket = INVALID_SOCKET then
    raise ESynapseError.Create('socket failed');
  SetVarSin(Sin, IP, Port, SOCK_STREAM, IPPROTO_TCP, AF_UNSPEC);
  if synsock.Connect(FSocket, @Sin.AddrIn, SizeOfVarSin(Sin)) = SOCKET_ERROR then
    raise ESynapseError.Create('connect failed');
end;
```

### 6.3 IPv6 transparente via `TVarSin`

```pascal
var
  Sin: TVarSin;
begin
  // Works for both IPv4 and IPv6 endpoints
  SetVarSin(Sin, '2001:db8::1', '636', SOCK_STREAM, IPPROTO_TCP, AF_INET6);
  // or:
  SetVarSin(Sin, '10.0.0.1', '636', SOCK_STREAM, IPPROTO_TCP, AF_INET);
  // synsock.Connect aceita qualquer um
end;
```

---

## 7. Relacionamentos

| Unit / Include | Tipo de relacao | Descricao |
|---|---|---|
| `synsock.pas` | Consumidor directo | Inclui `{$I ss*.inc}` conforme `{$IFDEF}` |
| `blcksock.pas` | Consumidor indirecto | `uses synsock` -- obtem `TSocket`, `TVarSin`, funcoes socket |
| `synaip.pas` | Consumidor | Usa `TVarSin` para parsing IPv4/IPv6 |
| `ldapsend.pas` | Consumidor (via blcksock) | Transporte TCP via `blcksock` (que usa `synsock`) |
| `httpsend.pas` | Consumidor idem | |
| `ws2_32.dll` / Winsock | Dependencia Win | `sswin32.inc` importa desta DLL |
| `libc` (Linux/macOS/BSD) | Dependencia POSIX | `ssfpc.inc`/`ssposix.inc` importam |
| `Posix.SysSocket` (RTL) | Dependencia Delphi POSIX | `ssposix.inc` re-exporta |

---

**Gerado:** 2026-04-21 (CSL reverse-engineering V2)
