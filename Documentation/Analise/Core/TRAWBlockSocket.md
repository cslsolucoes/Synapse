# TRAWBlockSocket / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe concreta | **Origem:** Upstream Synapse

---

## 1. O que e?

`TRAWBlockSocket` e o socket que permite envio e recepcao de pacotes IP brutos, onde o consumidor fornece o cabecalho IP completo. Herda de `TBlockSocket` (nao de `TDgramBlockSocket`), retornando `SOCK_RAW` + `IPPROTO_RAW`.

Sockets RAW sao usados para ferramentas de seguranca (sniffing, injection), protocolos customizados que nao estao acima de TCP/UDP, e implementacoes de protocolos nao suportados pelo kernel. Requer privilegio administrativo (Windows Administrator, Linux `CAP_NET_RAW`).

No contexto ActiveDirectoryORM, `TRAWBlockSocket` nao e usado — esta documentado aqui por completude da hierarquia Synapse.

---

## 2. Caracteristicas

* Socket RAW IP.
* Requer privilegio administrativo.
* Consumidor monta o cabecalho IP inteiro.
* Permite injecao e inspeccao de pacotes.
* Cross-platform com limitacoes (alguns OS nao permitem `IPPROTO_RAW` sem kernel module).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| [TBlockSocket](TBlockSocket.md) | Heranca directa |

---

## 4. Funcionalidades

### 4.1 Identificacao do socket

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSocketType` | `function GetSocketType: integer; override` | `SOCK_RAW` |
| `GetSocketProtocol` | `function GetSocketProtocol: integer; override` | `IPPROTO_RAW` |

### 4.2 Metodos herdados

Todos os metodos I/O de `TBlockSocket` — `SendBuffer`, `RecvBuffer`, `SendBufferTo`, `RecvBufferFrom` — sao utilizaveis. O consumidor deve montar o header IP no buffer enviado.

---

## 5. Aplicabilidades

1. **Sniffer de rede** — capturar todos os pacotes passando pela interface.
2. **Protocolos custom layer 3** — quando nao existe suporte TCP/UDP.
3. **Injecao de pacotes** — tests de seguranca, simulacao de ataques.
4. **Implementacao de VPN userspace** — encapsular trafego em pacotes custom.

---

## 6. Exemplos de uso

### 6.1 Socket RAW minimo (requer Admin)

```pascal
uses SysUtils, blcksock;

var
  LSock: TRAWBlockSocket;
begin
  LSock := TRAWBlockSocket.Create;
  try
    LSock.CreateSocket;
    if LSock.LastError <> 0 then
      Writeln('RAW falhou (executar como Administrador): ',
              LSock.GetErrorDescEx)
    else
      Writeln('RAW ativo');
  finally
    LSock.Free;
  end;
end;
```

### 6.2 Montagem de cabecalho IP (esqueleto)

```pascal
uses SysUtils, blcksock;

var
  LSock: TRAWBlockSocket;
  LHdr: TIPHeader;  // definido em blcksock.pas
  LBuf: AnsiString;
begin
  LSock := TRAWBlockSocket.Create;
  try
    FillChar(LHdr, SizeOf(LHdr), 0);
    LHdr.VerLen   := $45;  // IPv4 + header size 20
    LHdr.TTL      := 64;
    LHdr.Protocol := 17;   // UDP
    // ... SourceIp, DestIp, CheckSum ...
    SetString(LBuf, PAnsiChar(@LHdr), SizeOf(LHdr));
    LSock.Connect('10.0.0.1', '0');
    LSock.SendBuffer(PAnsiChar(LBuf), Length(LBuf));
  finally
    LSock.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TBlockSocket](TBlockSocket.md) | Heranca directa | Diferente de ICMP (que usa `TDgramBlockSocket`) |
| [TICMPBlockSocket](TICMPBlockSocket.md) | Irmao | Tambem `SOCK_RAW` mas `IPPROTO_ICMP` |
| `TIPHeader` (record em blcksock.pas) | Estrutura auxiliar | Definicao do cabecalho IP para ler/montar |
