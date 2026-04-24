# TDNSSend

**Unit:** `dnssend.pas` | **Versao:** 002.007.006 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TDNSSend` e o cliente DNS do Synapse (RFC-1035, RFC-1183, RFC-1706, RFC-1712, RFC-2163, RFC-2230). Suporta consultas UDP (default) e TCP (`UseTCP=True`, necessario para zone transfers AXFR e para respostas truncadas).

Envia queries para qualquer tipo de recurso (A, AAAA, NS, MX, TXT, SRV, PTR, CNAME, SOA, etc.), faz compressao de nomes na request e decodificacao/descompressao na resposta. Tambem suporta reverse lookup automatico: se `Name` for IPv4, e convertido para `X.X.X.X.in-addr.arpa` e consultado PTR.

Resultados vem em tres stringlists: `AnswerInfo` (seccao ANSWER), `NameserverInfo` (seccao AUTHORITY) e `AdditionalInfo` (seccao ADDITIONAL). O parametro de saida `Reply: TStrings` recebe os valores "humanos" (sem TTL nem record type). Records multi-valor (ex: MX) vem como CSV (`preference,host`).

## 2. Caracteristicas

- UDP (default) e TCP (`UseTCP=True`, obrigatorio para AXFR)
- Auto-convert de reverse IPv4 a PTR (`X.Y.Z.W` -> `W.Z.Y.X.in-addr.arpa`)
- Todos os QTYPE comuns + alguns avancados (AFSDB, X25, ISDN, RT, NSAP, KX, SPF, NAPTR, LOC, SIG, KEY, NXT)
- Suporte QTYPE_AXFR (zone transfer) sobre TCP
- Parse de flags DNS (`RCode`, `Authoritative`, `Truncated`)
- Helper global `GetMailServers` (combina MX queries + sort por preferencia)

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta DNS | `cDnsProtocol = '53'` |
| Transporte | UDP default, TCP opcional |
| Herda de | `TSynaClient` |
| RCode | 0=OK, 1=FormatErr, 2=ServerFail, 3=NXDomain, 4=NotImplemented, 5=Refused |

### 3.1 QTYPE constants (tabela extraida do source)

| Const | Valor | Tipo |
| --- | --- | --- |
| `QTYPE_A` | 1 | IPv4 |
| `QTYPE_NS` | 2 | Name Server |
| `QTYPE_CNAME` | 5 | Canonical alias |
| `QTYPE_SOA` | 6 | Start Of Authority |
| `QTYPE_PTR` | 12 | Reverse pointer |
| `QTYPE_HINFO` | 13 | Host info |
| `QTYPE_MX` | 15 | Mail Exchange |
| `QTYPE_TXT` | 16 | Text |
| `QTYPE_AAAA` | 28 | IPv6 |
| `QTYPE_SRV` | 33 | Service locator |
| `QTYPE_NAPTR` | 35 | Naming authority pointer (RFC-2168) |
| `QTYPE_SPF` | 99 | SPF record |
| `QTYPE_AXFR` | 252 | Zone transfer (TCP only) |
| `QTYPE_ALL` | 255 | ANY |

## 4. Funcionalidades

### 4.1 Construtor

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Aloca `TUDPBlockSocket` + `TTCPBlockSocket` + stringlists de info. |
| Destroy | `destructor Destroy; override;` | Liberta recursos. |

### 4.2 Query

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| DNSQuery | `function DNSQuery(Name: AnsiString; QType: Integer; const Reply: TStrings): Boolean;` | Consulta DNS. Se `Name` e IPv4 e `QType=QTYPE_PTR`, faz conversao automatica a `.in-addr.arpa`. |

### 4.3 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Sock | `property TUDPBlockSocket;` | Socket UDP. |
| TCPSock | `property TTCPBlockSocket;` | Socket TCP (zone transfer). |
| UseTCP | `property Boolean;` | Liga modo TCP. |
| RCode | `property Integer;` | Codigo de resposta DNS (0..5). |
| Authoritative | `property Boolean;` | Flag AA. |
| Truncated | `property Boolean;` | Flag TC. |
| AnswerInfo | `property TStringList;` | Seccao ANSWER com detalhes (tipo,TTL,valor). |
| NameserverInfo | `property TStringList;` | Seccao AUTHORITY. |
| AdditionalInfo | `property TStringList;` | Seccao ADDITIONAL. |

### 4.4 Funcoes globais

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| GetMailServers | `function GetMailServers(const DNSHost, Domain: AnsiString; const Servers: TStrings): Boolean;` | Combina MX query + sort por preferencia; retorna so hostnames. |

## 5. Aplicabilidades

1. **Resolver de mail gateway** -- `GetMailServers` para obter lista de MX ordenada.
2. **Debug de configuracao DNS** -- verificar multiplas zonas/records.
3. **Monitoring de propagacao** -- query a multiplos resolvers e comparar.
4. **Service discovery** -- SRV records para locais de LDAP/Kerberos/XMPP.
5. **Zone transfer backup** -- AXFR com `UseTCP=True` para dump zonal.
6. **Reverse DNS** -- transformar IP em hostname via PTR.

## 6. Exemplos de uso

### 6.1 Query A record

```pascal
uses
  SysUtils, Classes, dnssend;

var
  LDns: TDNSSend;
  LResult: TStringList;
  I: Integer;
begin
  LDns := TDNSSend.Create;
  LResult := TStringList.Create;
  try
    LDns.TargetHost := '8.8.8.8';
    if LDns.DNSQuery('example.com', QTYPE_A, LResult) then
      for I := 0 to LResult.Count - 1 do
        Writeln('A: ', LResult[I]);
  finally
    LResult.Free;
    LDns.Free;
  end;
end.
```

### 6.2 MX records ordenados

```pascal
uses
  SysUtils, Classes, dnssend;

var
  LServers: TStringList;
  I: Integer;
begin
  LServers := TStringList.Create;
  try
    if GetMailServers('8.8.8.8', 'example.com', LServers) then
      for I := 0 to LServers.Count - 1 do
        Writeln(Format('%d. %s', [I + 1, LServers[I]]));
  finally
    LServers.Free;
  end;
end.
```

### 6.3 Zone transfer AXFR

```pascal
uses
  SysUtils, Classes, dnssend;

var
  LDns: TDNSSend;
  LZone: TStringList;
  I: Integer;
begin
  LDns := TDNSSend.Create;
  LZone := TStringList.Create;
  try
    LDns.TargetHost := 'ns1.example.com';
    LDns.UseTCP := True;
    if LDns.DNSQuery('example.com', QTYPE_AXFR, LZone) then
    begin
      Writeln('Zone transfer OK (', LZone.Count, ' records)');
      for I := 0 to LDns.AnswerInfo.Count - 1 do
        Writeln(LDns.AnswerInfo[I]);
    end
    else
      Writeln('AXFR recusado ou servidor offline. RCode=', LDns.RCode);
  finally
    LZone.Free;
    LDns.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/timeout. |
| `TUDPBlockSocket` | Composicao | Transporte UDP. |
| `TTCPBlockSocket` | Composicao | Transporte TCP (AXFR). |
| `synaip` | Dependencia | Parse IPv4/IPv6 + deteccao. |
| `synautil` | Dependencia | Helpers binarios. |
