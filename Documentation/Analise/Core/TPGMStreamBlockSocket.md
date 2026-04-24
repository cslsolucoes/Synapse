# TPGMStreamBlockSocket / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe concreta | **Origem:** Upstream Synapse

---

## 1. O que e?

`TPGMStreamBlockSocket` e o socket PGM (Pragmatic General Multicast, RFC 3208) em modo stream — TCP-like byte stream sobre multicast confiavel. Herda directamente de `TBlockSocket`, retornando `SOCK_STREAM` + `IPPROTO_RM`.

Ao contrario de `TPGMMessageBlockSocket` (onde cada send/recv e um datagrama atomico), em modo stream os bytes fluem continuamente e o consumidor faz enquadramento (framing) como faria em TCP. E uma alternativa rara mas interessante para broadcast confiavel de volumes grandes de dados.

Suporte apenas em Windows com Reliable Multicast Protocol. Nao utilizado no contexto ActiveDirectoryORM.

---

## 2. Caracteristicas

* Multicast confiavel em modo stream.
* `SOCK_STREAM` com `IPPROTO_RM`.
* Windows-only.
* Semantica TCP-like (consumidor faz framing).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| [TBlockSocket](TBlockSocket.md) | Heranca directa |
| Windows Reliable Multicast Protocol | Runtime requerido |

---

## 4. Funcionalidades

### 4.1 Identificacao do socket

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSocketType` | `function GetSocketType: integer; override` | `SOCK_STREAM` |
| `GetSocketProtocol` | `function GetSocketProtocol: integer; override` | `IPPROTO_RM` |

### 4.2 I/O herdado

Todos os metodos `Send*`/`Recv*` de `TBlockSocket` aplicam-se normalmente como se fosse TCP.

---

## 5. Aplicabilidades

1. **Distribuicao de arquivos grandes** via multicast confiavel (ex.: deploy de software).
2. **Substituicao de TCP broadcast** onde broadcast-and-forget nao e suficiente.
3. **Aplicacoes financeiras** com requisito de ordem garantida e entrega confirmada.
4. **Windows legacy services** com RMP instalado.

---

## 6. Exemplos de uso

### 6.1 Checar disponibilidade no runtime

```pascal
uses SysUtils, blcksock;

var
  LSock: TPGMStreamBlockSocket;
begin
  LSock := TPGMStreamBlockSocket.Create;
  try
    LSock.CreateSocket;
    if LSock.LastError <> 0 then
      Writeln('PGM stream indisponivel: ', LSock.GetErrorDescEx)
    else
      Writeln('PGM stream OK');
  finally
    LSock.Free;
  end;
end;
```

### 6.2 Transmissao continua (esqueleto)

```pascal
uses SysUtils, Classes, blcksock;

var
  LSock: TPGMStreamBlockSocket;
  LStream: TFileStream;
begin
  LSock := TPGMStreamBlockSocket.Create;
  try
    LSock.Connect('239.5.6.7', '4004');
    LStream := TFileStream.Create('deploy.bin', fmOpenRead);
    try
      LSock.SendStreamRaw(LStream);
    finally
      LStream.Free;
    end;
  finally
    LSock.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TBlockSocket](TBlockSocket.md) | Heranca directa | |
| [TPGMMessageBlockSocket](TPGMMessageBlockSocket.md) | Irmao | Modo message (datagram) |
