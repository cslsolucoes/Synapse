# SynaMisc

**Unit:** `synamisc.pas` | **Versao:** 001.004.000 | **Tipo:** Unit | **Origem:** Upstream

---

## 1. O que e?

A `synamisc` e a unit de utilitarios de rede "grab-bag" do pacote Ararat Synapse. Agrupa funcionalidades que nao se enquadram em nenhum cliente de protocolo especifico mas que sao comuns em aplicacoes de rede: (1) Wake-on-LAN (envio de "magic packet" UDP); (2) descoberta de DNS servers configurados no SO (via `iphlpapi.dll` -> `GetNetworkParams` em Windows, ou `/etc/resolv.conf` em Unix); (3) leitura de proxy do Internet Explorer 5+ via `wininet.dll -> InternetQueryOption`; (4) auto-deteccao de proxy para URL especifica via `winhttp.dll -> WinHttpGetProxyForUrl` (inclui WPAD/PAC); (5) listagem de IPs locais (IPv4/IPv6 via `GetLocalIPsFamily`); (6) record `TProxySetting` como resultado comum. E uma unit especialmente **Windows-centrica** — algumas funcoes (`GetIEProxy`, `GetProxyForURL`) retornam resultado vazio em POSIX.

## 2. Caracteristicas

- Usa carga dinamica de DLLs (`iphlpapi.dll`, `wininet.dll`, `winhttp.dll`) em vez de static link — se a DLL nao existe, retorna silenciosamente resultado vazio.
- `GetDNS` em Unix le directamente `/etc/resolv.conf` (linhas iniciadas por `NAMESERVER`).
- Wake-on-LAN envia 6 bytes `FF` seguidos de 16 repeticoes do MAC (padrao AMD).
- `TProxySetting` e um record simples com `Host`, `Port`, `Bypass`, `ResultCode`, `Autodetected`.
- `GetLocalIPs` usa `TTCPBlockSocket.ResolveNameToIP(LocalName)` — retorna CommaText de todos os IPs do host local.
- A unit depende de `blcksock` para UDP (Wake-on-LAN) e resolucao.

## 3. Engine

Multi-engine conforme a funcao:

- **Wake-on-LAN:** `TUDPBlockSocket` com `EnableBroadcast(true)`, porta destino 9 (discard), `cBroadcast` se IP vazio.
- **GetDNS Windows:** carga dinamica de `IPHLPAPI.DLL`, chamada a `GetNetworkParams(TFixedInfo*)` para obter `DnsServerList` (linked list).
- **GetDNS Windows legacy:** fallback via registry `HKLM\System\CurrentControlSet\Services\Tcpip\Parameters\NameServer` e `DhcpNameServer`.
- **GetIEProxy:** `WININET.DLL -> InternetQueryOptionA` com `INTERNET_OPTION_PER_CONNECTION_OPTION`.
- **GetProxyForURL:** `WINHTTP.DLL -> WinHttpGetIEProxyConfigForCurrentUser` + `WinHttpGetProxyForUrl` (auto-deteccao PAC via DHCP/DNS-A).

## 4. Funcionalidades

### 4.1 Record publico

| Nome | Definicao |
| --- | --- |
| `TProxySetting` | `record Host, Port, Bypass: string; ResultCode: integer; Autodetected: Boolean end` |

### 4.2 Rede

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `WakeOnLan` | `procedure WakeOnLan(MAC, IP: string);` | Envia magic packet WOL via UDP:9. `MAC` pode ter `-` ou `:` como separador. `IP` vazio -> broadcast. |
| `GetDNS` | `function GetDNS: string;` | DNS servers comma-delimited. Windows: `iphlpapi.dll` + registry fallback. Unix: parsing de `/etc/resolv.conf`. |
| `GetLocalIPsFamily` | `function GetLocalIPsFamily(value: TSocketFamily): string;` | Lista IPs locais por familia (SF_Any / SF_IP4 / SF_IP6). |
| `GetLocalIPs` | `function GetLocalIPs: string;` | Shortcut: `GetLocalIPsFamily(SF_Any)`. |

### 4.3 Proxy (Windows only)

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetIEProxy` | `function GetIEProxy(protocol: string): TProxySetting;` | Le config de IE 5+ via `wininet.InternetQueryOptionA`. Retorna `Host`, `Port`, `Bypass`. |
| `GetProxyForURL` | `function GetProxyForURL(const AURL: WideString): TProxySetting;` | `{$IFDEF MSWINDOWS}` — usa WinHTTP + PAC + auto-discovery WPAD. |

## 5. Aplicabilidades

- **Wake-on-LAN / remote administration:** acordar servidores/desktops remotamente antes de operacoes agendadas.
- **Descoberta DNS dinamica:** determinar DNS server do SO antes de fazer query via `dnssend`.
- **HTTP client behind proxy:** `GetIEProxy('http')` + `GetProxyForURL('https://api.example.com')` configura transparentemente `THTTPSend`.
- **Listagem de interfaces locais:** escolher qual IP usar para multi-homed hosts antes de `Bind` em `TTCPBlockSocket`.
- **LDAP no AD:** raramente precisa de `GetIEProxy` (LDAP e TCP directo), mas `GetDNS` pode ajudar a descobrir os DCs via SRV records `_ldap._tcp.domain`.
- **Wake-up pre-login:** acordar `dc01` antes de tentar ligar.

## 6. Exemplos de uso

```pascal
uses
  SysUtils, synamisc;
var
  proxy: TProxySetting;
begin
  // Ler proxy do IE para protocolo http
  proxy := GetIEProxy('http');
  if proxy.Host <> '' then
    Writeln(Format('Proxy: %s:%s (bypass=%s)',
      [proxy.Host, proxy.Port, proxy.Bypass]))
  else
    Writeln('Sem proxy configurado no IE');
end;
```

```pascal
uses
  SysUtils, synamisc;
var
  dns, ips: string;
begin
  // Descobrir DNS e IPs locais antes de ligacao
  dns := GetDNS;
  ips := GetLocalIPs;
  Writeln('DNS servers  : ', dns);
  Writeln('Local IPs    : ', ips);

  // Desperta um DC remoto antes de ligar (WOL)
  WakeOnLan('00-1A-2B-3C-4D-5E', '192.168.100.255');
  Writeln('Magic packet enviado, aguardando 5s...');
  Sleep(5000);
end;
```

```pascal
uses
  SysUtils, synamisc;
var
  proxy: TProxySetting;
begin
{$IFDEF MSWINDOWS}
  // Auto-discovery via WPAD para URL especifica
  proxy := GetProxyForURL('https://dc01.empresa.local:636/');
  if proxy.Autodetected then
    Writeln(Format('Auto: %s:%s', [proxy.Host, proxy.Port]))
  else
    Writeln('Sem auto-proxy; ResultCode = ', proxy.ResultCode);
{$ENDIF}
end;
```

## 7. Relacionamentos

- **Consumida por:** aplicacoes de alto nivel (nao por clientes Synapse directos). E opcional.
- **Depende de:** `synautil`, `blcksock`, `SysUtils`, `Classes`, `Windows` (MSWINDOWS) ou `Libc`/`Posix.Stdlib` (POSIX).
- **Bibliotecas externas (dinamicas, Windows):**
  - `IPHLPAPI.DLL` -> `GetNetworkParams`.
  - `WININET.DLL` -> `InternetQueryOptionA`.
  - `WINHTTP.DLL` -> `WinHttpOpen`, `WinHttpGetIEProxyConfigForCurrentUser`, `WinHttpGetProxyForUrl`.
- **Unix:** `GetDNS` le `/etc/resolv.conf` directamente; outras funcoes retornam vazio.
- **Fork CSL:** sem modificacoes.
