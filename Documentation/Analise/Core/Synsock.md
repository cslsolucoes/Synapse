# Synsock / synsock.pas

**Unit:** `synsock.pas` | **Versao:** 005.002.004 | **Tipo:** Unit plataforma-agnostica (includes condicionais) | **Origem:** Upstream Synapse

---

## 1. O que e?

`synsock` e a unit mais baixa da pilha de rede da Ararat Synapse: e uma **camada de abstracao plataforma-agnostica** que encapsula diferencas entre os sistemas operacionais suportados. A unit em si nao contem codigo — apenas seleciona, via diretivas condicionais, um dos arquivos `.inc` que implementa o bridge para a API nativa de sockets do SO alvo.

A logica de selecao e:

- `CIL` (.NET) -> `ssdotnet.inc`
- `MSWINDOWS` / `WIN32` -> `sswin32.inc` (Winsock 2)
- `WINCE` -> `sswin32.inc` (incompleto)
- `FPC` + `OS2` -> `ssos2ws1.inc`
- `FPC` (Linux/BSD/macOS) -> `ssfpc.inc`
- `POSIX` (Delphi mobile / LINUX64) -> `ssposix.inc`
- Linux nativo Delphi -> `sslinux.inc`

Cada `.inc` exporta um conjunto consistente de tipos (`TSocket`, `TVarSin`, `sockaddr_in`, `sockaddr_in6`, `TFDSet`, `TWSAData`), funcoes de conversao de endianess (`htons`, `ntohs`, `htonl`, `ntohl`), primitivas de socket (`socket`, `connect`, `bind`, `listen`, `accept`, `send`, `recv`, `select`, `closesocket`, `setsockopt`, `getsockopt`, `gethostbyname`, `getaddrinfo`, `inet_addr`, `inet_ntoa`) e constantes (`AF_*`, `SOCK_*`, `IPPROTO_*`, `SO_*`, `IPPROTO_TCP`, `INVALID_SOCKET`, `SOCKET_ERROR`).

A classe `TBlockSocket` e toda a hierarquia Synapse compilam contra a API publica do `synsock` — assim o mesmo codigo de alto nivel roda em Windows, Linux, macOS e BSD sem modificacao.

---

## 2. Caracteristicas

* Plataforma-agnostica 100% via `.inc` condicionais.
* Exporta API identica a POSIX (padrao BSD sockets) em todos os SOs.
* Mapeamento transparente Winsock <-> POSIX sockets.
* Inclui binding para SSPI/secur32.dll em Windows (usado indirectamente por `ldapsend` V1.7.0 fork CSL).
* Nao tem classes proprias — e `include`-only.
* `{$MINENUMSIZE 4}` garante tamanho consistente de enums (4 bytes).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$MINENUMSIZE 4}` | Enums = 4 bytes (compatibilidade com structs C) |
| `{$IFDEF CIL}` -> `ssdotnet.inc` | .NET — usa `System.Net.Sockets` via interop |
| `{$IFDEF MSWINDOWS}` -> `sswin32.inc` | Winsock 2 (`ws2_32.dll`) |
| `{$IFDEF WINCE}` -> `sswin32.inc` | Windows CE (incompleto) |
| `{$IFDEF FPC} + {$IFDEF OS2}` -> `ssos2ws1.inc` | OS/2 via FPC |
| `{$IFDEF FPC}` -> `ssfpc.inc` | FPC em Linux/BSD/macOS — libc sockets |
| `{$IFDEF POSIX}` -> `ssposix.inc` | Delphi LINUX64/macOS64 — RTL POSIX units |
| `{$ELSE}` -> `sslinux.inc` | Delphi Linux nativo (legacy) |

---

## 4. Funcionalidades

### 4.1 Tipos publicos (comum a todos os includes)

| Tipo | Descricao |
| --- | --- |
| `TSocket` | Descritor de socket nativo (HANDLE em Windows, int em POSIX) |
| `u_int` | `Cardinal` (32-bit unsigned) |
| `u_short` | `Word` (16-bit unsigned) |
| `in_addr` | Endereco IPv4 (32 bits em network byte order) |
| `in6_addr` | Endereco IPv6 (128 bits) |
| `sockaddr_in` | Estrutura de endereco IPv4 (`sin_family`, `sin_port`, `sin_addr`) |
| `sockaddr_in6` | Estrutura de endereco IPv6 |
| `TVarSin` | Uniao/variante que suporta sockaddr_in + sockaddr_in6 com discriminador |
| `TFDSet` | Conjunto de descritores para `select()` |
| `TWSAData` | Dados de inicializacao Winsock (vazio em POSIX) |
| `TAddrFamily` | `Integer` representando `AF_*` |

### 4.2 Funcoes de byte order

| Funcao | Descricao |
| --- | --- |
| `htons(u: u_short): u_short` | Host-to-network short (16-bit) |
| `ntohs(u: u_short): u_short` | Network-to-host short |
| `htonl(u: u_int): u_int` | Host-to-network long (32-bit) |
| `ntohl(u: u_int): u_int` | Network-to-host long |

### 4.3 Funcoes BSD socket (wrappers)

| Funcao | Descricao |
| --- | --- |
| `socket(family, socktype, protocol): TSocket` | Cria socket |
| `connect(s, @addr, addrlen): Integer` | Conecta |
| `bind(s, @addr, addrlen): Integer` | Bind local |
| `listen(s, backlog): Integer` | Modo escuta |
| `accept(s, @addr, @addrlen): TSocket` | Aceita conexao |
| `send(s, buf, len, flags): Integer` | Envia |
| `recv(s, buf, len, flags): Integer` | Recebe |
| `sendto` / `recvfrom` | Datagrama com endereco |
| `select(nfds, readfds, writefds, exceptfds, timeout): Integer` | Multiplex |
| `closesocket(s): Integer` | Fecha |
| `setsockopt(s, level, optname, optval, optlen): Integer` | `SO_*` |
| `getsockopt(s, level, optname, optval, optlen): Integer` | Le opcao |
| `getsockname` / `getpeername` | Info local/remota |
| `gethostbyname(name): PHostEnt` | DNS legacy |
| `getaddrinfo(nodename, servname, hints, res): Integer` | DNS IPv6-aware |

### 4.4 Inicializacao da camada

| Funcao | Descricao |
| --- | --- |
| `InitSocketInterface(stack: string): Boolean` | Carrega biblioteca de socket (Winsock ou libc) |
| `DestroySocketInterface: Boolean` | Descarrega biblioteca (Winsock `WSACleanup`) |
| `SockCheck(SockResult: Integer): Integer` | Normaliza codigos de erro cross-platform |

### 4.5 Constantes principais

| Constante | Descricao |
| --- | --- |
| `INVALID_SOCKET` | Valor sentinela para socket invalido |
| `SOCKET_ERROR` | Retorno de erro de primitivas socket |
| `AF_INET` | IPv4 |
| `AF_INET6` | IPv6 |
| `AF_UNSPEC` | Qualquer familia |
| `SOCK_STREAM` | TCP |
| `SOCK_DGRAM` | UDP |
| `SOCK_RAW` | RAW (ICMP, custom) |
| `SOCK_RDM` | Reliable Datagram (PGM) |
| `IPPROTO_TCP` | Protocolo TCP |
| `IPPROTO_UDP` | Protocolo UDP |
| `IPPROTO_ICMP` / `IPPROTO_ICMPV6` | ICMP |
| `IPPROTO_RAW` | Raw IP |
| `IPPROTO_RM` | Reliable Multicast (PGM) |
| `SOL_SOCKET` | Nivel socket para `setsockopt` |
| `SO_REUSEADDR` / `SO_LINGER` / `SO_RCVBUF` / `SO_SNDBUF` / `SO_BROADCAST` / `SO_RCVTIMEO` / `SO_SNDTIMEO` | Opcoes |
| `IP_TTL` / `IP_MULTICAST_TTL` / `IP_MULTICAST_LOOP` / `IP_ADD_MEMBERSHIP` / `IP_DROP_MEMBERSHIP` | Opcoes IP |
| `WSAECONNRESET` | Erro Windows comum em conexoes long-lived (tratado pela CSL fork) |

---

## 5. Aplicabilidades

1. **Compilacao cross-platform** — mesma unit `TTCPBlockSocket` compila em Windows, Linux, macOS, FreeBSD.
2. **Portabilidade garantida** — a camada isola o consumidor de diferencas Winsock/POSIX.
3. **Novas plataformas** — adicionar suporte a um SO novo requer apenas escrever novo `.inc`.
4. **Diagnostico** — codigos de erro normalizados (Winsock->POSIX equivalentes) via `SockCheck`.
5. **Upgrade de stack** — trocar Winsock 1 -> 2 via outro `.inc` sem recompilar resto.

---

## 6. Exemplos de uso

### 6.1 Inicializar camada manualmente (normalmente nao e necessario — feito automatico)

```pascal
uses synsock;

begin
  if InitSocketInterface('') then
    Writeln('Synsock carregada')
  else
    Writeln('Falha ao carregar camada socket');
  try
    // ... uso de sockets
  finally
    DestroySocketInterface;
  end;
end.
```

### 6.2 Checar codigo de erro normalizado

```pascal
uses synsock, SysUtils, blcksock;

var
  LSock: TTCPBlockSocket;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.Connect('dc-invalido.local', '389');
    if LSock.LastError = WSAECONNREFUSED then
      Writeln('Porta fechada')
    else if LSock.LastError = WSAETIMEDOUT then
      Writeln('Timeout');
  finally
    LSock.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TBlockSocket](TBlockSocket.md) | Consumidor principal | Toda a hierarquia depende |
| [TTCPBlockSocket](TTCPBlockSocket.md) | Consumidor | Via `TBlockSocket` |
| `sswin32.inc` | Include Windows | Winsock 2 via `ws2_32.dll` |
| `ssfpc.inc` | Include FPC POSIX | libc sockets |
| `ssposix.inc` | Include Delphi POSIX | RTL POSIX.* units |
| `sslinux.inc` | Include Delphi Linux legacy | Linux syscalls |
| `ssos2ws1.inc` | Include OS/2 | OS/2 Warp sockets |
| `ssdotnet.inc` | Include .NET CIL | `System.Net.Sockets` interop |
| [TLDAPSend](TLDAPSend.md) | Consumidor final | Via `TTCPBlockSocket.Sock` |
