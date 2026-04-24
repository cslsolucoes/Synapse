# TDgramBlockSocket / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe base de UDP/ICMP/RAW | **Origem:** Upstream Synapse

---

## 1. O que e?

`TDgramBlockSocket` e a classe intermediaria para comunicacao baseada em datagramas (nao orientada a conexao). Herda de `TSocksBlockSocket` e e herdada por `TUDPBlockSocket`, `TICMPBlockSocket` e `TRAWBlockSocket`. A principal diferenca em relacao a `TTCPBlockSocket` e que `SendBuffer` e `RecvBuffer` sao redirecionados internamente para `SendBufferTo`/`RecvBufferFrom` — refletindo o modelo datagrama onde cada pacote carrega seu proprio endereco de destino/origem.

`Connect` nesta classe nao faz handshake TCP: apenas preenche `RemoteSin` com o endereco de destino que sera usado por `SendBuffer`. E util para UDP "conectado" (associacao unilateral sem handshake).

`TDgramBlockSocket` raramente e relevante no contexto ActiveDirectoryORM porque LDAP e TCP-orientado. E documentada aqui por completude da hierarquia.

---

## 2. Caracteristicas

* Classe intermediaria para datagramas.
* `Connect` sem handshake (apenas associa `RemoteSin`).
* `SendBuffer`/`RecvBuffer` redirecionam para `SendBufferTo`/`RecvBufferFrom`.
* Herda SOCKS5 de `TSocksBlockSocket` (SOCKS5 suporta UDP via `UDP ASSOCIATE`).
* Cross-platform.

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| [TSocksBlockSocket](TSocksBlockSocket.md) | Heranca (SOCKS5 para UDP) |
| [TBlockSocket](TBlockSocket.md) | Heranca (2 niveis) — I/O, hooks |
| `synsock` | Primitivas |

---

## 4. Funcionalidades

### 4.1 Metodos sobrescritos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Connect` | `procedure Connect(IP, Port: string); override` | Preenche `RemoteSin` com IP/Port; nao faz handshake (datagrama) |
| `SendBuffer` | `function SendBuffer(const Buffer: TMemory; Length: Integer): Integer; override` | Redireciona para `SendBufferTo` usando `RemoteSin` |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Length: Integer): Integer; override` | Redireciona para `RecvBufferFrom`; atualiza `RemoteSin` com origem |

### 4.2 Metodos herdados importantes

| Metodo | Descricao |
| --- | --- |
| `SendBufferTo(const Buffer: TMemory; Length: Integer): Integer` | `sendto()` com `RemoteSin` |
| `RecvBufferFrom(Buffer: TMemory; Length: Integer): Integer` | `recvfrom()` atualizando `RemoteSin` |
| `Bind(IP, Port: string)` | Bind local para receber datagramas |

---

## 5. Aplicabilidades

1. **Base para UDP** — `TUDPBlockSocket` adiciona broadcast, multicast e association.
2. **Base para ICMP** — `TICMPBlockSocket` usa para ping.
3. **Base para RAW** — `TRAWBlockSocket` para pacotes brutos.
4. **Consulta DNS manual** — enviar query UDP directamente (nao e usado no ORM, mas possivel).

---

## 6. Exemplos de uso

### 6.1 Enviar payload UDP simples (via subclasse TUDPBlockSocket)

```pascal
uses SysUtils, blcksock;

var
  LUDP: TUDPBlockSocket;
  LBuf: AnsiString;
begin
  LUDP := TUDPBlockSocket.Create;
  try
    LBuf := 'PING';
    LUDP.Connect('10.0.0.10', '5000');
    LUDP.SendBuffer(PAnsiChar(LBuf), Length(LBuf));
    if LUDP.LastError <> 0 then
      Writeln('Erro: ', LUDP.GetErrorDescEx);
  finally
    LUDP.Free;
  end;
end;
```

### 6.2 Receber datagrama com identificacao de origem

```pascal
uses SysUtils, blcksock;

var
  LUDP: TUDPBlockSocket;
  LBuffer: array[0..1499] of Byte;
  LRead: Integer;
begin
  LUDP := TUDPBlockSocket.Create;
  try
    LUDP.Bind('0.0.0.0', '5000');
    LRead := LUDP.RecvBufferFrom(@LBuffer[0], SizeOf(LBuffer));
    if LRead > 0 then
      Writeln('Recebi ', LRead, ' bytes de ',
              LUDP.GetRemoteSinIP, ':', LUDP.GetRemoteSinPort);
  finally
    LUDP.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TSocksBlockSocket](TSocksBlockSocket.md) | Heranca directa | SOCKS5 para UDP |
| [TBlockSocket](TBlockSocket.md) | Heranca (2 niveis) | Base |
| [TUDPBlockSocket](TUDPBlockSocket.md) | Subclasse | UDP + broadcast + multicast |
| [TICMPBlockSocket](TICMPBlockSocket.md) | Subclasse | ICMP (ping) |
| [TRAWBlockSocket](TRAWBlockSocket.md) | Parente directo | RAW (nao herda de Dgram) |
